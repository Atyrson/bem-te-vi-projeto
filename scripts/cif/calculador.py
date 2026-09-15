"""Modelos, validação e cálculo hierárquico isolado da CIF.

O módulo usa somente o catálogo versionado e as referências de fórmulas nele
registradas. Não importa planilhas, não acessa HTTP ou banco de dados e não usa
as abas de resumo como fonte clínica.
"""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass, field
from decimal import Decimal, ROUND_HALF_UP, localcontext
import json
from fractions import Fraction
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Mapping, Optional


DEFAULT_CATALOG_PATH = (
    Path(__file__).resolve().parents[2] / "catalogos" / "cif" / "catalogo.v0.1.json"
)
SEXES = ("Masculino", "Feminino")
_AREA_ROOT_CELLS = {"b": {"Feminino": "E4", "Masculino": "G4"}, "s": {"Feminino": "E3", "Masculino": "H3"}}
_CHAPTER_VARIANT_CELLS = {
    ("b", "b6"): {"Feminino": "E384", "Masculino": "I384"},
    ("s", "s6"): {"Feminino": "E173", "Masculino": "H173"},
}

_CELL_REFERENCE = re.compile(
    r"^\$?(?P<start_col>[A-Z]{1,3})\$?(?P<start_row>\d+)"
    r"(?:\:\$?(?P<end_col>[A-Z]{1,3})\$?(?P<end_row>\d+))?$",
    re.IGNORECASE,
)


class CatalogoCIFError(ValueError):
    """Indica catálogo ou fórmula incompatível com o calculador."""


@dataclass(frozen=True)
class EntradaCIF:
    """Dados clínicos recebidos pelo calculador.

    As respostas são indexadas preferencialmente por ``area:E<linha>``. Para
    códigos únicos, o código CIF (por exemplo ``b1100``) também é aceito. Um
    código repetido deve usar a chave por célula para não perder a identidade da
    ocorrência na planilha.
    """

    sexo: Optional[str] = None
    respostas: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.respostas is None:
            object.__setattr__(self, "respostas", MappingProxyType({}))
        else:
            object.__setattr__(self, "respostas", MappingProxyType(dict(self.respostas)))

    @classmethod
    def from_mapping(cls, data: Mapping[str, Any]) -> "EntradaCIF":
        """Cria uma entrada a partir de um mapa com ``sexo`` e respostas.

        Também aceita ``{"sexo": ..., "respostas": {...}}`` para facilitar a
        integração futura, sem criar dependência de um protocolo HTTP.
        """

        values = dict(data)
        sexo = values.pop("sexo", None)
        nested = values.pop("respostas", None)
        if nested is not None:
            if values:
                raise ValueError("Use respostas diretamente ou dentro de 'respostas', não ambos")
            values = dict(nested)
        return cls(sexo=sexo, respostas=values)


@dataclass(frozen=True)
class CampoEntrada:
    area: str
    codigo: str
    codigo_original: str
    celula: str
    linha: int
    descricao: str

    @property
    def chave(self) -> str:
        return f"{self.area}:{self.celula}"

    @property
    def key(self) -> str:
        """Alias em inglês para consumidores que não usam a nomenclatura local."""

        return self.chave


@dataclass(frozen=True)
class ProblemaValidacao:
    codigo: str
    mensagem: str
    campo: Optional[str] = None
    valor: Any = None

    @property
    def code(self) -> str:
        return self.codigo

    @property
    def field(self) -> Optional[str]:
        return self.campo


@dataclass(frozen=True)
class ResultadoParcial:
    codigo: str
    area: str
    campo: str
    valor: Optional[float]
    valor_interno: Optional[float]
    pendente: bool

    @property
    def value(self) -> Optional[float]:
        return self.valor

    @property
    def exact_value(self) -> Optional[float]:
        return self.valor_interno


@dataclass(frozen=True)
class ResultadoCapitulo(ResultadoParcial):
    pass


@dataclass(frozen=True)
class ResultadoArea(ResultadoParcial):
    nome: str = ""


@dataclass(frozen=True)
class ResultadoCIF:
    status: str
    definitivo: bool
    sexo: Optional[str]
    capitulos: Mapping[str, ResultadoCapitulo]
    areas: Mapping[str, ResultadoArea]
    intermediarios: Mapping[str, ResultadoParcial]
    campos_obrigatorios: tuple[CampoEntrada, ...]
    pendencias: tuple[ProblemaValidacao, ...]
    erros: tuple[ProblemaValidacao, ...]
    auditoria: Mapping[str, Any]
    resultado_geral: None = None

    @property
    def complete(self) -> bool:
        return self.definitivo

    @property
    def is_final(self) -> bool:
        return self.definitivo

    @property
    def chapters(self) -> Mapping[str, ResultadoCapitulo]:
        return self.capitulos

    @property
    def area_results(self) -> Mapping[str, ResultadoArea]:
        return self.areas

    @property
    def errors(self) -> tuple[ProblemaValidacao, ...]:
        return self.erros

    @property
    def pending(self) -> tuple[ProblemaValidacao, ...]:
        return self.pendencias


@dataclass(frozen=True)
class _Campo:
    area: str
    codigo: str
    codigo_original: str
    celula: str
    linha: int
    descricao: str
    formula: Optional[str]

    @property
    def chave(self) -> str:
        return f"{self.area}:{self.celula}"


def _column_number(column: str) -> int:
    value = 0
    for char in column.upper():
        value = value * 26 + ord(char) - ord("A") + 1
    return value


def _column_name(number: int) -> str:
    result = ""
    while number:
        number, remainder = divmod(number - 1, 26)
        result = chr(ord("A") + remainder) + result
    return result


def _expand_reference(token: str) -> list[str]:
    match = _CELL_REFERENCE.fullmatch(token.strip())
    if not match:
        raise CatalogoCIFError(f"Referência de célula não suportada: {token!r}")
    start_col = match.group("start_col").upper()
    start_row = int(match.group("start_row"))
    end_col = (match.group("end_col") or start_col).upper()
    end_row = int(match.group("end_row") or start_row)
    if _column_number(end_col) < _column_number(start_col) or end_row < start_row:
        raise CatalogoCIFError(f"Intervalo de células inválido: {token!r}")
    return [
        f"{_column_name(column)}{row}"
        for column in range(_column_number(start_col), _column_number(end_col) + 1)
        for row in range(start_row, end_row + 1)
    ]


def _formula_references(formula: str) -> list[str]:
    """Expande referências de uma fórmula AVERAGE preservando duplicatas."""

    normalized = formula.strip()
    if normalized.startswith("="):
        normalized = normalized[1:].strip()
    match = re.fullmatch(r"AVERAGE\s*\((.*)\)", normalized, re.IGNORECASE)
    if not match:
        raise CatalogoCIFError(f"Fórmula não suportada pelo calculador: {formula!r}")
    arguments = [part.strip() for part in re.split(r"[,;]", match.group(1))]
    if not arguments or any(not argument for argument in arguments):
        raise CatalogoCIFError(f"Fórmula sem argumentos válidos: {formula!r}")
    references: list[str] = []
    for argument in arguments:
        references.extend(_expand_reference(argument))
    return references


def _display_value(value: Fraction) -> float:
    """Arredonda apenas a apresentação final, com duas casas decimais."""

    with localcontext() as context:
        context.prec = max(40, len(str(abs(value.numerator))) + len(str(value.denominator)) + 10)
        decimal_value = Decimal(value.numerator) / Decimal(value.denominator)
        displayed = decimal_value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return float(displayed)


class CalculadorCIF:
    """Calcula uma avaliação CIF usando a árvore de referências do catálogo."""

    def __init__(
        self,
        catalogo: Optional[Mapping[str, Any]] = None,
        *,
        catalog_path: Optional[Path] = None,
    ) -> None:
        if catalogo is not None and catalog_path is not None:
            raise ValueError("Informe catalogo ou catalog_path, não ambos")
        if catalogo is None:
            path = Path(catalog_path) if catalog_path is not None else DEFAULT_CATALOG_PATH
            catalogo = json.loads(path.read_text(encoding="utf-8"))
        self.catalogo = catalogo
        self._areas: OrderedDict[str, dict[str, Any]] = OrderedDict()
        self._campos: dict[str, _Campo] = {}
        self._campos_por_codigo: dict[str, list[_Campo]] = {}
        self._campos_por_celula: dict[str, list[_Campo]] = {}
        self._raizes: dict[str, list[_Campo]] = {}
        self._capitulos: OrderedDict[str, _Campo] = OrderedDict()
        self._construir_indice()

    def _construir_indice(self) -> None:
        areas = self.catalogo.get("areas")
        if not isinstance(areas, list) or not areas:
            raise CatalogoCIFError("O catálogo não contém áreas")
        for area in areas:
            area_code = str(area.get("code", "")).lower()
            if not area_code:
                raise CatalogoCIFError("Área sem código")
            if area_code in self._areas:
                raise CatalogoCIFError(f"Área duplicada: {area_code}")
            nodes = area.get("nodes")
            if not isinstance(nodes, list):
                raise CatalogoCIFError(f"Área sem nós: {area_code}")
            self._areas[area_code] = area
            for node in nodes:
                node_code_original = str(node.get("code", "")).lower()
                node_code = self._codigo_canonico(area_code, node)
                row = int(node.get("source_row", 0))
                description = str(node.get("description", ""))
                for raw_field in node.get("fields", []):
                    cell = str(raw_field.get("value_cell", "")).upper()
                    if not cell:
                        raise CatalogoCIFError(f"Campo sem célula em {area_code}:{node_code}")
                    key = f"{area_code}:{cell}"
                    if key in self._campos:
                        raise CatalogoCIFError(f"Célula duplicada no catálogo: {key}")
                    formula = raw_field.get("formula")
                    if formula is not None:
                        formula = str(formula)
                    field_info = _Campo(
                        area=area_code,
                        codigo=node_code,
                        codigo_original=str(raw_field.get("source_code", node_code_original)).lower(),
                        celula=cell,
                        linha=row,
                        descricao=description,
                        formula=formula,
                    )
                    self._campos[key] = field_info
                    self._campos_por_codigo.setdefault(node_code, []).append(field_info)
                    self._campos_por_codigo.setdefault(field_info.codigo_original, []).append(field_info)
                    self._campos_por_celula.setdefault(cell, []).append(field_info)
                    if node_code == area_code:
                        self._raizes.setdefault(area_code, []).append(field_info)
                    if len(node_code) == 2:
                        # b6/s6 have an additional calculated field for the
                        # Homem variant; the first field remains the default
                        # Mulher field and the variant is selected explicitly.
                        self._capitulos.setdefault(node_code, field_info)

    @staticmethod
    def _codigo_canonico(area_code: str, node: Mapping[str, Any]) -> str:
        code = str(node.get("code", "")).lower()
        # A263/D263 da fonte é e598, mas o título da linha é e595. A fonte
        # continua intacta; somente o índice operacional usa o código canônico.
        if area_code == "e" and int(node.get("source_row", 0)) == 263 and code == "e598":
            return "e595"
        return code

    @property
    def areas(self) -> tuple[str, ...]:
        return tuple(self._areas)

    @property
    def capitulos(self) -> tuple[str, ...]:
        return tuple(self._capitulos)

    def _formula(self, campo: _Campo) -> Optional[str]:
        if campo.area == "b" and campo.celula == "E105":
            # Única alteração autorizada: retirar a segunda ocorrência de E119.
            return "AVERAGE(E106,E112,E118,E119)"
        return campo.formula

    def _referencias(self, campo: _Campo) -> list[str]:
        formula = self._formula(campo)
        if formula is None:
            return []
        return _formula_references(formula)

    def _raiz_para_sexo(self, area_code: str, sexo: str) -> Optional[_Campo]:
        selected_cell = _AREA_ROOT_CELLS.get(area_code, {}).get(sexo)
        roots = self._raizes.get(area_code, [])
        if selected_cell is not None:
            for campo in roots:
                if campo.celula == selected_cell:
                    return campo
        for campo in roots:
            if campo.celula.startswith("E"):
                return campo
        return roots[0] if roots else None

    def _campo_capitulo(self, code: str, sexo: str) -> Optional[_Campo]:
        base = self._capitulos.get(code)
        if base is None:
            return None
        selected_cell = _CHAPTER_VARIANT_CELLS.get((base.area, code), {}).get(sexo)
        if selected_cell is not None:
            for campo in self._campos_por_codigo.get(code, []):
                if campo.celula == selected_cell:
                    return campo
        return base

    def _caminho_referenciado(
        self, sexo: str
    ) -> tuple[OrderedDict[str, _Campo], tuple[ProblemaValidacao, ...]]:
        reachable: OrderedDict[str, _Campo] = OrderedDict()
        problems: list[ProblemaValidacao] = []
        visiting: set[str] = set()

        def visit(area: str, cell: str) -> None:
            key = f"{area}:{cell.upper()}"
            if key in reachable:
                return
            if key in visiting:
                problems.append(
                    ProblemaValidacao(
                        "ciclo_de_referencias",
                        f"Ciclo encontrado na cadeia de referências em {key}",
                        campo=key,
                    )
                )
                return
            campo = self._campos.get(key)
            if campo is None:
                problems.append(
                    ProblemaValidacao(
                        "referencia_desconhecida",
                        f"A fórmula referencia célula ausente no catálogo: {key}",
                        campo=key,
                    )
                )
                return
            visiting.add(key)
            reachable[key] = campo
            for reference in self._referencias(campo):
                visit(area, reference)
            visiting.remove(key)

        for area_code in self._areas:
            root = self._raiz_para_sexo(area_code, sexo)
            if root is None:
                problems.append(
                    ProblemaValidacao(
                        "raiz_de_area_ausente",
                        f"Área sem célula raiz selecionável: {area_code}",
                        campo=area_code,
                    )
                )
            else:
                visit(area_code, root.celula)
        return reachable, tuple(problems)

    def campos_entrada_obrigatorios(self, sexo: str) -> tuple[CampoEntrada, ...]:
        """Retorna as folhas sem fórmula alcançáveis para o sexo informado."""

        if sexo not in SEXES:
            return tuple()
        reachable, _ = self._caminho_referenciado(sexo)
        return tuple(
            CampoEntrada(
                area=campo.area,
                codigo=campo.codigo,
                codigo_original=campo.codigo_original,
                celula=campo.celula,
                linha=campo.linha,
                descricao=campo.descricao,
            )
            for campo in reachable.values()
            if campo.formula is None
        )

    def _campos_obrigatorios_diagnostico(self) -> tuple[CampoEntrada, ...]:
        fields: OrderedDict[str, _Campo] = OrderedDict()
        for sexo in SEXES:
            reachable, _ = self._caminho_referenciado(sexo)
            for key, campo in reachable.items():
                if campo.formula is None:
                    fields[key] = campo
        return tuple(
            CampoEntrada(
                area=campo.area,
                codigo=campo.codigo,
                codigo_original=campo.codigo_original,
                celula=campo.celula,
                linha=campo.linha,
                descricao=campo.descricao,
            )
            for campo in fields.values()
        )

    def _aliases(self, campo: _Campo) -> tuple[str, ...]:
        return (
            campo.codigo,
            campo.codigo_original,
            f"{campo.codigo}@{campo.linha}",
            f"{campo.codigo_original}@{campo.linha}",
        )

    def _resolver_chave(
        self,
        raw_key: Any,
        reachable: Mapping[str, _Campo],
    ) -> tuple[Optional[_Campo], Optional[ProblemaValidacao]]:
        if not isinstance(raw_key, str):
            return None, ProblemaValidacao(
                "codigo_desconhecido", "A chave da resposta deve ser um código CIF ou uma célula", valor=raw_key
            )
        key = raw_key.strip()
        normalized = key.lower()
        exact: Optional[_Campo] = None
        if ":" in normalized:
            area, remainder = normalized.split(":", 1)
            remainder = remainder.upper()
            if re.fullmatch(r"[A-Z]{1,3}\d+", remainder):
                exact = self._campos.get(f"{area}:{remainder}")
            elif "@" in remainder:
                code, row = remainder.rsplit("@", 1)
                candidates = [
                    campo
                    for campo in self._campos.values()
                    if campo.area == area and campo.codigo == code.lower() and str(campo.linha) == row
                ]
                if not candidates:
                    candidates = [
                        campo
                        for campo in self._campos.values()
                        if campo.area == area
                        and campo.codigo_original == code.lower()
                        and str(campo.linha) == row
                    ]
                if len(candidates) == 1:
                    exact = candidates[0]
            if exact is None and area not in self._areas:
                return None, ProblemaValidacao("codigo_desconhecido", f"Área desconhecida na chave {raw_key!r}", valor=raw_key)
        elif re.fullmatch(r"[A-Z]{1,3}\d+", key.upper()):
            cell_candidates = self._campos_por_celula.get(key.upper(), [])
            if len(cell_candidates) == 1:
                exact = cell_candidates[0]

        if exact is not None:
            candidates = [exact]
        else:
            alias = normalized.split(":", 1)[-1]
            if "@" in alias:
                code, row = alias.rsplit("@", 1)
                candidates = [
                    campo
                    for campo in self._campos.values()
                    if campo.codigo == code and str(campo.linha) == row
                ]
            else:
                candidates = [
                    campo
                    for campo in self._campos.values()
                    if alias in self._aliases(campo)
                    and (":" not in normalized or campo.area == normalized.split(":", 1)[0])
                ]
            unique: OrderedDict[str, _Campo] = OrderedDict((campo.chave, campo) for campo in candidates)
            candidates = list(unique.values())

        reachable_candidates = [campo for campo in candidates if campo.chave in reachable]
        if len(reachable_candidates) == 1:
            return reachable_candidates[0], None
        if len(reachable_candidates) > 1:
            return None, ProblemaValidacao(
                "codigo_ambiguo",
                f"O código {raw_key!r} identifica mais de uma ocorrência; use area:célula ou código@linha",
                valor=raw_key,
            )
        if candidates and any(campo.formula is not None for campo in candidates):
            return None, ProblemaValidacao(
                "campo_calculado_somente_leitura",
                f"A célula indicada por {raw_key!r} é calculada e somente leitura",
                campo=candidates[0].chave,
                valor=raw_key,
            )
        if candidates:
            return None, ProblemaValidacao(
                "campo_fora_da_cadeia",
                f"O campo {raw_key!r} não é uma entrada alcançável para esta avaliação",
                campo=candidates[0].chave,
                valor=raw_key,
            )
        return None, ProblemaValidacao(
            "codigo_desconhecido", f"Código ou célula CIF desconhecido: {raw_key!r}", valor=raw_key
        )

    @staticmethod
    def _validar_nota(value: Any) -> bool:
        return isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= 4

    def _valor_resultado(
        self, campo: _Campo, value: Optional[Fraction]
    ) -> ResultadoParcial:
        precise = None if value is None else float(value)
        displayed = None if value is None else _display_value(value)
        return ResultadoParcial(
            codigo=campo.codigo,
            area=campo.area,
            campo=campo.chave,
            valor=displayed,
            valor_interno=precise,
            pendente=value is None,
        )

    def _calcular_valores(
        self,
        reachable: Mapping[str, _Campo],
        input_values: Mapping[str, int],
    ) -> dict[str, Optional[Fraction]]:
        values: dict[str, Optional[Fraction]] = {}
        active: set[str] = set()

        def evaluate(campo: _Campo) -> Optional[Fraction]:
            key = campo.chave
            if key in values:
                return values[key]
            if key in active:
                values[key] = None
                return None
            active.add(key)
            formula = self._formula(campo)
            if formula is None:
                raw_value = input_values.get(key)
                value = None if raw_value is None else Fraction(raw_value)
            else:
                references = self._referencias(campo)
                children = [
                    evaluate(self._campos[f"{campo.area}:{reference}"])
                    for reference in references
                    if f"{campo.area}:{reference}" in reachable
                ]
                if len(children) != len(references) or any(child is None for child in children):
                    value = None
                else:
                    value = sum(children, Fraction(0, 1)) / len(children)
            active.remove(key)
            values[key] = value
            return value

        for campo in reachable.values():
            evaluate(campo)
        return values

    def _output_capitulos(
        self,
        sexo: Optional[str],
        values: Mapping[str, Optional[Fraction]],
    ) -> Mapping[str, ResultadoCapitulo]:
        result: OrderedDict[str, ResultadoCapitulo] = OrderedDict()
        for code, base in self._capitulos.items():
            campo = self._campo_capitulo(code, sexo) if sexo in SEXES else None
            value = None if campo is None else values.get(campo.chave)
            partial = self._valor_resultado(campo, value) if campo is not None else ResultadoParcial(
                codigo=code,
                area=base.area,
                campo=f"{base.area}:indisponível",
                valor=None,
                valor_interno=None,
                pendente=True,
            )
            result[code] = ResultadoCapitulo(**partial.__dict__)
        return MappingProxyType(result)

    def _output_areas(
        self,
        sexo: Optional[str],
        values: Mapping[str, Optional[Fraction]],
    ) -> Mapping[str, ResultadoArea]:
        result: OrderedDict[str, ResultadoArea] = OrderedDict()
        for area_code, area in self._areas.items():
            campo = self._raiz_para_sexo(area_code, sexo) if sexo in SEXES else None
            value = None if campo is None else values.get(campo.chave)
            partial = self._valor_resultado(campo, value) if campo is not None else ResultadoParcial(
                codigo=area_code,
                area=area_code,
                campo=f"{area_code}:indisponível",
                valor=None,
                valor_interno=None,
                pendente=True,
            )
            result[area_code] = ResultadoArea(**partial.__dict__, nome=str(area.get("name", "")))
        return MappingProxyType(result)

    def _output_intermediarios(
        self,
        reachable: Mapping[str, _Campo],
        values: Mapping[str, Optional[Fraction]],
    ) -> Mapping[str, ResultadoParcial]:
        result: OrderedDict[str, ResultadoParcial] = OrderedDict()
        for key, campo in reachable.items():
            if self._formula(campo) is not None:
                result[key] = self._valor_resultado(campo, values.get(key))
        return MappingProxyType(result)

    def _auditoria(self) -> Mapping[str, Any]:
        corrections = []
        field = self._campos.get("b:E105")
        if field is not None and field.formula is not None:
            corrections.append(
                {
                    "area": "b",
                    "celula": "E105",
                    "formula_original": field.formula,
                    "formula_aplicada": self._formula(field),
                }
            )
        divergences = []
        field = self._campos.get("e:E263")
        if field is not None and field.codigo_original == "e598" and field.codigo == "e595":
            divergences.append(
                {
                    "area": "e",
                    "celula": "E263",
                    "linha": field.linha,
                    "codigo_original": "e598",
                    "codigo_canonico": "e595",
                }
            )
        return MappingProxyType(
            {
                "formula_correcoes": tuple(corrections),
                "divergencias_de_codigo": tuple(divergences),
                "resultado_geral_clinico": None,
            }
        )

    def calcular(self, entrada: EntradaCIF) -> ResultadoCIF:
        """Valida e calcula uma avaliação, sem arredondar a árvore intermediária."""

        if not isinstance(entrada, EntradaCIF):
            raise TypeError("calcular espera uma EntradaCIF")

        sex_valid = entrada.sexo in SEXES
        if sex_valid:
            reachable, chain_problems = self._caminho_referenciado(entrada.sexo)  # type: ignore[arg-type]
            required = self.campos_entrada_obrigatorios(entrada.sexo)  # type: ignore[arg-type]
        else:
            reachable = OrderedDict()
            chain_problems = tuple()
            required = self._campos_obrigatorios_diagnostico()

        errors: list[ProblemaValidacao] = list(chain_problems)
        pendencias: list[ProblemaValidacao] = []
        if entrada.sexo is None or (isinstance(entrada.sexo, str) and not entrada.sexo.strip()):
            pendencias.append(ProblemaValidacao("sexo_ausente", "Sexo obrigatório para selecionar a variante CIF", campo="sexo"))
        elif not sex_valid:
            errors.append(
                ProblemaValidacao(
                    "sexo_invalido",
                    "Sexo deve ser exatamente Masculino ou Feminino",
                    campo="sexo",
                    valor=entrada.sexo,
                )
            )

        input_values: dict[str, int] = {}
        assigned: set[str] = set()
        response_reachable = reachable if sex_valid else {
            campo.chave: campo for campo in self._campos_obrigatorios_diagnostico()  # type: ignore[misc]
        }
        for raw_key, raw_value in entrada.respostas.items():
            campo, problem = self._resolver_chave(raw_key, response_reachable)
            if problem is not None:
                errors.append(problem)
                continue
            assert campo is not None
            if campo.chave in assigned:
                errors.append(
                    ProblemaValidacao(
                        "resposta_duplicada",
                        f"Mais de uma chave foi usada para a mesma célula {campo.chave}",
                        campo=campo.chave,
                        valor=raw_key,
                    )
                )
                continue
            assigned.add(campo.chave)
            if campo.formula is not None:
                errors.append(
                    ProblemaValidacao(
                        "campo_calculado_somente_leitura",
                        f"A célula {campo.chave} é calculada e somente leitura",
                        campo=campo.chave,
                        valor=raw_value,
                    )
                )
                continue
            if raw_value is None or (isinstance(raw_value, str) and not raw_value.strip()):
                continue
            if not self._validar_nota(raw_value):
                errors.append(
                    ProblemaValidacao(
                        "nota_invalida",
                        "A nota deve ser um inteiro de 0 a 4; decimais não são aceitos",
                        campo=campo.chave,
                        valor=raw_value,
                    )
                )
                continue
            input_values[campo.chave] = raw_value

        required_by_key = {field_info.chave: field_info for field_info in required}
        for key, field_info in required_by_key.items():
            if key not in input_values:
                pendencias.append(
                    ProblemaValidacao(
                        "campo_obrigatorio_ausente",
                        "Campo de entrada obrigatório sem nota; 0 deve ser informado explicitamente",
                        campo=key,
                    )
                )

        values: dict[str, Optional[Fraction]] = {}
        if sex_valid:
            values = self._calcular_valores(reachable, input_values)
        chapters = self._output_capitulos(entrada.sexo if sex_valid else None, values)
        areas = self._output_areas(entrada.sexo if sex_valid else None, values)
        intermediarios = self._output_intermediarios(reachable, values)
        definitive = sex_valid and not errors and not pendencias
        if errors:
            status = "invalida"
        elif not definitive:
            status = "pendente"
        else:
            status = "completa"
        return ResultadoCIF(
            status=status,
            definitivo=definitive,
            sexo=entrada.sexo,
            capitulos=chapters,
            areas=areas,
            intermediarios=intermediarios,
            campos_obrigatorios=required,
            pendencias=tuple(pendencias),
            erros=tuple(errors),
            auditoria=self._auditoria(),
            resultado_geral=None,
        )

    def calculate(self, entrada: EntradaCIF) -> ResultadoCIF:
        """Alias em inglês para facilitar uso por consumidores externos."""

        return self.calcular(entrada)


CalculatorCIF = CalculadorCIF
InputCIF = EntradaCIF
OutputCIF = ResultadoCIF


__all__ = [
    "CalculadorCIF",
    "CalculatorCIF",
    "CatalogoCIFError",
    "CampoEntrada",
    "EntradaCIF",
    "InputCIF",
    "OutputCIF",
    "ProblemaValidacao",
    "ResultadoArea",
    "ResultadoCIF",
    "ResultadoCapitulo",
    "ResultadoParcial",
]
