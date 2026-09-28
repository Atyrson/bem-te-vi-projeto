"""Validação do cadastro sem conexão ao banco de dados."""

import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

import main
from models import PatientCreate, PatientUpdateByName


class PatientRegistrationValidationTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)
        self.minimal_patient = {
            "nome_completo": "Paciente Teste",
            "data_nascimento": "2000-02-01",
            "sexo": "Feminino",
            "cpf": "12345678909",
        }

    def test_rejects_missing_required_fields_before_database_access(self):
        for field in self.minimal_patient:
            with self.subTest(field=field):
                payload = dict(self.minimal_patient)
                del payload[field]
                with patch.object(main, "get_db_connection") as connection:
                    response = self.client.post("/api/v1/patients", json=payload)
                self.assertEqual(response.status_code, 422)
                self.assertTrue(
                    any(error["loc"][-1] == field for error in response.json()["detail"])
                )
                connection.assert_not_called()

    def test_rejects_blank_required_text(self):
        for field in ("nome_completo", "sexo", "cpf"):
            with self.subTest(field=field):
                payload = dict(self.minimal_patient)
                payload[field] = "   "
                with patch.object(main, "get_db_connection") as connection:
                    response = self.client.post("/api/v1/patients", json=payload)
                self.assertEqual(response.status_code, 422)
                connection.assert_not_called()

    def test_optional_fields_remain_optional(self):
        patient = PatientCreate.model_validate(self.minimal_patient)
        self.assertIsNone(patient.email)
        self.assertIsNone(patient.telefone)
        self.assertIsNone(patient.peso)

    def test_update_contract_still_accepts_name_only(self):
        update = PatientUpdateByName.model_validate({"nome_completo": "Paciente Teste"})
        self.assertIsNone(update.data_nascimento)


if __name__ == "__main__":
    unittest.main()
