# MBE Legacy Dev Infra

Инфраструктурный репозиторий для legacy CRM: `PHP 7.0 + Debian Stretch + MySQL 5.7`.

Этот репозиторий хранит Docker-окружение, runtime-конфиги CRM и скрипты деплоя.

Важно:

- проект предназначен для legacy/dev-сценариев;
- код CRM хранится в отдельном репозитории и подключается через `APP_CODE_PATH`.

## Быстрый старт

```bash
cp env.example .env
mkdir -p html/mbelab.com
git clone <PRIVATE_CRM_REPO_URL> html/mbelab.com/crm
make up-build
make ps
```

- CRM: `http://localhost:8081`
- MySQL: `127.0.0.1:33063`

> **ВАЖНО:** <u>без импорта рабочего дампа базы данных CRM не будет нормально работать.</u>  
> Интерфейс может открываться, но данные, бизнес-процессы и cron-задачи будут работать некорректно.
>
> Импорт дампа:
> ```bash
> make db-import FILE=dump/<YOUR_FILE>.sql.gz
> ```

## Документация

- [Полная установка с нуля (новый ПК, git clone, создание папок, запуск)](docs/getting-started.md)
- [Все команды `make` с описанием](docs/commands.md)
- [Техническое описание dev-инфры](docs/dev-infra.md)
- [Git workflow для infra-репозитория](docs/git.md)

## Deploy (кратко)

```bash
cp .env.deploy.example .env.deploy
make deploy-dry
make deploy
```

Опционально:

- `make deploy-full-perms` — полный медленный прогон прав;
- `ARGS="--with-config-inc" make deploy` — включить `config.inc.php` в синхронизацию.
