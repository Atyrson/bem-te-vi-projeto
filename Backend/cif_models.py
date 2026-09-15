"""Contratos HTTP específicos da API de avaliações CIF."""

from datetime import date, datetime
from typing import Any, Dict, Literal, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, Field


StatusAvaliacaoCIF = Literal["rascunho", "concluida"]
SexoCIF = Literal["Masculino", "Feminino"]


class CIFRascunhoCriar(BaseModel):
    """Conteúdo inicial comum às duas rotas de criação de rascunho."""

    model_config = ConfigDict(extra="forbid")

    data_avaliacao: date = Field(
        default_factory=date.today,
        validation_alias=AliasChoices("data_avaliacao", "assessment_date"),
    )
    respostas: Dict[str, Any] = Field(default_factory=dict)


class CIFAvaliacaoCriar(CIFRascunhoCriar):
    """Criação pela rota genérica, com vínculo obrigatório no corpo."""

    paciente_id: int = Field(
        validation_alias=AliasChoices("paciente_id", "patient_id")
    )


class CIFAvaliacaoCriarNoPaciente(CIFRascunhoCriar):
    """Criação pela rota que já identifica o paciente no caminho."""


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


class CIFFormularioEscala(BaseModel):
    valores_permitidos: list[Literal[0, 1, 2, 3, 4]]
    permite_sem_resposta_no_rascunho: bool
    obrigatoria_na_conclusao: bool


class CIFFormularioCampo(BaseModel):
    ordem: int
    chave: str
    codigo: str
    codigo_original: str
    descricao: str
    area_codigo: str
    area_descricao: str
    capitulo_codigo: str
    capitulo_descricao: str
    obrigatorio_na_conclusao: bool


class CIFFormularioResposta(BaseModel):
    catalogo_versao: str
    regras_versao: str
    sexo: SexoCIF
    total_campos: int
    escala: CIFFormularioEscala
    campos: list[CIFFormularioCampo]
