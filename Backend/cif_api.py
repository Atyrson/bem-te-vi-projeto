"""Router HTTP da Fase 3 da CIF.

Este módulo não reimplementa fórmulas. Ele fornece o catálogo versionado,
mantém rascunhos e chama ``CalculadorCIF`` para toda prévia e conclusão.
"""

from __future__ import annotations

from dataclasses import fields, is_dataclass
from datetime import date, datetime
import copy
import json
from pathlib import Path
from typing import Any, Mapping, Optional

import psycopg2
from fastapi import APIRouter, HTTPException, status

try:  # Executa tanto como `uvicorn main:app` dentro de Backend quanto em testes.
    from cif_models import (
        CIFAvaliacaoAtualizar,
        CIFAvaliacaoCriar,
        CIFAvaliacaoOperacao,
        CIFAvaliacaoResposta,
        CIFPreviaResposta,
    )
    from cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFAvaliacaoRepository,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        mesclar_respostas,
    )
except ModuleNotFoundError:  # pragma: no cover - importação como pacote.
    from Backend.cif_models import (
        CIFAvaliacaoAtualizar,
        CIFAvaliacaoCriar,
        CIFAvaliacaoOperacao,
        CIFAvaliacaoResposta,
        CIFPreviaResposta,
    )
    from Backend.cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFAvaliacaoRepository,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        mesclar_respostas,
    )

PROJECT_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = PROJECT_ROOT / "catalogos" / "cif" / "catalogo.v0.1.json"
CATALOG = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
CATALOG_VERSION = str(CATALOG["catalog_version"])
# O catálogo registra que as regras ainda estão pendentes de revisão clínica.
# A versão é persistida para tornar explícito qual snapshot técnico foi usado.
RULES_VERSION = "0.1.0-pending-review"

try:
    from scripts.cif.calculador import CalculadorCIF, EntradaCIF
except ModuleNotFoundError:  # pragma: no cover - execução iniciada em Backend/.
    import sys

    sys.path.insert(0, str(PROJECT_ROOT))
    from scripts.cif.calculador import CalculadorCIF, EntradaCIF


calculator = CalculadorCIF(catalog_path=CATALOG_PATH)
repository = CIFAvaliacaoRepository()
router = APIRouter(prefix="/api/v1", tags=["CIF"])


def _json_ready(value: Any) -> Any:
    """Converte dataclasses e MappingProxyType do calculador para JSON."""

    if is_dataclass(value) and not isinstance(value, type):
        return {field.name: _json_ready(getattr(value, field.name)) for field in fields(value)}
    if isinstance(value, Mapping):
        return {str(key): _json_ready(item) for key, item in value.items()}
    if isinstance(value, (tuple, list)):
        return [_json_ready(item) for item in value]
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _resultado_dict(resultado: Any) -> dict[str, Any]:
    return _json_ready(resultado)


def _registro_dict(registro: CIFAvaliacaoRegistro) -> dict[str, Any]:
    return {
        "id": registro.id,
        "paciente_id": registro.paciente_id,
        "data_avaliacao": registro.data_avaliacao,
        "status": registro.status,
        "catalogo_versao": registro.catalogo_versao,
        "regras_versao": registro.regras_versao,
        "respostas": registro.respostas,
        "resultados": registro.resultados,
        "criado_em": registro.criado_em,
        "atualizado_em": registro.atualizado_em,
        "concluido_em": registro.concluido_em,
    }


def _calcular(sexo: Optional[str], respostas: Mapping[str, Any]) -> Any:
    """Único ponto em que a API chama o calculador oficial."""

    return calculator.calcular(EntradaCIF(sexo=sexo, respostas=respostas))


def _erro_banco(exc: Exception) -> HTTPException:
    # Não expõe credenciais, SQL ou detalhes do banco ao cliente.
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Erro interno ao acessar as avaliações CIF.",
    )


def _assert_path_patient(path_patient_id: Optional[int], body_patient_id: Optional[int]) -> int:
    if path_patient_id is None and body_patient_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="paciente_id é obrigatório para criar uma avaliação CIF.",
        )
    if path_patient_id is not None and body_patient_id is not None and path_patient_id != body_patient_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="paciente_id do corpo não corresponde ao paciente da rota.",
        )
    return body_patient_id if path_patient_id is None else path_patient_id


@router.get("/cif/catalogo", summary="Consulta o catálogo versionado da CIF")
def consultar_catalogo() -> dict[str, Any]:
    payload = copy.deepcopy(CATALOG)
    payload["rules_version"] = RULES_VERSION
    return payload


@router.post(
    "/cif-avaliacoes",
    response_model=CIFAvaliacaoResposta,
    status_code=status.HTTP_201_CREATED,
    summary="Cria um rascunho de avaliação CIF",
)
@router.post(
    "/patients/{patient_id}/cif-avaliacoes",
    response_model=CIFAvaliacaoResposta,
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False,
)
def criar_rascunho(
    payload: CIFAvaliacaoCriar, patient_id: Optional[int] = None
) -> dict[str, Any]:
    paciente_id = _assert_path_patient(patient_id, payload.paciente_id)
    try:
        registro = repository.criar(
            paciente_id=paciente_id,
            data_avaliacao=payload.data_avaliacao,
            respostas=payload.respostas,
            catalogo_versao=CATALOG_VERSION,
            regras_versao=RULES_VERSION,
        )
        return _registro_dict(registro)
    except CIFPacienteNaoEncontrado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paciente não encontrado.")
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


def _obter_contexto(patient_id: int, assessment_id: int) -> tuple[CIFAvaliacaoRegistro, Optional[str]]:
    try:
        return repository.obter_com_sexo(patient_id, assessment_id)
    except (CIFAvaliacaoNaoEncontrada, CIFPacienteNaoEncontrado):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Avaliação CIF não encontrada.")
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.patch(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}",
    response_model=CIFAvaliacaoResposta,
    summary="Atualiza um rascunho de avaliação CIF",
)
@router.put(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}",
    response_model=CIFAvaliacaoResposta,
    include_in_schema=False,
)
def atualizar_rascunho(
    patient_id: int, assessment_id: int, payload: CIFAvaliacaoAtualizar
) -> dict[str, Any]:
    try:
        registro = repository.atualizar_rascunho(
            paciente_id=patient_id,
            avaliacao_id=assessment_id,
            respostas=payload.respostas,
            data_avaliacao=payload.data_avaliacao,
        )
        return _registro_dict(registro)
    except CIFAvaliacaoNaoEncontrada:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Avaliação CIF não encontrada.")
    except CIFAvaliacaoConcluida:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Avaliações CIF concluídas não podem ser editadas.",
        )
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.post(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}/previa",
    response_model=CIFPreviaResposta,
    summary="Calcula uma prévia da avaliação CIF",
)
def calcular_previa(
    patient_id: int, assessment_id: int, payload: CIFAvaliacaoOperacao
) -> dict[str, Any]:
    registro, sexo = _obter_contexto(patient_id, assessment_id)
    respostas = mesclar_respostas(registro.respostas, payload.respostas)
    resultado = _calcular(sexo, respostas)
    return {
        "avaliacao_id": registro.id,
        "paciente_id": registro.paciente_id,
        "catalogo_versao": registro.catalogo_versao,
        "regras_versao": registro.regras_versao,
        "status": resultado.status,
        "definitivo": resultado.definitivo,
        "resultado": _resultado_dict(resultado),
    }


@router.post(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}/concluir",
    response_model=CIFAvaliacaoResposta,
    summary="Valida, recalcula e conclui uma avaliação CIF",
)
def concluir_avaliacao(
    patient_id: int, assessment_id: int, payload: CIFAvaliacaoOperacao
) -> dict[str, Any]:
    try:
        registro = repository.concluir(
            paciente_id=patient_id,
            avaliacao_id=assessment_id,
            respostas_patch=payload.respostas,
            calcular=_calcular,
            serializar_resultado=_resultado_dict,
        )
        return _registro_dict(registro)
    except CIFAvaliacaoNaoEncontrada:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Avaliação CIF não encontrada.")
    except CIFAvaliacaoConcluida:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Avaliações CIF concluídas não podem ser editadas.",
        )
    except CIFCalculoInvalido as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "message": "Respostas inválidas ou incompletas; a avaliação continua como rascunho.",
                "resultado": _resultado_dict(exc.resultado),
            },
        ) from exc
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.get(
    "/patients/{patient_id}/cif-avaliacoes",
    response_model=list[CIFAvaliacaoResposta],
    summary="Lista avaliações CIF de um paciente",
)
def listar_avaliacoes(patient_id: int) -> list[dict[str, Any]]:
    try:
        return [_registro_dict(item) for item in repository.listar(patient_id)]
    except CIFPacienteNaoEncontrado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paciente não encontrado.")
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.get(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}",
    response_model=CIFAvaliacaoResposta,
    summary="Consulta uma avaliação CIF",
)
def consultar_avaliacao(patient_id: int, assessment_id: int) -> dict[str, Any]:
    registro, _ = _obter_contexto(patient_id, assessment_id)
    return _registro_dict(registro)


__all__ = ["router"]
