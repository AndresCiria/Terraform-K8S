.PHONY: help bootstrap config deploy destroy status logs clean grafana full-deploy

help:
	@echo "Comandos disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap:
	@./scripts/bootstrap.sh

config:
	@./scripts/auto-config.sh

deploy:
	@echo "Desplegando..."
	@cd terraform && terraform init -upgrade
	@cd terraform && terraform apply -auto-approve
	@echo "Despliegue completado"
	@make status

destroy:
	@echo "Destruyendo..."
	@cd terraform && terraform destroy -auto-approve
	@kind delete cluster --name k8s-local 2>/dev/null || true
	@rm -f terraform/kubeconfig

status:
	@export KUBECONFIG=$(PWD)/terraform/kubeconfig && \
		kubectl get nodes && \
		echo "" && \
		kubectl get pods -A

logs:
	@export KUBECONFIG=$(PWD)/terraform/kubeconfig && kubectl logs -A --tail=50

grafana:
	@echo "http://192.168.122.55:30001"
	@echo "Usuario: admin"
	@echo "Contraseña: admin123"

port-forward:
	@kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0

clean:
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate*

full-deploy: bootstrap config deploy ## Despliegue completo