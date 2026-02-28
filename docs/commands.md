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
mbe exec -T mysql \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | gzip > "${MYSQL_DATABASE}_$(date +%F_%H-%M).sql.gz"
```

С прогрессом дампа (нужна утилита `pv`):

```bash
# Ubuntu/Debian: sudo apt-get install -y pv
# macOS (brew):  brew install pv
mbe exec -T mysql \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  | pv \
  | gzip > "${MYSQL_DATABASE}_$(date +%F_%H-%M).sql.gz"
```

```bash
# Замените dump.sql.gz на имя вашего файла, например:
# crm_backup_2026-02-28_12-00.sql.gz
gunzip -c dump.sql.gz \
  | mbe exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```

Импорт с прогрессом (нужна `pv`):

```bash
# Замените dump.sql.gz на свой файл дампа
pv dump.sql.gz \
  | gunzip \
  | mbe exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```
