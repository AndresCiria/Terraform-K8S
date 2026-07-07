# Makefile - Orquestador principal para el proyecto

.PHONY: help install deploy destroy test clean setup

# Variables
PROJECT_NAME := k8s-platform
TERRAFORM_DIR := terraform
KUBECONFIG := $(TERRAFORM_DIR)/kubeconfig

# Colores para output
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Muestra esta ayuda
	@printf "${GREEN}Comandos disponibles:${NC}\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  ${YELLOW}%-15s${NC} %s\n", $$1, $$2}'

setup: ## Instala dependencias (Docker, Kind, kubectl, Helm, Terraform)
	@printf "${GREEN}=== Instalando dependencias ===${NC}\n"
	@./scripts/bootstrap.sh

install: ## Instala Terraform plugins y prepara el entorno
	@printf "${GREEN}=== Inicializando Terraform ===${NC}\n"
	@cd $(TERRAFORM_DIR) && terraform init

deploy: ## Despliega el cluster y todos los servicios
	@printf "${GREEN}=== Desplegando plataforma completa ===${NC}\n"
	@$(MAKE) install
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@$(MAKE) configure-kubectl
	@$(MAKE) status

destroy: ## Destruye todo el despliegue
	@printf "${RED}=== Destruyendo plataforma ===${NC}\n"
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	@rm -f $(KUBECONFIG)

test: ## Ejecuta pruebas de verificación
	@printf "${YELLOW}=== Ejecutando pruebas ===${NC}\n"
	@./scripts/test-deployment.sh

status: ## Muestra el estado del cluster
	@printf "${GREEN}=== Estado del cluster ===${NC}\n"
	@export KUBECONFIG=$(KUBECONFIG) && \
		kubectl get nodes && \
		echo "" && \
		kubectl get pods -A && \
		echo "" && \
		kubectl get svc -A

logs: ## Muestra los logs de todos los pods
	@export KUBECONFIG=$(KUBECONFIG) && kubectl logs -A --tail=50

grafana: ## Muestra la URL de Grafana
	@printf "${GREEN}=== Acceso a Grafana ===${NC}\n"
	@cd $(TERRAFORM_DIR) && terraform output grafana_url

configure-kubectl: ## Configura kubectl para usar el cluster
	@printf "${GREEN}=== Configurando kubectl ===${NC}\n"
	@export KUBECONFIG=$(KUBECONFIG) && \
		kubectl cluster-info && \
		echo "✅ kubectl configurado correctamente"

clean: ## Limpia archivos temporales y caché
	@printf "${YELLOW}=== Limpiando archivos temporales ===${NC}\n"
	@cd $(TERRAFORM_DIR) && rm -rf .terraform .terraform.lock.hcl terraform.tfstate* kubeconfig
	@rm -f $(TERRAFORM_DIR)/kind-config.yaml

full-deploy: setup install deploy test ## Despliegue completo (todo en uno)

full-clean: destroy clean ## Limpieza completa

# Ejecutar todo automáticamente sin intervención
auto-deploy: setup install deploy test status
	@printf "${GREEN}=== 🎉 Despliegue automático completado ===${NC}\n"
	@printf "${GREEN}📊 Grafana: $(shell cd $(TERRAFORM_DIR) && terraform output -raw grafana_url)${NC}\n"
	@printf "${GREEN}🔑 Contraseña Grafana: $(shell cd $(TERRAFORM_DIR) && terraform output -raw grafana_password)${NC}\n"

# Comando por defecto
default: help