# Bem-Te-Vi

Sistema para registro e acompanhamento da reabilitação de pessoas com lesão medular.

Este repositório dá continuidade ao trabalho desenvolvido por **Letícia Arisa**. A aplicação reúne um frontend Flutter, uma API FastAPI e um banco de dados PostgreSQL.

## Funcionalidades

- Cadastro e consulta de pacientes
- Autenticação por perfil de usuário
- Registro de anamnese
- Avaliações ASIA e GAS
- Avaliações MEEM e eletrodiagnóstico
- Densitometria óssea e acompanhamento de tendências

## Estrutura

- `lib/` — aplicação Flutter
- `Backend/` — API FastAPI, modelos, esquema do banco e scripts de população
- `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/` — plataformas suportadas pelo Flutter

## Requisitos

- Flutter SDK com Dart 3.8 ou superior
- Python 3.10 ou superior
- PostgreSQL 14 ou superior

## Execução

Consulte [Backend/README.md](Backend/README.md) para configurar o banco, instalar as dependências e popular os dados de teste.

Com o PostgreSQL configurado, inicie a API:

```bash
cd Backend
source venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Em outro terminal, inicie o Flutter:

```bash
flutter pub get
flutter run
```

Para executar em um celular físico, conecte-o à mesma rede do computador e informe o endereço da API:

```bash
flutter run -d ID_DO_DISPOSITIVO \
  --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8000/api/v1
```

## Usuários de teste

| E-mail | Senha | Perfil |
|---|---|---|
| `admin@bemtevi.com` | `admin123` | Administrador |
| `fisio@bemtevi.com` | `fisio123` | Fisioterapeuta |
| `estagiario@bemtevi.com` | `estag123` | Estagiário/Pesquisador |
