"""Persistência isolada das avaliações CIF.

O repositório conhece somente o contrato da tabela CIF. A decisão de validade
clínica e todos os cálculos continuam no calculador oficial em
``scripts/cif/calculador.py``.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Callable, Dict, Iterable, Mapping, Optional

from psycopg2.extras import Json

try:  # Compatível com `uvicorn main:app` e com importação como Backend.
    from database import get_db_connection
except ModuleNotFoundError:  # pragma: no cover - importação como pacote.
    from Backend.database import get_db_connection


@dataclass(frozen=True)
class CIFAvaliacaoRegistro:
    id: int
    paciente_id: int
    data_avaliacao: date
    status: str
    catalogo_versao: str
    regras_versao: str
    respostas: Dict[str, Any]
    resultados: Optional[Dict[str, Any]]
    criado_em: Optional[datetime]
    atualizado_em: Optional[datetime]
    concluido_em: Optional[datetime]


class CIFPacienteNaoEncontrado(LookupError):
    pass


class CIFAvaliacaoNaoEncontrada(LookupError):
    pass


class CIFAvaliacaoConcluida(RuntimeError):
    pass


class CIFCalculoInvalido(ValueError):
    def __init__(self, resultado: Any):
        super().__init__("A avaliação CIF não pode ser concluída com as respostas informadas")
        self.resultado = resultado


class CIFRespostasInvalidas(ValueError):
    def __init__(self, resultado: Any):
        super().__init__("O rascunho contém respostas CIF inválidas")
        self.resultado = resultado


def mesclar_respostas(
    atuais: Mapping[str, Any], patch: Optional[Mapping[str, Any]]
) -> Dict[str, Any]:
    """Mescla um patch e permite remover uma resposta usando ``null``."""

    merged = dict(atuais)
    if patch is None:
        return merged
    for key, value in patch.items():
        if value is None:
            merged.pop(key, None)
        else:
            merged[key] = value
    return merged


class CIFAvaliacaoRepository:
    """Acesso transacional à tabela ``avaliacoes_cif``."""

    _COLUMNS = (
        "id, paciente_id, data_avaliacao, status, catalogo_versao, "
        "regras_versao, respostas, resultados, criado_em, atualizado_em, concluido_em"
    )

    def __init__(self, connection_factory: Callable[[], Any] = get_db_connection):
        self.connection_factory = connection_factory

    @classmethod
    def _registro(cls, row: Iterable[Any]) -> CIFAvaliacaoRegistro:
        values = list(row)
        return CIFAvaliacaoRegistro(
            id=values[0],
            paciente_id=values[1],
            data_avaliacao=values[2],
            status=values[3],
            catalogo_versao=values[4],
            regras_versao=values[5],
            respostas=dict(values[6] or {}),
            resultados=None if values[7] is None else dict(values[7]),
            criado_em=values[8],
            atualizado_em=values[9],
            concluido_em=values[10],
        )

    @staticmethod
    def _fechar(conn: Any, cursor: Any, commit: bool = False) -> None:
        if conn is not None:
            if commit:
                conn.commit()
            cursor.close()
            conn.close()

    @staticmethod
    def _rollback_fechar(conn: Any, cursor: Any) -> None:
        if conn is not None:
            conn.rollback()
            cursor.close()
            conn.close()

    @classmethod
    def _buscar_registro(
        cls, cursor: Any, paciente_id: int, avaliacao_id: int, *, for_update: bool = False
    ) -> Optional[CIFAvaliacaoRegistro]:
        suffix = " FOR UPDATE" if for_update else ""
        cursor.execute(
            f"SELECT {cls._COLUMNS} FROM avaliacoes_cif "
            f"WHERE id = %s AND paciente_id = %s{suffix};",
            (avaliacao_id, paciente_id),
        )
        row = cursor.fetchone()
        return None if row is None else cls._registro(row)

    @staticmethod
    def _buscar_sexo(cursor: Any, paciente_id: int) -> Optional[str]:
        cursor.execute("SELECT sexo FROM pacientes WHERE id = %s;", (paciente_id,))
        row = cursor.fetchone()
        if row is None:
            raise CIFPacienteNaoEncontrado
        return row[0]

    def criar(
        self,
        paciente_id: int,
        data_avaliacao: date,
        respostas: Mapping[str, Any],
        catalogo_versao: str,
        regras_versao: str,
        validar_rascunho: Callable[
            [str, str, Optional[str], Mapping[str, Any]], Any
        ],
    ) -> CIFAvaliacaoRegistro:
        conn = self.connection_factory()
        cursor = conn.cursor()
        try:
            sexo = self._buscar_sexo(cursor, paciente_id)
            validar_rascunho(
                catalogo_versao, regras_versao, sexo, respostas
            )
            cursor.execute(
                f"INSERT INTO avaliacoes_cif "
                "(paciente_id, data_avaliacao, status, catalogo_versao, regras_versao, respostas) "
                "VALUES (%s, %s, 'rascunho', %s, %s, %s) "
                f"RETURNING {self._COLUMNS};",
                (
                    paciente_id,
                    data_avaliacao,
                    catalogo_versao,
                    regras_versao,
                    Json(dict(respostas)),
                ),
            )
            registro = self._registro(cursor.fetchone())
            self._fechar(conn, cursor, commit=True)
            return registro
        except Exception:
            self._rollback_fechar(conn, cursor)
            raise

    def obter_com_sexo(
        self, paciente_id: int, avaliacao_id: int
    ) -> tuple[CIFAvaliacaoRegistro, Optional[str]]:
        conn = self.connection_factory()
        cursor = conn.cursor()
        try:
            registro = self._buscar_registro(cursor, paciente_id, avaliacao_id)
            if registro is None:
                raise CIFAvaliacaoNaoEncontrada
            sexo = self._buscar_sexo(cursor, paciente_id)
            self._fechar(conn, cursor)
            return registro, sexo
        except Exception:
            self._rollback_fechar(conn, cursor)
            raise

    def listar(self, paciente_id: int) -> list[CIFAvaliacaoRegistro]:
        conn = self.connection_factory()
        cursor = conn.cursor()
        try:
            self._buscar_sexo(cursor, paciente_id)
            cursor.execute(
                f"SELECT {self._COLUMNS} FROM avaliacoes_cif "
                "WHERE paciente_id = %s ORDER BY data_avaliacao DESC, id DESC;",
                (paciente_id,),
            )
            registros = [self._registro(row) for row in cursor.fetchall()]
            self._fechar(conn, cursor)
            return registros
        except Exception:
            self._rollback_fechar(conn, cursor)
            raise

    def atualizar_rascunho(
        self,
        paciente_id: int,
        avaliacao_id: int,
        respostas: Optional[Mapping[str, Any]],
        data_avaliacao: Optional[date],
        validar_rascunho: Callable[
            [str, str, Optional[str], Mapping[str, Any]], Any
        ],
    ) -> CIFAvaliacaoRegistro:
        conn = self.connection_factory()
        cursor = conn.cursor()
        try:
            registro = self._buscar_registro(cursor, paciente_id, avaliacao_id, for_update=True)
            if registro is None:
                raise CIFAvaliacaoNaoEncontrada
            if registro.status == "concluida":
                raise CIFAvaliacaoConcluida
            atualizadas = mesclar_respostas(registro.respostas, respostas)
            sexo = self._buscar_sexo(cursor, paciente_id)
            validar_rascunho(
                registro.catalogo_versao,
                registro.regras_versao,
                sexo,
                atualizadas,
            )
            cursor.execute(
                f"UPDATE avaliacoes_cif SET respostas = %s, "
                "data_avaliacao = COALESCE(%s, data_avaliacao), "
                "atualizado_em = CURRENT_TIMESTAMP "
                "WHERE id = %s AND paciente_id = %s AND status = 'rascunho' "
                f"RETURNING {self._COLUMNS};",
                (Json(atualizadas), data_avaliacao, avaliacao_id, paciente_id),
            )
            row = cursor.fetchone()
            if row is None:
                raise CIFAvaliacaoConcluida
            atualizado = self._registro(row)
            self._fechar(conn, cursor, commit=True)
            return atualizado
        except Exception:
            self._rollback_fechar(conn, cursor)
            raise

    def concluir(
        self,
        paciente_id: int,
        avaliacao_id: int,
        respostas_patch: Optional[Mapping[str, Any]],
        calcular: Callable[
            [str, str, Optional[str], Mapping[str, Any]], Any
        ],
        serializar_resultado: Callable[[Any], Dict[str, Any]],
    ) -> CIFAvaliacaoRegistro:
        """Conclui sob lock, recalculando contra o estado efetivamente salvo."""

        conn = self.connection_factory()
        cursor = conn.cursor()
        try:
            registro = self._buscar_registro(cursor, paciente_id, avaliacao_id, for_update=True)
            if registro is None:
                raise CIFAvaliacaoNaoEncontrada

            respostas_finais = mesclar_respostas(registro.respostas, respostas_patch)
            if registro.status == "concluida":
                if respostas_finais != registro.respostas:
                    raise CIFAvaliacaoConcluida
                self._fechar(conn, cursor)
                return registro

            sexo = self._buscar_sexo(cursor, paciente_id)
            resultado = calcular(
                registro.catalogo_versao,
                registro.regras_versao,
                sexo,
                respostas_finais,
            )
            if not resultado.definitivo:
                raise CIFCalculoInvalido(resultado)
            resultados = serializar_resultado(resultado)
            cursor.execute(
                f"UPDATE avaliacoes_cif SET respostas = %s, status = 'concluida', "
                "resultados = %s, concluido_em = CURRENT_TIMESTAMP, "
                "atualizado_em = CURRENT_TIMESTAMP "
                "WHERE id = %s AND paciente_id = %s AND status = 'rascunho' "
                f"RETURNING {self._COLUMNS};",
                (Json(respostas_finais), Json(resultados), avaliacao_id, paciente_id),
            )
            row = cursor.fetchone()
            if row is None:
                raise CIFAvaliacaoConcluida
            concluida = self._registro(row)
            self._fechar(conn, cursor, commit=True)
            return concluida
        except Exception:
            self._rollback_fechar(conn, cursor)
            raise
