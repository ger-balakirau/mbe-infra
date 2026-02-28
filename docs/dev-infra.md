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
make up
make ps
make logs
```

CRM: `http://localhost:8081`

MySQL: `127.0.0.1:33063`

## Управление через Makefile

```bash
make help
```

`make` — основной интерфейс для локальной работы (compose, CRM-команды, backup/restore, deploy).
