# MBE Legacy Dev Infra

EOL legacy dev-инфраструктура для CRM (PHP 7.0, Debian Stretch, MySQL 5.7).

## Быстрый старт

```bash
cp env.example .env
docker compose up -d --build
docker compose ps
```

- CRM: `http://localhost:8081`
- MySQL: `127.0.0.1:33063`

## Важно

- Только для dev/legacy-совместимости.
- Код приложения не хранится в этом repo; путь задаётся через `APP_CODE_PATH` в `.env`.

## Документация

- `docs/dev-infra.md`
- `docs/commands.md`
- `docs/git.md`
