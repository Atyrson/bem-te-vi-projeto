"""Montagem do contrato de formulário dinâmico da CIF.

Este módulo apenas seleciona as entradas informadas pelo calculador oficial e
as enriquece com metadados de apresentação do catálogo. Não interpreta
fórmulas, calcula resultados nem acessa persistência.
"""

from __future__ import annotations

from typing import Any, Mapping, get_args

try:  # Compatível com execução a partir de Backend e importação como pacote.
    from cif_models import (
        CIFFormularioCampo,
        CIFFormularioEscala,
        CIFFormularioResposta,
        SexoCIF,
    )
    from cif_versions import CIFMotorVersionado
except ModuleNotFoundError:  # pragma: no cover - importação como pacote.
    from Backend.cif_models import (
        CIFFormularioCampo,
        CIFFormularioEscala,
        CIFFormularioResposta,
        SexoCIF,
    )
    from Backend.cif_versions import CIFMotorVersionado


_ESCALA = (0, 1, 2, 3, 4)


def _metadados_catalogo(catalogo: Mapping[str, Any]) -> dict[str, dict[str, str]]:
    """Indexa descrições de campos por área e célula de valor."""

    campos: dict[str, dict[str, str]] = {}
    for area in catalogo.get("areas", []):
        area_codigo = str(area.get("code", "")).lower()
        area_descricao = str(area.get("name", ""))
        nodes = area.get("nodes", [])
        nodes_por_codigo = {
            str(node.get("code", "")).lower(): node for node in nodes
        }
        for node in nodes:
            chapter_codigo = node.get("chapter")
            if chapter_codigo is None:
                continue
            chapter_codigo = str(chapter_codigo).lower()
            chapter = nodes_por_codigo.get(chapter_codigo)
            if chapter is None:
                raise ValueError(
                    f"Capítulo ausente no catálogo: {area_codigo}:{chapter_codigo}"
                )
            for field in node.get("fields", []):
                celula = str(field.get("value_cell", "")).upper()
                if not celula:
                    raise ValueError(
                        f"Campo sem célula no catálogo: {area_codigo}:{node.get('code')}"
                    )
                chave = f"{area_codigo}:{celula}".lower()
                if chave in campos:
                    raise ValueError(f"Célula duplicada no catálogo: {chave}")
                campos[chave] = {
                    "descricao": str(node.get("description", "")),
                    "area_codigo": area_codigo,
                    "area_descricao": area_descricao,
                    "capitulo_codigo": chapter_codigo,
                    "capitulo_descricao": str(chapter.get("description", "")),
                }
    return campos


def construir_formulario(
    motor: CIFMotorVersionado, sexo: SexoCIF
) -> CIFFormularioResposta:
    """Constrói o formulário para ``sexo`` a partir do motor versionado."""

    if sexo not in get_args(SexoCIF):
        raise ValueError("Sexo deve ser exatamente 'Feminino' ou 'Masculino'.")

    metadados = _metadados_catalogo(motor.catalogo)
    campos_calculador = motor.calculador.campos_entrada_obrigatorios(sexo)
    campos: list[CIFFormularioCampo] = []
    for ordem, campo in enumerate(campos_calculador, start=1):
        metadata = metadados.get(campo.chave.lower())
        if metadata is None:
            raise ValueError(f"Campo ausente no catálogo: {campo.chave}")
        campos.append(
            CIFFormularioCampo(
                ordem=ordem,
                chave=campo.chave,
                codigo=campo.codigo,
                codigo_original=campo.codigo_original,
                descricao=metadata["descricao"],
                area_codigo=metadata["area_codigo"],
                area_descricao=metadata["area_descricao"],
                capitulo_codigo=metadata["capitulo_codigo"],
                capitulo_descricao=metadata["capitulo_descricao"],
                obrigatorio_na_conclusao=True,
            )
        )

    return CIFFormularioResposta(
        catalogo_versao=motor.catalogo_versao,
        regras_versao=motor.regras_versao,
        sexo=sexo,
        total_campos=len(campos),
        escala=CIFFormularioEscala(
            valores_permitidos=list(_ESCALA),
            permite_sem_resposta_no_rascunho=True,
            obrigatoria_na_conclusao=True,
        ),
        campos=campos,
    )


__all__ = ["construir_formulario"]
