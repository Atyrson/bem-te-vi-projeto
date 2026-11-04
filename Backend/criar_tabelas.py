from pathlib import Path
from database import get_db_connection

BACKEND_DIR = Path(__file__).resolve().parent
SQL_FILE = BACKEND_DIR / 'schema.sql'
MIGRATIONS_DIR = BACKEND_DIR / 'migrations'


def _scripts_de_migracao():
    """Retorna as migrações SQL em ordem de versão."""
    return sorted(MIGRATIONS_DIR.glob('*.sql'))


def criar_tabelas():
    conn = None
    cursor = None
    try:
        schema_sql = SQL_FILE.read_text(encoding='utf-8')
        migracoes = _scripts_de_migracao()

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(schema_sql)
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS bemtevi_schema_migrations (
                version TEXT PRIMARY KEY,
                aplicado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            """
        )
        cursor.execute("SELECT version FROM bemtevi_schema_migrations;")
        aplicadas = {row[0] for row in cursor.fetchall()}

        for migracao in migracoes:
            if migracao.name in aplicadas:
                continue
            cursor.execute(migracao.read_text(encoding='utf-8'))
            cursor.execute(
                "INSERT INTO bemtevi_schema_migrations (version) VALUES (%s);",
                (migracao.name,),
            )

        conn.commit()
        print("Schema e migrações aplicados com sucesso.")
        for migracao in migracoes:
            estado = 'já aplicada' if migracao.name in aplicadas else 'aplicada'
            print(f"Migração {estado}: {migracao.name}")
    except Exception as error:
        print(f"ERRO ao criar tabelas: {error}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            if cursor:
                cursor.close()
            conn.close()

if __name__ == "__main__":
    criar_tabelas()
