#!/bin/bash
# deploy.sh - Despliegue completo

set -e

echo "=== Despliegue automático de Kubernetes Platform ==="

# 1. Verificar dependencias
echo "Verificando dependencias..."

COMMANDS=("docker" "kind" "kubectl" "helm" "terraform" "make" "git")
MISSING=()

for cmd in "${COMMANDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        MISSING+=($cmd)
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "Faltan dependencias: ${MISSING[*]}"
    echo ""
    echo "Instalando dependencias automáticamente..."
    ./scripts/bootstrap.sh
    echo ""
    echo "Por favor, cierra sesión y vuelve a entrar para que los cambios surtan efecto"
    echo "   O ejecuta: source ~/.bashrc"
    exit 1
fi

echo "Todas las dependencias están instaladas"

# 2. Generar configuración si no existe
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "Generando configuración automática..."
    ./scripts/auto-config.sh
fi

# 3. Mostrar configuración
echo ""
echo "Configuración actual:"
cat terraform/terraform.tfvars
echo ""

# 4. Desplegar
make deploy

# 5. Mostrar acceso
API_IP=$(grep api_server_address terraform/terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
GRAFANA_PORT=$(grep grafana_port terraform/terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
GRAFANA_PASS=$(grep grafana_admin_password terraform/terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')

echo ""
echo "=== Despliegue completado ==="
echo ""
echo "Grafana: http://$API_IP:$GRAFANA_PORT"
echo "   Usuario: admin"
echo "   Contraseña: $GRAFANA_PASS"
echo ""
echo "Comandos útiles:"
echo "   make status   - Ver estado"
echo "   make logs     - Ver logs"
echo "   make grafana  - Mostrar URL de Grafana"
echo "   make destroy  - Destruir todo"
echo ""
echo "Para usar kubectl:"
echo "   export KUBECONFIG=$(pwd)/terraform/kubeconfig"
echo "   kubectl get nodes"