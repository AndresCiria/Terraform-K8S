# Makefile - Con fallbacks para instalación

.PHONY: help bootstrap deploy destroy status test config config-show config-edit

CONFIG_FILE := terraform/terraform.tfvars
TF_DIR := terraform

help: ## Muestra esta ayuda
	@echo "📋 Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Instala TODAS las dependencias
	@./scripts/bootstrap.sh

config: ## Genera configuración automáticamente
	@./scripts/auto-config.sh

config-show: ## Muestra la configuración actual
	@cat $(CONFIG_FILE)

config-edit: ## Edita la configuración
	@${EDITOR:-nano} $(CONFIG_FILE)

deploy: ## Despliega usando terraform.tfvars
	@echo "🚀 Desplegando..."
	@cd $(TF_DIR) && terraform apply -auto-approve

destroy: ## Destruye todo
	@echo "🗑️  Destruyendo..."
	@cd $(TF_DIR) && terraform destroy -auto-approve

status: ## Muestra el estado del cluster
	@export KUBECONFIG=$(TF_DIR)/kubeconfig 2>/dev/null || true && \
		kubectl get nodes 2>/dev/null || echo "⚠️  Cluster no disponible" && \
		echo "" && \
		kubectl get pods -A 2>/dev/null || true

logs: ## Muestra logs de todos los pods
	@export KUBECONFIG=$(TF_DIR)/kubeconfig 2>/dev/null || true && \
		kubectl logs -A --tail=50 2>/dev/null || echo "⚠️  Cluster no disponible"

grafana:
	@export KUBECONFIG=$(TF_DIR)/kubeconfig 2>/dev/null || true && \
		echo "📊 URL de Grafana:" && \
		(cd $(TF_DIR) && terraform output grafana_url 2>/dev/null || echo "⚠️  Grafana no desplegado") && \
		echo "" && \
		echo "🚀 Iniciando port-forward de Grafana..." && \
		kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0 > /dev/null 2>&1 || \
		(echo "❌ Error: No se pudo iniciar port-forward de Grafana" && exit 1) && \
		echo "✅ Grafana disponible en http://localhost:30001" && \
		echo "" && \
		echo "🔧 Iniciando port-forward de Jenkins..." && \
		kubectl port-forward -n default svc/jenkins-manual 30005:8080 --address=0.0.0.0 || \
		(echo "❌ Error: No se pudo iniciar port-forward de Jenkins" && exit 1)

test: ## Ejecuta pruebas de verificación
	@./scripts/test-deployment.sh

full-deploy: bootstrap config deploy status ## Despliegue completo

full-clean: destroy ## Limpieza completa

default: help