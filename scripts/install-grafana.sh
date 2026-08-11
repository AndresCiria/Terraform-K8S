#!/bin/bash

echo "=== Deshabilitando Kyverno temporalmente ==="

# Ver deployments de Kyverno
kubectl get deployments -n security

# Escalar a 0
kubectl scale deployment -n security kyverno-admission-controller --replicas=0
kubectl scale deployment -n security kyverno-background-controller --replicas=0
kubectl scale deployment -n security kyverno-cleanup-controller --replicas=0
kubectl scale deployment -n security kyverno-reports-controller --replicas=0

echo "Esperando que Kyverno se desactive..."
sleep 15

# Verificar que no hay pods de Kyverno
kubectl get pods -n security

echo ""
echo "=== Instalando Grafana ==="

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --create-namespace \
  --set adminPassword="admin" \
  --set persistence.enabled=false \
  --set service.type=NodePort \
  --set service.nodePort=30001 \
  --set securityContext.runAsNonRoot=true \
  --set securityContext.runAsUser=472 \
  --set containerSecurityContext.runAsNonRoot=true \
  --set containerSecurityContext.runAsUser=472 \
  --set containerSecurityContext.allowPrivilegeEscalation=false \
  --wait

if [ $? -eq 0 ]; then
    echo "✅ Grafana instalado correctamente"
else
    echo "❌ Error al instalar Grafana"
    exit 1
fi

echo ""
echo "=== Reactivando Kyverno ==="

# Reactivar Kyverno
kubectl scale deployment -n security kyverno-admission-controller --replicas=1
kubectl scale deployment -n security kyverno-background-controller --replicas=1
kubectl scale deployment -n security kyverno-cleanup-controller --replicas=1
kubectl scale deployment -n security kyverno-reports-controller --replicas=1

echo "Esperando que Kyverno se reactive..."
sleep 10

# Verificar
kubectl get pods -n security

echo ""
echo "=== Verificando Grafana ==="
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl get svc -n monitoring grafana

echo ""
echo "=== Credenciales de Grafana ==="
echo "URL: http://192.168.122.55:30001"
echo "Usuario: admin"
echo "Contraseña: admin"

# Probar acceso
sleep 10
if curl -s -f http://192.168.122.55:30001/api/health > /dev/null 2>&1; then
    echo "✅ Grafana está accesible"
else
    echo "⚠️ Intentando port-forward..."
    kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0 &
    sleep 5
    if curl -s -f http://localhost:30001/api/health > /dev/null 2>&1; then
        echo "✅ Grafana accesible en http://localhost:30001"
    fi
fi