# Implantação do Bem-Te-Vi no servidor do laboratório

Roteiro para instalar o PostgreSQL e a API FastAPI num servidor Linux acessado por SSH, e para publicar atualizações depois.

Premissas (ajuste se o servidor for diferente):

- Ubuntu Server 24.04 LTS (já traz Python 3.12, compatível com as versões fixadas em `Backend/requirements.txt`).
- Você tem um usuário com `sudo` no servidor.
- O servidor tem um nome ou IP fixo na rede do laboratório, aqui chamado `bemtevi.lab.local`.
- A branch de produção é `main`. Versões publicadas recebem uma tag `vX.Y.Z`.

Arquitetura:

```
App Android ──HTTPS──▶ nginx :443 ──▶ uvicorn 127.0.0.1:8000 (systemd) ──▶ PostgreSQL 127.0.0.1:5432
```

A API e o banco escutam só em `127.0.0.1`. Apenas o nginx fica exposto, e só na rede do laboratório.

---

## 0. Antes de usar com pacientes reais

O sistema vai guardar dados de saúde, que a LGPD trata como dados pessoais sensíveis. No estado atual do código, ele **não deve** ficar acessível fora de uma rede controlada nem receber dados reais sem estas correções:

| Problema | Onde | Risco |
|---|---|---|
| Nenhuma rota exige autenticação. O login só devolve dados do usuário, sem token. | `Backend/main.py`, `Backend/cif_api.py` | Qualquer pessoa que alcance a URL lista e altera todos os pacientes (`GET /api/v1/patients`). |
| `POST /api/v1/register` é aberto e aceita qualquer perfil. | `main.py:417` | Qualquer pessoa cria um usuário `admin`. |
| Senhas gravadas e comparadas em texto puro. | `main.py:437`, `main.py:468` | Vazamento do banco expõe as senhas. |
| `Backend/.env` com a senha do banco está versionado desde o primeiro commit. | `Backend/.env` | A senha está no histórico do GitHub. Não reutilize essa senha no servidor. |
| CORS liberado para qualquer origem. | `main.py:31` | Menor para o app Android, relevante se surgir versão web. |

Correções mínimas recomendadas, nesta ordem: hash de senha (bcrypt/argon2), token JWT exigido em todas as rotas, `/register` restrito a admin, remover `Backend/.env` do Git (`git rm --cached`) e adicioná-lo ao `.gitignore`. Também vale formalizar com a coordenação do laboratório quem é o responsável pelos dados e a política de backup.

Até lá, use o servidor só com os dados fictícios, ou só dentro da rede/VPN do laboratório.

---

## 1. Preparar o servidor

```bash
ssh usuario@bemtevi.lab.local

sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3.12-venv postgresql nginx ufw

# Usuário de sistema sem login para rodar a API
sudo adduser --system --group --home /opt/bemtevi bemtevi
```

Firewall: SSH e HTTPS liberados apenas para a rede do laboratório (troque a faixa):

```bash
sudo ufw default deny incoming
sudo ufw allow from 10.0.0.0/16 to any port 22 proto tcp
sudo ufw allow from 10.0.0.0/16 to any port 443 proto tcp
sudo ufw enable
```

## 2. Banco de dados

O PostgreSQL do Ubuntu já escuta apenas em `localhost`. Crie usuário e banco com uma senha nova:

```bash
SENHA=$(openssl rand -base64 24)
echo "Guarde esta senha num cofre: $SENHA"

sudo -u postgres psql <<SQL
CREATE ROLE bemtevi_user LOGIN PASSWORD '$SENHA';
CREATE DATABASE bemtivi_db OWNER bemtevi_user;
SQL
```

## 3. Código da API

Use uma *deploy key* somente leitura para o servidor clonar o repositório:

```bash
sudo -u bemtevi ssh-keygen -t ed25519 -N '' -f /opt/bemtevi/.ssh/id_ed25519
sudo cat /opt/bemtevi/.ssh/id_ed25519.pub
```

Cadastre a chave em GitHub → repositório → Settings → Deploy keys (sem permissão de escrita). Depois:

```bash
sudo -u bemtevi git clone git@github.com:Atyrson/bem-te-vi-projeto.git /opt/bemtevi/app
cd /opt/bemtevi/app/Backend
sudo -u bemtevi python3.12 -m venv venv
sudo -u bemtevi venv/bin/pip install -r requirements.txt
```

Configuração fora do repositório, legível só pelo serviço:

```bash
sudo mkdir -p /etc/bemtevi
sudo tee /etc/bemtevi/api.env >/dev/null <<EOF
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=bemtivi_db
DB_USER=bemtevi_user
DB_PASSWORD=$SENHA
EOF
sudo chown root:bemtevi /etc/bemtevi/api.env
sudo chmod 640 /etc/bemtevi/api.env
sudo -u bemtevi rm -f /opt/bemtevi/app/Backend/.env   # evita usar a senha versionada
```

Criar o schema e aplicar as migrações (o script é idempotente e registra o que já aplicou em `bemtevi_schema_migrations`):

```bash
cd /opt/bemtevi/app/Backend
sudo -u bemtevi bash -c 'set -a; . /etc/bemtevi/api.env; venv/bin/python criar_tabelas.py'
```

**Não rode `popular_tudo.py` nem `seed_usuarios.py` em produção.** Eles inserem pacientes fictícios e usuários com senhas públicas (`admin123`). Crie os usuários reais da equipe individualmente.

## 4. Serviço systemd

`/etc/systemd/system/bemtevi-api.service`:

```ini
[Unit]
Description=Bem-Te-Vi API
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=bemtevi
Group=bemtevi
WorkingDirectory=/opt/bemtevi/app/Backend
EnvironmentFile=/etc/bemtevi/api.env
ExecStart=/opt/bemtevi/app/Backend/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now bemtevi-api
curl -s localhost:8000/ && journalctl -u bemtevi-api -n 20
```

## 5. nginx com HTTPS

Peça ao TI do laboratório um certificado para `bemtevi.lab.local` (ou use Let's Encrypt se o servidor tiver nome público). Para teste interno, um autoassinado funciona, mas o Android só confia nele se o app for configurado para isso; prefira um certificado de verdade.

`/etc/nginx/sites-available/bemtevi`:

```nginx
server {
    listen 443 ssl;
    server_name bemtevi.lab.local;

    ssl_certificate     /etc/ssl/bemtevi/fullchain.pem;
    ssl_certificate_key /etc/ssl/bemtevi/privkey.pem;

    client_max_body_size 10m;

    # Documentação interativa da API fica fora do acesso público
    location ~ ^/(docs|redoc|openapi.json) { return 404; }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/bemtevi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

## 6. Backup do banco

Dump diário com retenção de 30 dias, em `/etc/cron.d/bemtevi-backup`:

```
0 2 * * * postgres pg_dump -Fc bemtivi_db > /var/backups/bemtevi/bemtivi_$(date +\%F).dump && find /var/backups/bemtevi -name '*.dump' -mtime +30 -delete
```

```bash
sudo mkdir -p /var/backups/bemtevi && sudo chown postgres: /var/backups/bemtevi && sudo chmod 700 /var/backups/bemtevi
```

Copie os dumps para outra máquina (o disco do servidor não é backup). Teste a restauração pelo menos uma vez:

```bash
sudo -u postgres createdb bemtivi_restore_teste
sudo -u postgres pg_restore -d bemtivi_restore_teste /var/backups/bemtevi/<arquivo>.dump
```

---

## 7. Publicar atualizações

### Fluxo de trabalho

1. Desenvolva em branches `feat/...` na sua máquina, com o banco local (Docker) e os dados fictícios.
2. Abra PR para `main`. Rode os testes (`venv/bin/pytest` no `Backend/`) antes do merge.
3. Mudança de banco = **novo arquivo** em `Backend/migrations/`, numerado em sequência (`002_...sql`, `003_...sql`). Nunca edite uma migração já aplicada no servidor, porque o `criar_tabelas.py` não reaplica arquivos já registrados.
4. Ao liberar uma versão, crie a tag: `git tag v1.1.0 && git push origin v1.1.0`.

### Atualizar o backend no servidor

Salve como `/opt/bemtevi/deploy.sh` (dono `root`, modo `755`):

```bash
#!/usr/bin/env bash
# Uso: sudo /opt/bemtevi/deploy.sh v1.1.0
set -euo pipefail
VERSAO="${1:?informe a tag, ex.: v1.1.0}"
APP=/opt/bemtevi/app
BACKUP=/var/backups/bemtevi/pre-deploy_${VERSAO}_$(date +%F_%H%M).dump

echo "== Backup antes da atualização: $BACKUP"
sudo -u postgres pg_dump -Fc bemtivi_db > "$BACKUP"

echo "== Código na versão $VERSAO"
ANTERIOR=$(sudo -u bemtevi git -C "$APP" describe --tags --always)
sudo -u bemtevi git -C "$APP" fetch --tags --quiet
sudo -u bemtevi git -C "$APP" checkout --quiet "$VERSAO"

echo "== Dependências"
sudo -u bemtevi "$APP/Backend/venv/bin/pip" install --quiet -r "$APP/Backend/requirements.txt"

echo "== Migrações"
sudo -u bemtevi bash -c "set -a; . /etc/bemtevi/api.env; cd $APP/Backend && venv/bin/python criar_tabelas.py"

echo "== Reiniciando a API"
systemctl restart bemtevi-api
sleep 3
if curl -fsS localhost:8000/ >/dev/null; then
  echo "OK: $ANTERIOR -> $VERSAO"
else
  echo "FALHOU. Logs: journalctl -u bemtevi-api -n 50"
  echo "Para voltar o código: sudo -u bemtevi git -C $APP checkout $ANTERIOR && systemctl restart bemtevi-api"
  echo "Se a migração alterou dados: pg_restore --clean -d bemtivi_db $BACKUP"
  exit 1
fi
```

Da sua máquina, a atualização vira um comando:

```bash
ssh usuario@bemtevi.lab.local 'sudo /opt/bemtevi/deploy.sh v1.1.0'
```

Para voltar uma versão, rode o mesmo script com a tag anterior. Se a versão nova tinha migração, voltar o código não desfaz o banco; nesse caso restaure o dump `pre-deploy_*` gerado automaticamente.

### Atualizar o app Android

O app não fica no servidor. Ele é instalado nos celulares da equipe e só aponta para a API.

1. Aumente a versão em `pubspec.yaml` (`version: 1.1.0+2`; o número após `+` precisa crescer a cada build, senão o Android recusa a atualização).
2. Gere o APK apontando para o servidor:

   ```bash
   flutter build apk --release \
     --android-skip-build-dependency-validation \
     --dart-define=API_BASE_URL=https://bemtevi.lab.local/api/v1
   ```

   Saída: `build/app/outputs/flutter-apk/app-release.apk`.
3. Assine sempre com **a mesma chave de release** (crie uma vez com `keytool` e configure em `android/key.properties`, fora do Git). APK assinado com outra chave não atualiza o instalado; o usuário teria de desinstalar e perder os dados locais.
4. Distribua o APK pelo canal do laboratório (pasta compartilhada, ou Google Play com faixa de teste interno, que também resolve a atualização automática).

Ordem segura quando a mudança envolve app e API: publique primeiro o backend, mantendo compatibilidade com o app antigo (rotas e campos novos opcionais, sem remover os existentes), e depois distribua o APK novo. Assim, quem ainda não atualizou o celular continua funcionando.

---

## Comandos úteis no servidor

```bash
systemctl status bemtevi-api            # estado da API
journalctl -u bemtevi-api -f            # logs em tempo real
git -C /opt/bemtevi/app describe --tags # versão em produção
sudo -u postgres psql bemtivi_db        # console do banco
ls -lh /var/backups/bemtevi             # backups
```
