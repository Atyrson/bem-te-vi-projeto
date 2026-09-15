import unittest

try:
    from calculador import CalculadorCIF, EntradaCIF
except ModuleNotFoundError:  # pragma: no cover - permite executar pelo diretório raiz
    from scripts.cif.calculador import CalculadorCIF, EntradaCIF


def _node(code, row, cell, formula=None, description=None):
    return {
        "code": code,
        "description": description or code,
        "source_row": row,
        "fields": [
            {
                "code_cell": f"D{row}",
                "source_code": code,
                "value_cell": cell,
                "kind_observed": "calculated" if formula else "input_candidate",
                "formula": formula,
            }
        ],
    }


def _hierarchy_catalog():
    return {
        "schema_version": 1,
        "catalog_version": "test",
        "areas": [
            {
                "code": "b",
                "name": "Teste",
                "nodes": [
                    _node("b", 1, "E1", "AVERAGE(E2)"),
                    _node("b1", 2, "E2", "AVERAGE(E3,E4)"),
                    _node("b10", 3, "E3", "AVERAGE(E5:E6)"),
                    _node("b100", 5, "E5"),
                    _node("b101", 6, "E6"),
                    _node("b11", 4, "E4"),
                ],
            }
        ],
    }


def _rounding_catalog():
    return {
        "schema_version": 1,
        "catalog_version": "test",
        "areas": [
            {
                "code": "b",
                "name": "Teste de precisão",
                "nodes": [
                    _node("b", 1, "E1", "AVERAGE(E2)"),
                    _node("b1", 2, "E2", "AVERAGE(E3,E4)"),
                    _node("b10", 3, "E3", "AVERAGE(E5:E10)"),
                    _node("b100", 5, "E5"),
                    _node("b101", 6, "E6"),
                    _node("b102", 7, "E7"),
                    _node("b103", 8, "E8"),
                    _node("b104", 9, "E9"),
                    _node("b105", 10, "E10"),
                    _node("b11", 4, "E4"),
                ],
            }
        ],
    }


class CalculadorCIFTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.calculador = CalculadorCIF()

    def respostas(self, sexo="Feminino", valor=0):
        return {campo.chave: valor for campo in self.calculador.campos_entrada_obrigatorios(sexo)}

    def test_todos_os_valores_zero_sao_validos_e_completos(self):
        for sexo in ("Feminino", "Masculino"):
            with self.subTest(sexo=sexo):
                resultado = self.calculador.calcular(EntradaCIF(sexo, self.respostas(sexo, 0)))
                self.assertEqual(resultado.status, "completa")
                self.assertTrue(resultado.definitivo)
                self.assertEqual(len(resultado.capitulos), 30)
                self.assertEqual(len(resultado.areas), 4)
                self.assertTrue(all(item.valor == 0 for item in resultado.capitulos.values()))
                self.assertTrue(all(item.valor == 0 for item in resultado.areas.values()))

    def test_todos_os_valores_quatro_sao_completos(self):
        resultado = self.calculador.calcular(EntradaCIF("Feminino", self.respostas(valor=4)))
        self.assertEqual(resultado.status, "completa")
        self.assertTrue(resultado.definitivo)
        self.assertTrue(all(item.valor == 4 for item in resultado.capitulos.values()))
        self.assertTrue(all(item.valor == 4 for item in resultado.areas.values()))

    def test_campo_vazio_deixa_avaliacao_pendente(self):
        respostas = self.respostas()
        campo = next(iter(respostas))
        respostas.pop(campo)
        resultado = self.calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertEqual(resultado.status, "pendente")
        self.assertFalse(resultado.definitivo)
        self.assertIn(campo, {item.campo for item in resultado.pendencias})

    def test_zero_explicito_nao_e_confundido_com_ausencia(self):
        respostas = self.respostas(valor=0)
        resultado = self.calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertTrue(resultado.definitivo)
        self.assertEqual(resultado.areas["b"].valor, 0)
        self.assertNotIn("b:E9", {item.campo for item in resultado.pendencias})

    def test_decimal_e_rejeitado(self):
        respostas = self.respostas()
        campo = next(iter(respostas))
        respostas[campo] = 1.0
        resultado = self.calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertFalse(resultado.definitivo)
        self.assertEqual(resultado.status, "invalida")
        self.assertIn("nota_invalida", {item.codigo for item in resultado.erros})
        self.assertIn(campo, {item.campo for item in resultado.erros})

    def test_hierarquia_com_grupos_de_tamanhos_diferentes_calcula_media_dos_grupos(self):
        calculador = CalculadorCIF(_hierarchy_catalog())
        respostas = {"b:E5": 0, "b:E6": 4, "b:E4": 4}
        resultado = calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertTrue(resultado.definitivo)
        self.assertEqual(resultado.intermediarios["b:E3"].valor, 2)
        self.assertEqual(resultado.capitulos["b1"].valor, 3)
        self.assertEqual(resultado.areas["b"].valor, 3)

    def test_repeticao_de_e119_e_removida_apenas_no_calculo(self):
        respostas = self.respostas()
        respostas["b:E119"] = 4
        resultado = self.calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertEqual(resultado.intermediarios["b:E105"].valor_interno, 1.0)
        correction = resultado.auditoria["formula_correcoes"][0]
        self.assertEqual(correction["formula_original"], "AVERAGE(E106,E112,E118,E119,E119)")
        self.assertEqual(correction["formula_aplicada"], "AVERAGE(E106,E112,E118,E119)")

    def test_variantes_mulher_homem_para_b6(self):
        mulher = self.respostas("Feminino")
        mulher["b:E408"] = 4
        resultado_mulher = self.calculador.calcular(EntradaCIF("Feminino", mulher))
        resultado_homem = self.calculador.calcular(EntradaCIF("Masculino", self.respostas("Masculino")))
        self.assertTrue(resultado_mulher.definitivo)
        self.assertTrue(resultado_homem.definitivo)
        self.assertGreater(resultado_mulher.capitulos["b6"].valor_interno, 0)
        self.assertEqual(resultado_homem.capitulos["b6"].valor, 0)
        self.assertEqual(resultado_mulher.capitulos["b6"].campo, "b:E384")
        self.assertEqual(resultado_homem.capitulos["b6"].campo, "b:I384")

    def test_variantes_mulher_homem_para_s6_e_s630(self):
        mulher = self.calculador.calcular(EntradaCIF("Feminino", self.respostas("Feminino")))
        homem_respostas = self.respostas("Masculino")
        homem_respostas["s:E197"] = 4
        homem = self.calculador.calcular(EntradaCIF("Masculino", homem_respostas))
        self.assertEqual(mulher.capitulos["s6"].campo, "s:E173")
        self.assertEqual(homem.capitulos["s6"].campo, "s:H173")
        self.assertEqual(mulher.intermediarios["s:E183"].valor, 0)
        self.assertEqual(homem.intermediarios["s:G183"].valor, 1)

    def test_arredondamento_ocorre_somente_na_apresentacao(self):
        calculador = CalculadorCIF(_rounding_catalog())
        respostas = {f"b:E{row}": 0 for row in range(5, 11)}
        respostas["b:E5"] = 1
        respostas["b:E4"] = 0
        resultado = calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertTrue(resultado.definitivo)
        self.assertAlmostEqual(resultado.intermediarios["b:E3"].valor_interno, 1 / 6)
        self.assertEqual(resultado.intermediarios["b:E3"].valor, 0.17)
        self.assertAlmostEqual(resultado.capitulos["b1"].valor_interno, 1 / 12)
        self.assertEqual(resultado.capitulos["b1"].valor, 0.08)
        self.assertEqual(resultado.areas["b"].valor, 0.08)

    def test_codigo_desconhecido_e_rejeitado(self):
        resultado = self.calculador.calcular(EntradaCIF("Feminino", {"codigo-inexistente": 0}))
        self.assertFalse(resultado.definitivo)
        self.assertIn("codigo_desconhecido", {item.codigo for item in resultado.erros})

    def test_sexo_ausente_fica_pendente_e_outro_e_rejeitado(self):
        ausente = self.calculador.calcular(EntradaCIF(None, {}))
        outro = self.calculador.calcular(EntradaCIF("Outro", {}))
        self.assertEqual(ausente.status, "pendente")
        self.assertFalse(ausente.definitivo)
        self.assertIn("sexo_ausente", {item.codigo for item in ausente.pendencias})
        self.assertEqual(outro.status, "invalida")
        self.assertFalse(outro.definitivo)
        self.assertIn("sexo_invalido", {item.codigo for item in outro.erros})

    def test_calculadas_sao_somente_leitura(self):
        resultado = self.calculador.calcular(EntradaCIF("Feminino", {"b:E8": 1}))
        self.assertIn("campo_calculado_somente_leitura", {item.codigo for item in resultado.erros})
        self.assertFalse(resultado.definitivo)

    def test_e13_fica_fora_da_media_e_divergencia_e595_e_auditada(self):
        respostas = self.respostas()
        respostas["b:E13"] = 4
        resultado = self.calculador.calcular(EntradaCIF("Feminino", respostas))
        self.assertFalse(resultado.definitivo)
        self.assertNotIn("b:E13", {campo.chave for campo in resultado.campos_obrigatorios})
        self.assertEqual(resultado.intermediarios["b:E8"].valor, 0)
        self.assertEqual(resultado.intermediarios["e:E263"].codigo, "e595")
        divergence = resultado.auditoria["divergencias_de_codigo"][0]
        self.assertEqual(divergence["codigo_original"], "e598")
        self.assertEqual(divergence["codigo_canonico"], "e595")


if __name__ == "__main__":
    unittest.main()
