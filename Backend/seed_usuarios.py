from database import get_db_connection

USUARIOS = [
    {
        "nome_completo": "Dr. Administrador",
        "email": "admin@bemtevi.com",
        "senha": "admin123",
        "perfil": "admin"
    },
    {
        "nome_completo": "Maria Souza",
        "email": "fisio@bemtevi.com",
        "senha": "fisio123",
        "perfil": "fisioterapeuta"
    },
    {
        "nome_completo": "João Aluno",
        "email": "estagiario@bemtevi.com",
        "senha": "estag123",
        "perfil": "estagiario"
    }
]

def seed_usuarios():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        for usuario in USUARIOS:
            cursor.execute(
                "SELECT id FROM usuarios WHERE email = %s;",
                (usuario["email"],)
            )
            if cursor.fetchone():
                print(f"Usuário '{usuario['email']}' já existe. Pulando.")
                continue

            cursor.execute(
                "INSERT INTO usuarios (nome_completo, email, senha, perfil) VALUES (%s, %s, %s, %s);",
                (usuario["nome_completo"], usuario["email"], usuario["senha"], usuario["perfil"])
            )
            print(f"Usuário '{usuario['email']}' (perfil: {usuario['perfil']}) criado.")

        conn.commit()
        print("Seed de usuários concluído.")
    except Exception as error:
        print(f"ERRO ao criar usuários: {error}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            cursor.close()
            conn.close()

if __name__ == "__main__":
    seed_usuarios()
