#!/bin/bash
# deploy.sh - Script de despliegue principal

set -e

echo "=== 🚀 Despliegue automático de Kubernetes Platform ==="

# Detectar IP automáticamente
DETECTED_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)

if [ -z "$DETECTED_IP" ]; then
    DETECTED_IP="127.0.0.1"
fi

echo "📡 IP detectada: $DETECTED_IP"

# Configurar IP automáticamente si no está configurada
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "📝 Creando terraform.tfvars automáticamente..."
    cat > terraform/terraform.tfvars << EOF
cluster_name         = "k8s-local"
api_server_address   = "$DETECTED_IP"
worker_count         = 2
grafana_admin_password = "admin123"
loki_storage_size    = "5Gi"
app_replicas         = 2
enable_observability = true
deploy_test_apps     = true
EOF
fi

# Ejecutar Make
make full-deploy