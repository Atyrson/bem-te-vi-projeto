"""Registro dos motores CIF suportados pela API.

Cada combinação de catálogo e regras aponta para uma instância explícita do
calculador oficial. Rascunhos nunca são recalculados silenciosamente por uma
combinação diferente daquela registrada na criação.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import sys
from typing import Any, Mapping


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.cif.calculador import CalculadorCIF  # noqa: E402


class CIFVersaoNaoSuportada(LookupError):
    def __init__(self, catalogo_versao: str, regras_versao: str):
        super().__init__(
            f"Versão CIF não suportada: catálogo={catalogo_versao}, regras={regras_versao}"
        )
        self.catalogo_versao = catalogo_versao
        self.regras_versao = regras_versao


@dataclass(frozen=True)
class CIFMotorVersionado:
    catalogo_versao: str
    regras_versao: str
    catalogo: Mapping[str, Any]
    calculador: CalculadorCIF

    @property
    def chave(self) -> tuple[str, str]:
        return self.catalogo_versao, self.regras_versao


def _carregar_motor(catalog_path: Path, regras_versao: str) -> CIFMotorVersionado:
    catalogo = json.loads(catalog_path.read_text(encoding="utf-8"))
    return CIFMotorVersionado(
        catalogo_versao=str(catalogo["catalog_version"]),
        regras_versao=regras_versao,
        catalogo=catalogo,
        calculador=CalculadorCIF(catalog_path=catalog_path),
    )


CATALOG_PATH = PROJECT_ROOT / "catalogos" / "cif" / "catalogo.v0.1.json"
MOTOR_ATIVO = _carregar_motor(CATALOG_PATH, "0.1.0-pending-review")
MOTORES_SUPORTADOS = {MOTOR_ATIVO.chave: MOTOR_ATIVO}


def obter_motor(catalogo_versao: str, regras_versao: str) -> CIFMotorVersionado:
    try:
        return MOTORES_SUPORTADOS[(catalogo_versao, regras_versao)]
    except KeyError as exc:
        raise CIFVersaoNaoSuportada(catalogo_versao, regras_versao) from exc


__all__ = [
    "CATALOG_PATH",
    "CIFMotorVersionado",
    "CIFVersaoNaoSuportada",
    "MOTOR_ATIVO",
    "MOTORES_SUPORTADOS",
    "obter_motor",
]
