"""Router HTTP da Fase 3 da CIF.

Este módulo não reimplementa fórmulas. Ele fornece o catálogo versionado,
mantém rascunhos e chama ``CalculadorCIF`` para toda prévia e conclusão.
"""

from __future__ import annotations

from dataclasses import fields, is_dataclass
from datetime import date, datetime
import copy
from typing import Annotated, Any, Mapping, Optional, cast, get_args

import psycopg2
from fastapi import APIRouter, Depends, HTTPException, Query, status

try:  # Executa tanto como `uvicorn main:app` dentro de Backend quanto em testes.
    from cif_models import (
        CIFAvaliacaoAtualizar,
        CIFAvaliacaoCriar,
        CIFAvaliacaoCriarNoPaciente,
        CIFAvaliacaoOperacao,
        CIFAvaliacaoResposta,
        CIFFormularioResposta,
        CIFPreviaResposta,
        SexoCIF,
    )
    from cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFAvaliacaoRepository,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        CIFRespostasInvalidas,
        mesclar_respostas,
    )
    from cif_versions import CIFVersaoNaoSuportada, MOTOR_ATIVO, obter_motor
    from cif_formulario import construir_formulario
except ModuleNotFoundError:  # pragma: no cover - importação como pacote.
    from Backend.cif_models import (
        CIFAvaliacaoAtualizar,
        CIFAvaliacaoCriar,
        CIFAvaliacaoCriarNoPaciente,
        CIFAvaliacaoOperacao,
        CIFAvaliacaoResposta,
        CIFFormularioResposta,
        CIFPreviaResposta,
        SexoCIF,
    )
    from Backend.cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFAvaliacaoRepository,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        CIFRespostasInvalidas,
        mesclar_respostas,
    )
    from Backend.cif_versions import CIFVersaoNaoSuportada, MOTOR_ATIVO, obter_motor
    from Backend.cif_formulario import construir_formulario


CATALOG = MOTOR_ATIVO.catalogo
CATALOG_VERSION = MOTOR_ATIVO.catalogo_versao
RULES_VERSION = MOTOR_ATIVO.regras_versao
calculator = MOTOR_ATIVO.calculador


repository = CIFAvaliacaoRepository()
router = APIRouter(prefix="/api/v1", tags=["CIF"])


def obter_repositorio_cif() -> CIFAvaliacaoRepository:
    return repository


RepositorioCIF = Annotated[CIFAvaliacaoRepository, Depends(obter_repositorio_cif)]


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


def _calcular_versionado(
    catalogo_versao: str,
    regras_versao: str,
    sexo: Optional[str],
    respostas: Mapping[str, Any],
) -> Any:
    """Resolve a versão persistida antes de chamar o calculador oficial."""

    motor = obter_motor(catalogo_versao, regras_versao)
    from scripts.cif.calculador import EntradaCIF

    return motor.calculador.calcular(EntradaCIF(sexo=sexo, respostas=respostas))


def _validar_rascunho_versionado(
    catalogo_versao: str,
    regras_versao: str,
    sexo: Optional[str],
    respostas: Mapping[str, Any],
) -> Any:
    """Aceita pendências, mas rejeita respostas estruturalmente inválidas."""

    resultado = _calcular_versionado(
        catalogo_versao, regras_versao, sexo, respostas
    )
    erros_estruturais = [
        erro for erro in resultado.erros if erro.codigo != "sexo_invalido"
    ]
    if erros_estruturais:
        raise CIFRespostasInvalidas(resultado)
    return resultado


def _erro_banco(exc: Exception) -> HTTPException:
    # Não expõe credenciais, SQL ou detalhes do banco ao cliente.
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Erro interno ao acessar as avaliações CIF.",
    )


def _erro_versao(exc: CIFVersaoNaoSuportada) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "versao_cif_incompativel",
            "message": "A versão CIF desta avaliação não é suportada pelo servidor atual.",
            "catalogo_versao": exc.catalogo_versao,
            "regras_versao": exc.regras_versao,
        },
    )


def _erro_respostas(resultado: Any) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={
            "message": "O rascunho contém respostas CIF inválidas.",
            "resultado": _resultado_dict(resultado),
        },
    )


def _validar_sexo_formulario(sexo: Optional[str]) -> SexoCIF:
    if sexo in get_args(SexoCIF):
        return cast(SexoCIF, sexo)
    codigo = "sexo_ausente" if sexo is None else "sexo_invalido"
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={
            "code": codigo,
            "message": (
                "O parâmetro sexo é obrigatório e deve ser exatamente "
                "'Feminino' ou 'Masculino'."
            ),
            "valor": sexo,
        },
    )


@router.get(
    "/cif/formulario",
    response_model=CIFFormularioResposta,
    summary="Consulta o formulário CIF aplicável por sexo",
)
def consultar_formulario(
    sexo: Optional[str] = Query(
        default=None,
        description="Sexo autoritativo do paciente: Feminino ou Masculino.",
    )
) -> CIFFormularioResposta:
    sexo_validado = _validar_sexo_formulario(sexo)
    return construir_formulario(MOTOR_ATIVO, sexo_validado)


@router.get("/cif/catalogo", summary="Consulta o catálogo versionado da CIF")
def consultar_catalogo() -> dict[str, Any]:
    payload = copy.deepcopy(CATALOG)
    payload["rules_version"] = RULES_VERSION
    return payload


def _criar_rascunho(
    paciente_id: int,
    data_avaliacao: date,
    respostas: Mapping[str, Any],
    repositorio: CIFAvaliacaoRepository,
) -> dict[str, Any]:
    try:
        registro = repositorio.criar(
            paciente_id=paciente_id,
            data_avaliacao=data_avaliacao,
            respostas=respostas,
            catalogo_versao=CATALOG_VERSION,
            regras_versao=RULES_VERSION,
            validar_rascunho=_validar_rascunho_versionado,
        )
        return _registro_dict(registro)
    except CIFPacienteNaoEncontrado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paciente não encontrado.")
    except CIFRespostasInvalidas as exc:
        raise _erro_respostas(exc.resultado) from exc
    except CIFVersaoNaoSuportada as exc:
        raise _erro_versao(exc) from exc
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.post(
    "/cif-avaliacoes",
    response_model=CIFAvaliacaoResposta,
    status_code=status.HTTP_201_CREATED,
    summary="Cria um rascunho de avaliação CIF",
)
def criar_rascunho(
    payload: CIFAvaliacaoCriar, repositorio: RepositorioCIF
) -> dict[str, Any]:
    return _criar_rascunho(
        payload.paciente_id,
        payload.data_avaliacao,
        payload.respostas,
        repositorio,
    )


@router.post(
    "/patients/{patient_id}/cif-avaliacoes",
    response_model=CIFAvaliacaoResposta,
    status_code=status.HTTP_201_CREATED,
    summary="Cria um rascunho CIF para o paciente da rota",
)
def criar_rascunho_do_paciente(
    patient_id: int,
    payload: CIFAvaliacaoCriarNoPaciente,
    repositorio: RepositorioCIF,
) -> dict[str, Any]:
    return _criar_rascunho(
        patient_id,
        payload.data_avaliacao,
        payload.respostas,
        repositorio,
    )


def _obter_contexto(
    repositorio: CIFAvaliacaoRepository, patient_id: int, assessment_id: int
) -> tuple[CIFAvaliacaoRegistro, Optional[str]]:
    try:
        return repositorio.obter_com_sexo(patient_id, assessment_id)
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
    patient_id: int,
    assessment_id: int,
    payload: CIFAvaliacaoAtualizar,
    repositorio: RepositorioCIF,
) -> dict[str, Any]:
    try:
        registro = repositorio.atualizar_rascunho(
            paciente_id=patient_id,
            avaliacao_id=assessment_id,
            respostas=payload.respostas,
            data_avaliacao=payload.data_avaliacao,
            validar_rascunho=_validar_rascunho_versionado,
        )
        return _registro_dict(registro)
    except CIFAvaliacaoNaoEncontrada:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Avaliação CIF não encontrada.")
    except CIFAvaliacaoConcluida:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Avaliações CIF concluídas não podem ser editadas.",
        )
    except CIFRespostasInvalidas as exc:
        raise _erro_respostas(exc.resultado) from exc
    except CIFVersaoNaoSuportada as exc:
        raise _erro_versao(exc) from exc
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.post(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}/previa",
    response_model=CIFPreviaResposta,
    summary="Calcula uma prévia da avaliação CIF",
)
def calcular_previa(
    patient_id: int,
    assessment_id: int,
    payload: CIFAvaliacaoOperacao,
    repositorio: RepositorioCIF,
) -> dict[str, Any]:
    registro, sexo = _obter_contexto(repositorio, patient_id, assessment_id)
    respostas = mesclar_respostas(registro.respostas, payload.respostas)
    try:
        resultado = _calcular_versionado(
            registro.catalogo_versao,
            registro.regras_versao,
            sexo,
            respostas,
        )
    except CIFVersaoNaoSuportada as exc:
        raise _erro_versao(exc) from exc
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
    patient_id: int,
    assessment_id: int,
    payload: CIFAvaliacaoOperacao,
    repositorio: RepositorioCIF,
) -> dict[str, Any]:
    try:
        registro = repositorio.concluir(
            paciente_id=patient_id,
            avaliacao_id=assessment_id,
            respostas_patch=payload.respostas,
            calcular=_calcular_versionado,
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
    except CIFVersaoNaoSuportada as exc:
        raise _erro_versao(exc) from exc
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.get(
    "/patients/{patient_id}/cif-avaliacoes",
    response_model=list[CIFAvaliacaoResposta],
    summary="Lista avaliações CIF de um paciente",
)
def listar_avaliacoes(
    patient_id: int, repositorio: RepositorioCIF
) -> list[dict[str, Any]]:
    try:
        return [_registro_dict(item) for item in repositorio.listar(patient_id)]
    except CIFPacienteNaoEncontrado:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paciente não encontrado.")
    except (psycopg2.Error, OSError) as exc:
        raise _erro_banco(exc) from exc


@router.get(
    "/patients/{patient_id}/cif-avaliacoes/{assessment_id}",
    response_model=CIFAvaliacaoResposta,
    summary="Consulta uma avaliação CIF",
)
def consultar_avaliacao(
    patient_id: int,
    assessment_id: int,
    repositorio: RepositorioCIF,
) -> dict[str, Any]:
    registro, _ = _obter_contexto(repositorio, patient_id, assessment_id)
    return _registro_dict(registro)


__all__ = ["obter_repositorio_cif", "router"]
