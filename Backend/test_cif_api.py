"""Testes de contrato do fluxo CIF sem executar seed ou alterar banco."""

from __future__ import annotations

from datetime import date, datetime
import re
import unittest

from fastapi import FastAPI, HTTPException
from pydantic import ValidationError

try:
    import cif_api
    from cif_models import CIFAvaliacaoAtualizar, CIFAvaliacaoCriar, CIFAvaliacaoOperacao
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
    from Backend.cif_models import CIFAvaliacaoAtualizar, CIFAvaliacaoCriar, CIFAvaliacaoOperacao
    from Backend.cif_repository import (
        CIFAvaliacaoConcluida,
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRegistro,
        CIFCalculoInvalido,
        CIFPacienteNaoEncontrado,
        mesclar_respostas,
    )


class MemoriaCIF:
    """Substituto transacional pequeno para testar o contrato HTTP."""

    def __init__(self):
        self.pacientes = {}
        self.avaliacoes = {}
        self.proximo_id = 1

    def paciente(self, paciente_id, sexo):
        self.pacientes[paciente_id] = sexo

    def criar(self, paciente_id, data_avaliacao, respostas, catalogo_versao, regras_versao):
        if paciente_id not in self.pacientes:
            raise CIFPacienteNaoEncontrado
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

    def atualizar_rascunho(self, paciente_id, avaliacao_id, respostas, data_avaliacao):
        registro = self._get(paciente_id, avaliacao_id)
        if registro.status == "concluida":
            raise CIFAvaliacaoConcluida
        atualizado = CIFAvaliacaoRegistro(
            **{
                **registro.__dict__,
                "data_avaliacao": data_avaliacao or registro.data_avaliacao,
                "respostas": mesclar_respostas(registro.respostas, respostas),
                "atualizado_em": datetime.now(),
            }
        )
        self.avaliacoes[avaliacao_id] = atualizado
        return atualizado

    def concluir(self, paciente_id, avaliacao_id, respostas_patch, calcular, serializar_resultado):
        registro = self._get(paciente_id, avaliacao_id)
        respostas = mesclar_respostas(registro.respostas, respostas_patch)
        if registro.status == "concluida":
            if respostas != registro.respostas:
                raise CIFAvaliacaoConcluida
            return registro
        resultado = calcular(self.pacientes[paciente_id], respostas)
        if not resultado.definitivo:
            raise CIFCalculoInvalido(resultado)
        concluida = CIFAvaliacaoRegistro(
            **{
                **registro.__dict__,
                "status": "concluida",
                "respostas": respostas,
                "resultados": serializar_resultado(resultado),
                "atualizado_em": datetime.now(),
                "concluido_em": datetime.now(),
            }
        )
        self.avaliacoes[avaliacao_id] = concluida
        return concluida


class RespostaDireta:
    def __init__(self, status_code, body):
        self.status_code = status_code
        self.body = body
        self.text = str(body)

    def json(self):
        return self.body


class ClienteDireto:
    """Invoca handlers FastAPI sem exigir a dependência opcional httpx."""

    @staticmethod
    def _call(fn, *args):
        try:
            return RespostaDireta(200, fn(*args))
        except HTTPException as exc:
            return RespostaDireta(exc.status_code, exc.detail)
        except ValidationError as exc:
            return RespostaDireta(422, exc.errors())

    def get(self, path):
        if path == "/api/v1/cif/catalogo":
            return self._call(cif_api.consultar_catalogo)
        match = re.fullmatch(r"/api/v1/patients/(\d+)/cif-avaliacoes", path)
        if match:
            return self._call(cif_api.listar_avaliacoes, int(match.group(1)))
        match = re.fullmatch(r"/api/v1/patients/(\d+)/cif-avaliacoes/(\d+)", path)
        if match:
            return self._call(
                cif_api.consultar_avaliacao, int(match.group(1)), int(match.group(2))
            )
        raise AssertionError(path)

    def post(self, path, json):
        if path == "/api/v1/cif-avaliacoes":
            try:
                payload = CIFAvaliacaoCriar.model_validate(json)
            except ValidationError as exc:
                return RespostaDireta(422, exc.errors())
            response = self._call(cif_api.criar_rascunho, payload, None)
            if response.status_code == 200:
                response.status_code = 201
            return response
        match = re.fullmatch(r"/api/v1/patients/(\d+)/cif-avaliacoes", path)
        if match:
            try:
                payload = CIFAvaliacaoCriar.model_validate(json)
            except ValidationError as exc:
                return RespostaDireta(422, exc.errors())
            response = self._call(cif_api.criar_rascunho, payload, int(match.group(1)))
            if response.status_code == 200:
                response.status_code = 201
            return response
        match = re.fullmatch(
            r"/api/v1/patients/(\d+)/cif-avaliacoes/(\d+)/(previa|concluir)", path
        )
        if match:
            operation = (
                cif_api.calcular_previa
                if match.group(3) == "previa"
                else cif_api.concluir_avaliacao
            )
            try:
                payload = CIFAvaliacaoOperacao.model_validate(json)
            except ValidationError as exc:
                return RespostaDireta(422, exc.errors())
            return self._call(
                operation,
                int(match.group(1)),
                int(match.group(2)),
                payload,
            )
        raise AssertionError(path)

    def patch(self, path, json):
        match = re.fullmatch(r"/api/v1/patients/(\d+)/cif-avaliacoes/(\d+)", path)
        if match:
            try:
                payload = CIFAvaliacaoAtualizar.model_validate(json)
            except ValidationError as exc:
                return RespostaDireta(422, exc.errors())
            return self._call(
                cif_api.atualizar_rascunho,
                int(match.group(1)),
                int(match.group(2)),
                payload,
            )
        raise AssertionError(path)


class CIFAvaliacaoAPITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = FastAPI()
        cls.app.include_router(cif_api.router)

    def setUp(self):
        self.memoria = MemoriaCIF()
        self.memoria.paciente(10, "Feminino")
        self.memoria.paciente(20, "Masculino")
        cif_api.repository = self.memoria
        self.client = ClienteDireto()

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

    def test_catalogo_disponivel_e_versionado(self):
        response = self.client.get("/api/v1/cif/catalogo")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["catalog_version"], cif_api.CATALOG_VERSION)
        self.assertIn("areas", response.json())
        self.assertEqual(response.json()["rules_version"], cif_api.RULES_VERSION)

    def test_cria_atualiza_previa_e_retoma_rascunho(self):
        draft = self.criar()
        self.assertEqual(draft["status"], "rascunho")
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

    def test_criacao_por_rota_do_paciente_nao_exige_repetir_paciente_id(self):
        response = self.client.post(
            "/api/v1/patients/10/cif-avaliacoes", {"respostas": {}}
        )
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()["paciente_id"], 10)

    def test_conclusao_valida_persiste_resultados_versoes_e_e_idempotente(self):
        draft = self.criar(respostas=self.respostas_validas())
        first = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}/concluir", json={}
        )
        self.assertEqual(first.status_code, 200, first.text)
        data = first.json()
        self.assertEqual(data["status"], "concluida")
        self.assertIsNotNone(data["resultados"])
        self.assertEqual(data["catalogo_versao"], cif_api.CATALOG_VERSION)
        self.assertEqual(data["regras_versao"], cif_api.RULES_VERSION)

        repeated = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}/concluir", json={}
        )
        self.assertEqual(repeated.status_code, 200, repeated.text)
        self.assertEqual(repeated.json()["id"], data["id"])
        self.assertEqual(len(self.memoria.avaliacoes), 1)

        blocked = self.client.patch(
            f"/api/v1/patients/10/cif-avaliacoes/{draft['id']}",
            json={"respostas": {"b:E9": 1}},
        )
        self.assertEqual(blocked.status_code, 409)

    def test_invalida_decimal_calculada_e_obrigatoria(self):
        decimal = self.criar(respostas={next(iter(self.respostas_validas())): 1.0})
        response = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{decimal['id']}/concluir", json={}
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("nota_invalida", str(response.json()))

        calculated = self.criar(respostas={"b:E8": 1})
        response = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{calculated['id']}/concluir", json={}
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("campo_calculado_somente_leitura", str(response.json()))

        missing = self.criar()
        response = self.client.post(
            f"/api/v1/patients/10/cif-avaliacoes/{missing['id']}/concluir", json={}
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("campo_obrigatorio_ausente", str(response.json()))

    def test_sexo_ausente_e_outro_bloqueiam_conclusao(self):
        self.memoria.paciente(30, None)
        self.memoria.paciente(40, "Outro")
        for paciente_id, codigo in ((30, "sexo_ausente"), (40, "sexo_invalido")):
            draft = self.criar(paciente_id, self.respostas_validas())
            response = self.client.post(
                f"/api/v1/patients/{paciente_id}/cif-avaliacoes/{draft['id']}/concluir",
                json={},
            )
            self.assertEqual(response.status_code, 422)
            self.assertIn(codigo, str(response.json()))

    def test_multiplas_avaliacoes_e_isolamento_por_paciente(self):
        first = self.criar(10)
        second = self.criar(10)
        other = self.criar(20)
        self.assertNotEqual(first["id"], second["id"])
        self.assertNotEqual(first["id"], other["id"])
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
