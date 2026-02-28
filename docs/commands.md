# MBE Commands

Основной интерфейс для локальной работы: `make` (без установки shell-алиасов).

## Базовые команды

```bash
make up
make ps
make logs
make logs SERVICE=mysql
make sh-apache
make compose-exec CMD='php -v'
```

## CRM задачи

`Tracking.php`:
- ручной запуск логистического трекинга отправлений (обновление статусов по интеграциям/операторам).

`vtigercron.php`:
- запуск штатных cron-задач CRM (плановые фоновые процессы, очереди, сервисные обработчики).

```bash
make tracking
make vtiger-cron
```

## Работа с базой

Создать дамп:

```bash
make db-dump
```

Создать дамп с прогрессом (нужна утилита `pv`):

```bash
# Ubuntu/Debian: sudo apt-get install -y pv
# macOS (brew):  brew install pv
make db-dump-pv
```

Импорт из файла:

```bash
make db-import FILE=dump/crm_backup_2026-02-28_12-00.sql.gz
```

Импорт с прогрессом (нужна `pv`):

```bash
make db-import-pv FILE=dump/crm_backup_2026-02-28_12-00.sql.gz
```

## Deploy на сервер

Подготовка:

```bash
cp .env.deploy.example .env.deploy
```

Проверить изменения (без применения):

```bash
make deploy-dry
```

Реальный деплой:

```bash
make deploy
```

`config.inc.php` по умолчанию в deploy не входит. Включить можно так:

```bash
ARGS="--with-config-inc" make deploy
# или установить в .env.deploy:
# DEPLOY_INCLUDE_CONFIG_INC=1
```

Полный прогон прав по всему проекту (редко, медленно):

```bash
make deploy-full-perms
```

При необходимости можно временно переопределить хост:

```bash
make deploy HOST=203.0.113.10
```

Опасные флаги `push-crm.sh`:
- `--delete` — удаляет на сервере файлы, которых нет локально.
- `--full-perms` — запускает полный рекурсивный прогон прав по проекту (медленно).
- `--source <path>` — при ошибке пути можно отправить на сервер не тот каталог.
- `--with-config-inc` — включает синхронизацию `config.inc.php` (по умолчанию выключена).
