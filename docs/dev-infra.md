# MBE Dev Infra

Legacy-only dev окружение. Стек EOL (PHP 7.0, Debian Stretch, MySQL 5.7) сохранён для совместимости с проектом.

## Состав

- `Dockerfile`
- `docker-compose.yml`
- `prod.conf/`
- `env.example`

## Запуск

```bash
cp env.example .env
```

Проверьте, что путь в `.env` (`APP_CODE_PATH`) указывает на каталог, где есть `crm`.

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f apache
```

CRM: `http://localhost:8081`

MySQL: `127.0.0.1:33063`

## Shell-интеграция

```bash
bash scripts/install-shell-tools.sh
source ~/.bashrc
```

После этого можно запускать `mbe ...` из любой подпапки проекта.
