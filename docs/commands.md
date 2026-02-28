# MBE Commands

## Один раз: установить shell-команды

```bash
bash scripts/install-shell-tools.sh
source ~/.bashrc
# для zsh:
# bash scripts/install-shell-tools.sh ~/.zshrc && source ~/.zshrc
```

После установки доступны команды:

- `mbe ...` — запуск `docker compose` для текущего MBE-проекта из любой подпапки
- `mbe-env` — загрузка переменных из `.env`
- `mbe-root` — показать найденный корень проекта

## Базовые команды

`Tracking.php`:
- ручной запуск логистического трекинга отправлений (обновление статусов по интеграциям/операторам).

`vtigercron.php`:
- запуск штатных cron-задач CRM (плановые фоновые процессы, очереди, сервисные обработчики).

```bash
mbe ps
mbe logs -f apache
mbe exec apache php Tracking.php
mbe exec apache php vtigercron.php
```

## Работа с базой

```bash
mbe-env
```

```bash
FILE="dump/${MYSQL_DATABASE}_$(date +%F_%H-%M).sql.gz"
mbe exec -T mysql \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | gzip > "$FILE"
echo "Saved: $FILE"
```

С прогрессом дампа (нужна утилита `pv`):

```bash
# Ubuntu/Debian: sudo apt-get install -y pv
# macOS (brew):  brew install pv
FILE="dump/${MYSQL_DATABASE}_$(date +%F_%H-%M).sql.gz"
mbe exec -T mysql \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | pv \
  | gzip > "$FILE"
echo "Saved: $FILE"
```

```bash
# Импорт из файла в папке dump/
# Замените имя на свой файл:
FILE="dump/crm_backup_2026-02-28_12-00.sql.gz"
gunzip -c "$FILE" \
  | mbe exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

Импорт с прогрессом (нужна `pv`):

```bash
# Замените имя на свой файл в папке dump/
FILE="dump/crm_backup_2026-02-28_12-00.sql.gz"
pv "$FILE" \
  | gunzip \
  | mbe exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
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
