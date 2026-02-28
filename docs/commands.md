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

```bash
gunzip -c dump.sql.gz \
  | mbe exec -T mysql \
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"
```
