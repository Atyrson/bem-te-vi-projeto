# Bem-Te-Vi — Sistema de Reabilitação

App Flutter com backend FastAPI para reabilitação de pacientes com lesão medular.

## Setup do Backend

Consulte [Backend/README.md](Backend/README.md) para instruções completas de:
- Configuração do PostgreSQL
- Instalação de dependências Python
- Criação das tabelas e população do banco
- Usuários de teste para login

## Executar no celular Android

O endereço da API é configurável no momento da execução. Para usar o padrão
local no computador, execute apenas `flutter run`. Para um celular físico,
conecte-o à mesma rede Wi-Fi do computador e informe o IP do computador:

```bash
flutter pub get
flutter devices
flutter run -d ID_DO_DISPOSITIVO \
  --dart-define=API_BASE_URL=http://IP_DO_COMPUTADOR:8000/api/v1
```

O celular precisa estar com a depuração USB ativada e o computador autorizado
nas opções de desenvolvedor. A API deve estar iniciada com:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
