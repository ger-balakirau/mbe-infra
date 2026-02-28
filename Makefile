.PHONY: help deploy deploy-dry deploy-full-perms

help:
	@echo "Targets:"
	@echo "  make deploy      # Deploy CRM to server"
	@echo "  make deploy-dry  # Show deploy changes without applying"
	@echo "  make deploy-full-perms  # Deploy and force full chmod/chown scan"
	@echo ""
	@echo "Optional variables:"
	@echo "  HOST=<ip-or-host>  Override remote host from .env.deploy"
	@echo "  ARGS='...'         Extra args for scripts/deploy/push-crm.sh"

deploy:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) $(ARGS)

deploy-dry:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) --dry-run $(ARGS)

deploy-full-perms:
	./scripts/deploy/push-crm.sh $(if $(HOST),--host $(HOST),) --full-perms $(ARGS)
