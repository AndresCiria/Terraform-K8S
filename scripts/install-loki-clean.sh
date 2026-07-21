#!/bin/bash
# install-loki-clean.sh

cd ~/Terraform-k8s/terraform
export KUBECONFIG=$(pwd)/kubeconfig

echo "Instalando Loki sin agentes problemáticos..."

helm uninstall loki -n monitoring 2>/dev/null || true

kubectl delete daemonset loki-logs -n monitoring 2>/dev/null || true

helm install loki grafana/loki -n monitoring \
  --version 5.42.0 \
  --set deploymentMode=SingleBinary \
  --set singleBinary.replicas=1 \
  --set loki.auth_enabled=false \
  --set loki.storage.type=filesystem \
  --set persistence.enabled=false \
  --set agent.enabled=false \
  --set gateway.enabled=false \
  --set grafana-agent-operator.enabled=false

if kubectl get deployment loki-grafana-agent-operator -n monitoring &>/dev/null; then
    echo "Eliminando operador de Grafana Agent..."
    kubectl scale deployment loki-grafana-agent-operator -n monitoring --replicas=0
    kubectl delete daemonset loki-logs -n monitoring 2>/dev/null || true
fi

echo "Verificando pods de Loki:"
kubectl get pods -n monitoring | grep loki

echo "Verificando servicio de Loki:"
kubectl get svc -n monitoring | grep loki

echo "Loki instalado correctamente"