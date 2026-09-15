"""Integração CIF com PostgreSQL isolado.

Só executa quando ``CIF_TEST_DATABASE_URL`` e
``CIF_TEST_DATABASE_CONFIRM=isolated`` são informados. Cada execução cria e
remove um schema exclusivo dentro desse banco de teste.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import date
import os
from pathlib import Path
from threading import Barrier
import unittest
from uuid import uuid4

import psycopg2
from psycopg2 import sql

try:
    import cif_api
    from cif_repository import (
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRepository,
        CIFRespostasInvalidas,
    )
except ModuleNotFoundError:  # pragma: no cover - descoberta a partir da raiz.
    from Backend import cif_api
    from Backend.cif_repository import (
        CIFAvaliacaoNaoEncontrada,
        CIFAvaliacaoRepository,
        CIFRespostasInvalidas,
    )


class CIFAvaliacaoRepositoryIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.database_url = os.getenv("CIF_TEST_DATABASE_URL")
        confirmed = os.getenv("CIF_TEST_DATABASE_CONFIRM") == "isolated"
        if not cls.database_url or not confirmed:
            raise unittest.SkipTest("PostgreSQL CIF isolado não configurado")

        cls.schema = f"cif_test_{uuid4().hex}"
        conn = psycopg2.connect(cls.database_url)
        conn.autocommit = True
        cursor = conn.cursor()
        try:
            cursor.execute(
                sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(cls.schema))
            )
            cursor.execute(
                sql.SQL("SET search_path TO {}, public").format(
                    sql.Identifier(cls.schema)
                )
            )
            cursor.execute(
                """
                CREATE TABLE pacientes (
                    id SERIAL PRIMARY KEY,
                    nome_completo TEXT NOT NULL,
                    sexo TEXT
                );
                """
            )
            migration = (
                Path(__file__).resolve().parent
                / "migrations"
                / "001_create_avaliacoes_cif.sql"
            ).read_text(encoding="utf-8")
            cursor.execute(migration)
        except Exception:
            cursor.execute(
                sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(
                    sql.Identifier(cls.schema)
                )
            )
            raise
        finally:
            cursor.close()
            conn.close()

        def connection_factory():
            return psycopg2.connect(
                cls.database_url,
                options=f"-c search_path={cls.schema},public",
            )

        cls.repository = CIFAvaliacaoRepository(connection_factory)

    @classmethod
    def tearDownClass(cls):
        if not getattr(cls, "database_url", None) or not getattr(cls, "schema", None):
            return
        conn = psycopg2.connect(cls.database_url)
        conn.autocommit = True
        cursor = conn.cursor()
        try:
            cursor.execute(
                sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(
                    sql.Identifier(cls.schema)
                )
            )
        finally:
            cursor.close()
            conn.close()

    def setUp(self):
        conn = self.repository.connection_factory()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "TRUNCATE TABLE avaliacoes_cif, pacientes RESTART IDENTITY CASCADE;"
            )
            cursor.execute(
                "INSERT INTO pacientes (nome_completo, sexo) VALUES (%s, %s) RETURNING id;",
                ("Paciente Feminino", "Feminino"),
            )
            self.paciente_feminino = cursor.fetchone()[0]
            cursor.execute(
                "INSERT INTO pacientes (nome_completo, sexo) VALUES (%s, %s) RETURNING id;",
                ("Paciente Masculino", "Masculino"),
            )
            self.paciente_masculino = cursor.fetchone()[0]
            conn.commit()
        finally:
            cursor.close()
            conn.close()

    def respostas_validas(self, sexo="Feminino"):
        return {
            campo.chave: 0
            for campo in cif_api.calculator.campos_entrada_obrigatorios(sexo)
        }

    def criar(self, paciente_id, respostas):
        return self.repository.criar(
            paciente_id=paciente_id,
            data_avaliacao=date(2026, 9, 15),
            respostas=respostas,
            catalogo_versao=cif_api.CATALOG_VERSION,
            regras_versao=cif_api.RULES_VERSION,
            validar_rascunho=cif_api._validar_rascunho_versionado,
        )

    def test_jsonb_multiplas_avaliacoes_isolamento_e_rollback(self):
        primeira = self.criar(self.paciente_feminino, {"b:E9": 0})
        segunda = self.criar(self.paciente_feminino, {})
        outra = self.criar(self.paciente_masculino, {})

        atualizada = self.repository.atualizar_rascunho(
            self.paciente_feminino,
            primeira.id,
            {"b:E10": 1},
            None,
            cif_api._validar_rascunho_versionado,
        )
        self.assertEqual(atualizada.respostas, {"b:E9": 0, "b:E10": 1})
        self.assertEqual(
            {item.id for item in self.repository.listar(self.paciente_feminino)},
            {primeira.id, segunda.id},
        )
        with self.assertRaises(CIFAvaliacaoNaoEncontrada):
            self.repository.obter_com_sexo(self.paciente_feminino, outra.id)

        with self.assertRaises(CIFRespostasInvalidas):
            self.repository.atualizar_rascunho(
                self.paciente_feminino,
                primeira.id,
                {"b:E8": 4},
                None,
                cif_api._validar_rascunho_versionado,
            )
        preservada, _ = self.repository.obter_com_sexo(
            self.paciente_feminino, primeira.id
        )
        self.assertEqual(preservada.respostas, {"b:E9": 0, "b:E10": 1})

    def test_conclusao_concorrente_e_idempotente_nao_duplica(self):
        draft = self.criar(
            self.paciente_feminino,
            self.respostas_validas("Feminino"),
        )
        barrier = Barrier(2)

        def concluir():
            barrier.wait()
            return self.repository.concluir(
                self.paciente_feminino,
                draft.id,
                None,
                cif_api._calcular_versionado,
                cif_api._resultado_dict,
            )

        with ThreadPoolExecutor(max_workers=2) as executor:
            resultados = list(executor.map(lambda _: concluir(), range(2)))

        self.assertEqual({item.id for item in resultados}, {draft.id})
        self.assertTrue(all(item.status == "concluida" for item in resultados))
        self.assertTrue(all(item.resultados is not None for item in resultados))

        conn = self.repository.connection_factory()
        cursor = conn.cursor()
        try:
            cursor.execute(
                "SELECT count(*), min(status) FROM avaliacoes_cif WHERE id = %s;",
                (draft.id,),
            )
            self.assertEqual(cursor.fetchone(), (1, "concluida"))
        finally:
            cursor.close()
            conn.close()


if __name__ == "__main__":
    unittest.main()
