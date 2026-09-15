"""Testes HTTP do fluxo CIF sem acessar o banco de desenvolvimento."""

from __future__ import annotations

from dataclasses import replace
from datetime import datetime
import unittest

from fastapi import FastAPI
from fastapi.testclient import TestClient

try:
    import cif_api
    from cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        mesclar_respostas,
    )
except ModuleNotFoundError:  # pragma: no cover - descoberta a partir da raiz.
    from Backend import cif_api
    from Backend.cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        mesclar_respostas,
    )


class MemoriaCIF:
    """Repositório em memória injetado somente nos testes HTTP."""

    def __init__(self):
        self.pacientes = {}
        self.avaliacoes = {}
        self.proximo_id = 1

    def paciente(self, paciente_id, sexo):
        self.pacientes[paciente_id] = sexo

    def criar(
        self,
        paciente_id,
        data_avaliacao,
        respostas,
        catalogo_versao,
        regras_versao,
        validar_rascunho,
    ):
        if paciente_id not in self.pacientes:
            raise CIFPacienteNaoEncontrado
        validar_rascunho(
            catalogo_versao,
            regras_versao,
            self.pacientes[paciente_id],
            respostas,
        )
        agora = datetime.now()
        registro = CIFAvaliacaoRegistro(
            id=self.proximo_id,
            paciente_id=paciente_id,
            data_avaliacao=data_avaliacao,
            status="rascunho",
            catalogo_versao=catalogo_versao,
            regras_versao=regras_versao,
            respostas=dict(respostas),
            resultados=None,
            criado_em=agora,
            atualizado_em=agora,
            concluido_em=None,
        )
        self.avaliacoes[self.proximo_id] = registro
        self.proximo_id += 1
        return registro

    def _get(self, paciente_id, avaliacao_id):
        registro = self.avaliacoes.get(avaliacao_id)
        if registro is None or registro.paciente_id != paciente_id:
            raise CIFAvaliacaoNaoEncontrada
        return registro

    def obter_com_sexo(self, paciente_id, avaliacao_id):
        registro = self._get(paciente_id, avaliacao_id)
        return registro, self.pacientes[paciente_id]

    def listar(self, paciente_id):
        if paciente_id not in self.pacientes:
            raise CIFPacienteNaoEncontrado
        return sorted(
            (item for item in self.avaliacoes.values() if item.paciente_id == paciente_id),
            key=lambda item: (item.data_avaliacao, item.id),
            reverse=True,
        )

    def atualizar_rascunho(
        self,
        paciente_id,
        avaliacao_id,
        respostas,
        data_avaliacao,
        validar_rascunho,
    ):
        registro = self._get(paciente_id, avaliacao_id)
        if registro.status == "concluida":
            raise CIFAvaliacaoConcluida
        atualizadas = mesclar_respostas(registro.respostas, respostas)
        validar_rascunho(
            registro.catalogo_versao,
            registro.regras_versao,
            self.pacientes[paciente_id],
            atualizadas,
        )
        atualizado = replace(
            registro,
            data_avaliacao=data_avaliacao or registro.data_avaliacao,
            respostas=atualizadas,
            atualizado_em=datetime.now(),
        )
        self.avaliacoes[avaliacao_id] = atualizado
        return atualizado

    def concluir(
        self,
        paciente_id,
        avaliacao_id,
        respostas_patch,
        calcular,
        serializar_resultado,
    ):
        registro = self._get(paciente_id, avaliacao_id)
        respostas = mesclar_respostas(registro.respostas, respostas_patch)
        if registro.status == "concluida":
            if respostas != registro.respostas:
                raise CIFAvaliacaoConcluida
            return registro
        resultado = calcular(
            registro.catalogo_versao,
            registro.regras_versao,
            self.pacientes[paciente_id],
            respostas,
        )
        if not resultado.definitivo:
            raise CIFCalculoInvalido(resultado)
        concluida = replace(
            registro,
            status="concluida",
            respostas=respostas,
            resultados=serializar_resultado(resultado),
            atualizado_em=datetime.now(),
            concluido_em=datetime.now(),
        )
        self.avaliacoes[avaliacao_id] = concluida
        return concluida


class CIFAvaliacaoAPITest(unittest.TestCase):
    def setUp(self):
        self.memoria = MemoriaCIF()
        self.memoria.paciente(10, "Feminino")
        self.memoria.paciente(20, "Masculino")
        self.app = FastAPI()
        self.app.include_router(cif_api.router)
        self.app.dependency_overrides[cif_api.obter_repositorio_cif] = lambda: self.memoria
        self.client = TestClient(self.app)

    def tearDown(self):
        self.client.close()
        self.app.dependency_overrides.clear()

    def respostas_validas(self, sexo="Feminino", valor=0):
        return {
            campo.chave: valor
            for campo in cif_api.calculator.campos_entrada_obrigatorios(sexo)
        }

    def criar(self, paciente_id=10, respostas=None):
        response = self.client.post(
            "/api/v1/cif-avaliacoes",
            json={"paciente_id": paciente_id, "respostas": respostas or {}},
        )
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def test_catalogo_e_openapi_disponiveis_sem_patient_id_duplicado(self):
        response = self.client.get("/api/v1/cif/catalogo")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["catalog_version"], cif_api.CATALOG_VERSION)
        self.assertEqual(response.json()["rules_version"], cif_api.RULES_VERSION)

        schema = self.app.openapi()
        generic = schema["paths"]["/api/v1/cif-avaliacoes"]["post"]
        nested = schema["paths"]["/api/v1/patients/{patient_id}/cif-avaliacoes"]
        self.assertEqual(generic.get("parameters", []), [])
        self.assertIn("post", nested)

    def test_formulario_dinamico_por_sexo_e_openapi(self):
        feminino = self.client.get("/api/v1/cif/formulario?sexo=Feminino")
        masculino = self.client.get("/api/v1/cif/formulario?sexo=Masculino")

        self.assertEqual(feminino.status_code, 200, feminino.text)
        self.assertEqual(masculino.status_code, 200, masculino.text)
        feminino_data = feminino.json()
        masculino_data = masculino.json()
        self.assertEqual(feminino_data["sexo"], "Feminino")
        self.assertEqual(masculino_data["sexo"], "Masculino")
        self.assertEqual(
            feminino_data["total_campos"],
            len(cif_api.calculator.campos_entrada_obrigatorios("Feminino")),
        )
        self.assertEqual(
            masculino_data["total_campos"],
            len(cif_api.calculator.campos_entrada_obrigatorios("Masculino")),
        )
        self.assertNotEqual(
            [campo["chave"] for campo in feminino_data["campos"]],
            [campo["chave"] for campo in masculino_data["campos"]],
        )
        self.assertEqual(feminino_data["escala"]["valores_permitidos"], [0, 1, 2, 3, 4])

        schema = self.app.openapi()
        endpoint = schema["paths"]["/api/v1/cif/formulario"]["get"]
        self.assertEqual(
            endpoint["responses"]["200"]["content"]["application/json"]["schema"]["$ref"],
            "#/components/schemas/CIFFormularioResposta",
        )

    def test_formulario_rejeita_sexo_ausente_vazio_outro_e_grafias_diferentes(self):
        for query in ("", "?sexo=", "?sexo=Outro", "?sexo=feminino", "?sexo=FEMININO"):
            with self.subTest(query=query):
                response = self.client.get(f"/api/v1/cif/formulario{query}")
                self.assertEqual(response.status_code, 422, response.text)
                self.assertIn("sexo", response.text)

    def test_cria_atualiza_previa_e_retoma_rascunho(self):
        draft = self.criar()
        key = next(iter(self.respostas_validas()))
        updated = self.client.patch(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}",
            json={"respostas": {key: 0}},
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        preview = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}/previa",
            json={},
        )
        self.assertEqual(preview.status_code, 200)
        self.assertFalse(preview.json()["definitivo"])
        resumed = self.client.get(f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}")
        self.assertEqual(resumed.status_code, 200)
        self.assertEqual(resumed.json()["respostas"], {key: 0})

    def test_criacao_aninhada_usa_apenas_paciente_da_rota(self):
        response = self.client.post(
            "/api/v1/patients/10/cif-avaliacoes", json={"respostas": {}}
        )
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()["paciente_id"], 10)
        duplicated = self.client.post(
            "/api/v1/patients/10/cif-avaliacoes",
            json={"paciente_id": 20, "respostas": {}},
        )
        self.assertEqual(duplicated.status_code, 422)

    def test_rascunho_rejeita_respostas_invalidas_sem_persistir(self):
        key = next(iter(self.respostas_validas()))
        for respostas, codigo in (
            ({key: 1.5}, "nota_invalida"),
            ({"b:E8": 1}, "campo_calculado_somente_leitura"),
            ({"codigo-inexistente": 1}, "codigo_desconhecido"),
        ):
            with self.subTest(codigo=codigo):
                response = self.client.post(
                    "/api/v1/cif-avaliacoes",
                    json={"paciente_id": 10, "respostas": respostas},
                )
                self.assertEqual(response.status_code, 422, response.text)
                self.assertIn(codigo, response.text)
        self.assertEqual(self.memoria.avaliacoes, {})

    def test_atualizacao_invalida_preserva_estado_anterior(self):
        key = next(iter(self.respostas_validas()))
        draft = self.criar(respostas={key: 0})
        response = self.client.patch(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}",
            json={"respostas": {"b:E8": 4}},
        )
        self.assertEqual(response.status_code, 422, response.text)
        self.assertEqual(self.memoria.avaliacoes[draft["id"]].respostas, {key: 0})

    def test_conclusao_valida_persiste_resultados_e_e_idempotente(self):
        draft = self.criar(respostas=self.respostas_validas())
        endpoint = f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}/concluir"
        first = self.client.post(endpoint, json={})
        self.assertEqual(first.status_code, 200, first.text)
        data = first.json()
        self.assertEqual(data["status"], "concluida")
        self.assertIsNotNone(data["resultados"])
        self.assertEqual(data["catalogo_versao"], cif_api.CATALOG_VERSION)
        self.assertEqual(data["regras_versao"], cif_api.RULES_VERSION)

        repeated = self.client.post(endpoint, json={})
        self.assertEqual(repeated.status_code, 200, repeated.text)
        self.assertEqual(repeated.json()["id"], data["id"])
        self.assertEqual(len(self.memoria.avaliacoes), 1)

        blocked = self.client.patch(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}",
            json={"respostas": {"b:E9": 1}},
        )
        self.assertEqual(blocked.status_code, 409)

    def test_campos_ausentes_e_sexo_invalido_bloqueiam_apenas_conclusao(self):
        incomplete = self.criar()
        response = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{incomplete['id']}/concluir",
            json={},
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("campo_obrigatorio_ausente", response.text)

        self.memoria.paciente(30, None)
        self.memoria.paciente(40, "Outro")
        for paciente_id, codigo in ((30, "sexo_ausente"), (40, "sexo_invalido")):
            draft = self.criar(paciente_id, self.respostas_validas())
            response = self.client.post(
                f"/api/v1/patients/{paciente_id}/cif-avaliacoes/{draft['id']}/concluir",
                json={},
            )
            self.assertEqual(response.status_code, 422)
            self.assertIn(codigo, response.text)

    def test_versao_incompativel_bloqueia_previa_atualizacao_e_conclusao(self):
        draft = self.criar()
        self.memoria.avaliacoes[draft["id"]] = replace(
            self.memoria.avaliacoes[draft["id"]],
            catalogo_versao="catalogo-antigo",
        )
        base = f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}"
        responses = (
            self.client.post(f"{base}/previa", json={}),
            self.client.patch(base, json={"respostas": {"b:E9": 0}}),
            self.client.post(f"{base}/concluir", json={}),
        )
        for response in responses:
            self.assertEqual(response.status_code, 409, response.text)
            self.assertEqual(response.json()["detail"]["code"], "versao_cif_incompativel")
        self.assertEqual(self.memoria.avaliacoes[draft["id"]].status, "rascunho")

    def test_multiplas_avaliacoes_e_isolamento_por_paciente(self):
        first = self.criar(10)
        second = self.criar(10)
        other = self.criar(20)
        listing = self.client.get("/api/v1/patients/10/cif-avaliacoes")
        self.assertEqual(listing.status_code, 200)
        self.assertEqual({item["id"] for item in listing.json()}, {first["id"], second["id"]})
        leaked = self.client.get(f"/api/v1/patients/10/cif-avaliacoes/{other['id']}")
        self.assertEqual(leaked.status_code, 404)

    def test_resultados_do_cliente_nao_fazem_parte_do_contrato(self):
        draft = self.criar()
        response = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}/concluir",
            json={"resultados": {"areas": {"b": {"valor": 999}}}},
        )
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()
