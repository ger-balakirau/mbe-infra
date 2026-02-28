SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

COMPOSE ?= docker compose
APACHE_SERVICE ?= apache
MYSQL_SERVICE ?= mysql
DUMP_DIR ?= dump
SERVICE ?= $(APACHE_SERVICE)

.PHONY: help \
	up up-build rebuild down restart ps logs sh-apache compose-exec \
	tracking vtiger-cron \
	db-dump db-dump-pv db-import db-import-pv mysql-show-mode mysql-legacy-mode \
	deploy deploy-dry deploy-full-perms

help:
	@echo "Main (docker compose via make):"
	@echo "  make up             # docker compose up -d"
	@echo "  make up-build       # docker compose up -d --build"
	@echo "  make rebuild        # docker compose build --no-cache"
	@echo "  make down           # docker compose down"
	@echo "  make restart        # docker compose restart"
	@echo "  make ps             # docker compose ps"
	@echo "  make logs           # docker compose logs -f $(APACHE_SERVICE)"
	@echo "  make logs SERVICE=mysql"
	@echo "  make sh-apache      # shell in apache container"
	@echo "  make compose-exec CMD='php -v' [SERVICE=apache]"
	@echo ""
	@echo "CRM:"
	@echo "  make tracking       # php Tracking.php in apache container"
	@echo "  make vtiger-cron    # php vtigercron.php in apache container"
	@echo ""
	@echo "Database:"
	@echo "  make db-dump        # dump DB to $(DUMP_DIR)/<db>_<date>.sql.gz"
	@echo "  make db-dump-pv     # same as db-dump, with pv progress"
	@echo "  make db-import FILE=$(DUMP_DIR)/backup.sql.gz"
	@echo "  make db-import-pv FILE=$(DUMP_DIR)/backup.sql.gz"
	@echo "  make mysql-show-mode   # show current MySQL GLOBAL sql_mode"
	@echo "  make mysql-legacy-mode # dev only: drop ONLY_FULL_GROUP_BY at runtime"
	@echo ""
	@echo "Deploy:"
	@echo "  make deploy"
	@echo "  make deploy-dry"
	@echo "  make deploy-full-perms"
	@echo ""
	@echo "Deploy variables:"
	@echo "  HOST=<ip-or-host>  Override remote host from .env.deploy"
	@echo "  ARGS='...'         Extra args for scripts/deploy/push-crm.sh"

up:
	$(COMPOSE) up -d

up-build:
	$(COMPOSE) up -d --build

rebuild:
	$(COMPOSE) build --no-cache

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	@set -o pipefail; \
	status=0; \
	$(COMPOSE) logs -f $(SERVICE) || status=$$?; \
	if [[ $$status -eq 0 || $$status -eq 130 ]]; then \
		exit 0; \
	fi; \
	exit $$status

sh-apache:
	$(COMPOSE) exec $(APACHE_SERVICE) bash

compose-exec:
	@if [[ -z "$(CMD)" ]]; then \
		echo "Error: CMD is required. Example: make compose-exec CMD='php -v'"; \
		exit 1; \
	fi
	$(COMPOSE) exec $(SERVICE) sh -lc "$(CMD)"

tracking:
	$(COMPOSE) exec -T $(APACHE_SERVICE) php Tracking.php

vtiger-cron:
	$(COMPOSE) exec -T $(APACHE_SERVICE) php vtigercron.php

db-dump:
	@mkdir -p "$(DUMP_DIR)"
	@db_name="$$(awk -F= '/^MYSQL_DATABASE=/{print $$2; exit}' .env)"; \
	if [[ -z "$$db_name" ]]; then \
		echo "Error: MYSQL_DATABASE is not set in .env"; \
		exit 1; \
	fi; \
	file="$(DUMP_DIR)/$${db_name}_$$(date +%F_%H-%M).sql.gz"; \
	echo "Dumping database to $$file"; \
	$(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc 'mysqldump -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' \
		| gzip > "$$file"; \
	echo "Saved: $$file"

db-dump-pv:
	@if ! command -v pv >/dev/null 2>&1; then \
		echo "Error: pv is not installed. Install it or use: make db-dump"; \
		exit 1; \
	fi
	@mkdir -p "$(DUMP_DIR)"
	@db_name="$$(awk -F= '/^MYSQL_DATABASE=/{print $$2; exit}' .env)"; \
	if [[ -z "$$db_name" ]]; then \
		echo "Error: MYSQL_DATABASE is not set in .env"; \
		exit 1; \
	fi; \
	file="$(DUMP_DIR)/$${db_name}_$$(date +%F_%H-%M).sql.gz"; \
	echo "Dumping database to $$file (with pv)"; \
	$(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc 'mysqldump -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' \
		| pv | gzip > "$$file"; \
	echo "Saved: $$file"

db-import:
	@if [[ -z "$(FILE)" ]]; then \
		echo "Error: FILE is required. Example: make db-import FILE=$(DUMP_DIR)/backup.sql.gz"; \
		exit 1; \
	fi
	@if [[ ! -f "$(FILE)" ]]; then \
		echo "Error: dump file not found: $(FILE)"; \
		exit 1; \
	fi
	@echo "Importing $(FILE) ..."
	@gunzip -c "$(FILE)" \
		| $(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'
	@echo "Import completed"

db-import-pv:
	@if [[ -z "$(FILE)" ]]; then \
		echo "Error: FILE is required. Example: make db-import-pv FILE=$(DUMP_DIR)/backup.sql.gz"; \
		exit 1; \
	fi
	@if [[ ! -f "$(FILE)" ]]; then \
		echo "Error: dump file not found: $(FILE)"; \
		exit 1; \
	fi
	@if ! command -v pv >/dev/null 2>&1; then \
		echo "Error: pv is not installed. Install it or use: make db-import FILE=..."; \
		exit 1; \
	fi
	@echo "Importing $(FILE) with progress ..."
	@pv "$(FILE)" \
		| gunzip \
		| $(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'
	@echo "Import completed"

mysql-show-mode:
	@$(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc "mysql -u\"$$MYSQL_USER\" -p\"$$MYSQL_PASSWORD\" -Nse \"SELECT @@GLOBAL.sql_mode;\" \"$$MYSQL_DATABASE\""

mysql-legacy-mode:
	@echo "Applying dev-only sql_mode workaround (remove ONLY_FULL_GROUP_BY)..."
	@$(COMPOSE) exec -T $(MYSQL_SERVICE) sh -lc "mysql -u\"$$MYSQL_USER\" -p\"$$MYSQL_PASSWORD\" -Nse \"SET GLOBAL sql_mode=(SELECT REPLACE(@@GLOBAL.sql_mode, 'ONLY_FULL_GROUP_BY', '')); SELECT @@GLOBAL.sql_mode;\" \"$$MYSQL_DATABASE\""
	@echo "Applied. Note: this is runtime-only and resets after mysql container restart."

deploy:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) $(ARGS)

deploy-dry:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) --dry-run $(ARGS)

deploy-full-perms:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) --full-perms $(ARGS)
