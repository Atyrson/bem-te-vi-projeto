"""Contratos HTTP específicos da API de avaliações CIF."""

from datetime import date, datetime
from typing import Any, Dict, Literal, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, Field


StatusAvaliacaoCIF = Literal["rascunho", "concluida"]


class CIFAvaliacaoCriar(BaseModel):
    """Dados para abrir uma avaliação independente por paciente."""

    model_config = ConfigDict(extra="forbid")

    paciente_id: Optional[int] = Field(
        default=None,
        validation_alias=AliasChoices("paciente_id", "patient_id")
    )
    data_avaliacao: date = Field(
        default_factory=date.today,
        validation_alias=AliasChoices("data_avaliacao", "assessment_date"),
    )
    respostas: Dict[str, Any] = Field(default_factory=dict)


class CIFAvaliacaoAtualizar(BaseModel):
    """Patch de um rascunho; respostas novas mesclam-se às já salvas."""

    model_config = ConfigDict(extra="forbid")

    data_avaliacao: Optional[date] = Field(
        default=None,
        validation_alias=AliasChoices("data_avaliacao", "assessment_date"),
    )
    respostas: Optional[Dict[str, Any]] = None


class CIFAvaliacaoOperacao(BaseModel):
    """Respostas opcionais para prévia ou conclusão.

    Quando presentes, as respostas são aplicadas como patch sobre o estado
    persistido. O campo de resultados não faz parte do contrato de entrada.
    """

    model_config = ConfigDict(extra="forbid")

    respostas: Optional[Dict[str, Any]] = None


class CIFAvaliacaoResposta(BaseModel):
    id: int
    paciente_id: int
    data_avaliacao: date
    status: StatusAvaliacaoCIF
    catalogo_versao: str
    regras_versao: str
    respostas: Dict[str, Any]
    resultados: Optional[Dict[str, Any]] = None
    criado_em: Optional[datetime] = None
    atualizado_em: Optional[datetime] = None
    concluido_em: Optional[datetime] = None


class CIFPreviaResposta(BaseModel):
    avaliacao_id: int
    paciente_id: int
    catalogo_versao: str
    regras_versao: str
    status: str
    definitivo: bool
    resultado: Dict[str, Any]
