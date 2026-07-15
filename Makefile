.PHONY: help bootstrap config deploy destroy status logs clean grafana full-deploy

help: ## Muestra esta ayuda
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Instala todas las dependencias
	@./scripts/bootstrap.sh

config: ## Genera configuración automática
	@./scripts/auto-config.sh

deploy: ## Despliega todo el stack
	@echo "🚀 Desplegando..."
	@cd terraform && terraform init -upgrade
	@cd terraform && terraform apply -auto-approve
	@echo "✅ Despliegue completado"
	@make status

destroy: ## Destruye todo
	@echo "🗑️  Destruyendo..."
	@cd terraform && terraform destroy -auto-approve
	@kind delete cluster --name k8s-local 2>/dev/null || true
	@rm -f terraform/kubeconfig

status: ## Muestra el estado del cluster
	@export KUBECONFIG=$(PWD)/terraform/kubeconfig && \
		kubectl get nodes && \
		echo "" && \
		kubectl get pods -A

logs: ## Muestra logs de todos los pods
	@export KUBECONFIG=$(PWD)/terraform/kubeconfig && kubectl logs -A --tail=50

grafana: ## Muestra URL de Grafana
	@echo "http://192.168.122.163:30001"
	@echo "Usuario: admin"
	@echo "Contraseña: admin123"

port-forward: ## Activa port-forward para Grafana
	@kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0

clean: ## Limpia archivos temporales
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate*

full-deploy: bootstrap config deploy ## Despliegue completo