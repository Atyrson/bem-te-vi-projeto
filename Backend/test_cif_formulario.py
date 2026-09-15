"""Testes do contrato de formulário CIF contra o calculador oficial."""

from __future__ import annotations

from copy import deepcopy
import unittest

try:
    from cif_formulario import construir_formulario
    from cif_versions import MOTOR_ATIVO
except ModuleNotFoundError:  # pragma: no cover - descoberta a partir da raiz.
    from Backend.cif_formulario import construir_formulario
    from Backend.cif_versions import MOTOR_ATIVO


class CIFFormularioTest(unittest.TestCase):
    def setUp(self):
        self.catalogo_original = deepcopy(MOTOR_ATIVO.catalogo)

    def test_formularios_correspondem_exatamente_ao_calculador_e_preservam_ordem(self):
        formularios = {
            sexo: construir_formulario(MOTOR_ATIVO, sexo)
            for sexo in ("Feminino", "Masculino")
        }

        for sexo, formulario in formularios.items():
            with self.subTest(sexo=sexo):
                calculador = MOTOR_ATIVO.calculador
                campos_calculador = calculador.campos_entrada_obrigatorios(sexo)
                self.assertEqual(
                    [campo.chave for campo in formulario.campos],
                    [campo.chave for campo in campos_calculador],
                )
                self.assertEqual(
                    [campo.codigo for campo in formulario.campos],
                    [campo.codigo for campo in campos_calculador],
                )
                self.assertEqual(formulario.total_campos, len(campos_calculador))
                self.assertEqual(formulario.catalogo_versao, MOTOR_ATIVO.catalogo_versao)
                self.assertEqual(formulario.regras_versao, MOTOR_ATIVO.regras_versao)
                self.assertEqual(
                    [campo.ordem for campo in formulario.campos],
                    list(range(1, len(campos_calculador) + 1)),
                )

    def test_campos_sao_entradas_unicas_com_metadados_e_sem_calculadas(self):
        campos_catalogo = {
            f"{area['code']}:{field['value_cell']}": field
            for area in MOTOR_ATIVO.catalogo["areas"]
            for node in area["nodes"]
            for field in node.get("fields", [])
        }
        for sexo in ("Feminino", "Masculino"):
            formulario = construir_formulario(MOTOR_ATIVO, sexo)
            chaves = [campo.chave for campo in formulario.campos]
            self.assertEqual(len(chaves), len(set(chaves)))
            self.assertTrue(all(":" in chave for chave in chaves))
            self.assertTrue(
                all(campos_catalogo[chave]["formula"] is None for chave in chaves)
            )
            self.assertTrue(
                all(
                    campo.descricao
                    and campo.area_codigo
                    and campo.area_descricao
                    and campo.capitulo_codigo
                    and campo.capitulo_descricao
                    for campo in formulario.campos
                )
            )
            self.assertTrue(all(campo.obrigatorio_na_conclusao for campo in formulario.campos))
            self.assertEqual(formulario.escala.valores_permitidos, [0, 1, 2, 3, 4])
            self.assertTrue(formulario.escala.permite_sem_resposta_no_rascunho)
            self.assertTrue(formulario.escala.obrigatoria_na_conclusao)

        feminino = construir_formulario(MOTOR_ATIVO, "Feminino")
        masculino = construir_formulario(MOTOR_ATIVO, "Masculino")
        self.assertNotEqual(
            {campo.chave for campo in feminino.campos},
            {campo.chave for campo in masculino.campos},
        )

    def test_catalogo_bruto_nao_e_modificado(self):
        construir_formulario(MOTOR_ATIVO, "Feminino")
        construir_formulario(MOTOR_ATIVO, "Masculino")
        self.assertEqual(MOTOR_ATIVO.catalogo, self.catalogo_original)

    def test_sexo_invalido_nao_monta_formulario(self):
        for sexo in (None, "", "Outro", "feminino", "MASCULINO"):
            with self.subTest(sexo=sexo):
                with self.assertRaises(ValueError):
                    construir_formulario(MOTOR_ATIVO, sexo)  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()
