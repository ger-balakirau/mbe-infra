# MBE Legacy Dev Infra

EOL legacy dev-инфраструктура для CRM (PHP 7.0, Debian Stretch, MySQL 5.7).

## Быстрый старт

```bash
cp env.example .env
mkdir -p html/mbelab.com
git clone <PRIVATE_CRM_REPO_URL> html/mbelab.com/crm
docker compose up -d --build
docker compose ps
```

- CRM: `http://localhost:8081`
- MySQL: `127.0.0.1:33063`

## Конфиги CRM в инфре

- Внешние runtime-конфиги хранятся в `configs/crm/` и монтируются в контейнер поверх кода CRM:
  - `config.inc.php`
  - `config.csrf-secret.php`
  - `config_override.php`
  - `.mbe` (по умолчанию используется `configs/crm/.mbe.example`)
- Эти файлы не находятся в git-репозитории кода приложения (`html/mbelab.com/crm`), только в инфра-репо.
- Для переноса на другую машину достаточно перенести infra-репо + код CRM и заполнить `.env`.

### Режим ошибок PHP в CRM

В `configs/crm/config.inc.php` режим переключается комментариями в секции `Adjust error_reporting favourable to deployment`:

- `PRODUCTION` (по умолчанию): активна первая строка, предупреждения не выводятся в браузер.
- `DEBUGGING`: раскомментировать строку с `//ini_set('display_errors','on'); ... // DEBUGGING`.
- `STRICT DEVELOPMENT`: раскомментировать строку с `//ini_set('display_errors','on'); error_reporting(E_ALL); // STRICT DEVELOPMENT`.

Важно: одновременно должен быть активен только один режим.

## Важно

- Только для dev/legacy-совместимости.
- Код приложения не хранится в этом repo; путь задаётся через `APP_CODE_PATH` в `.env`.

## Документация

- `docs/dev-infra.md`
- `docs/commands.md`
- `docs/git.md`

## Deploy (infra)

1. Создайте deploy-конфиг:

```bash
cp .env.deploy.example .env.deploy
```

2. Заполните `.env.deploy` (хост, путь, ключ).

3. Проверка без изменений:

```bash
make deploy-dry
```

4. Деплой:

```bash
make deploy
```

Примечание:
- `storage/` и `OperatorWayBill/` не синхронизируются.
- `config.inc.php` не синхронизируется по умолчанию.
- Права на файлы применяются только к измененным файлам через `rsync` (быстро, без полного прохода по проекту).
- Полный прогон прав (медленно) запускается отдельно: `make deploy-full-perms`.
- После деплоя скрипт делает reload legacy сервисов (`php7.x-fpm`/`php-fpm`, `apache2`/`httpd`) для обновления OPCache.
- `--dry-run` не создает директории на сервере, а проверяет наличие `${DEPLOY_REMOTE_PATH}`, `storage/`, `OperatorWayBill/`.
- Если директории отсутствуют, `--dry-run` завершится с ошибкой без изменений (безопасно для проверки).
- CLI-флаги (`--host`, `--path`, и т.д.) всегда имеют приоритет над `.env.deploy`, независимо от порядка аргументов.

Если нужно включить `config.inc.php` в деплой:
- разово через флаг: `ARGS="--with-config-inc" make deploy`
- постоянно через `.env.deploy`: `DEPLOY_INCLUDE_CONFIG_INC=1`

Опасные флаги:
- `--delete`: удаляет на сервере файлы, которых нет локально.
- `--full-perms`: делает полный рекурсивный `chmod/chown` по проекту (медленно).
- `--source <path>`: при неверном пути можно залить не тот код в production.
- `--with-config-inc`: отправляет `config.inc.php` на сервер (использовать только осознанно).
