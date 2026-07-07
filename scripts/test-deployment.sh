#!/bin/bash
# scripts/test-deployment.sh - Pruebas de verificación

set -e

echo "=== 🧪 Ejecutando pruebas de verificación ==="

# Exportar kubeconfig
export KUBECONFIG=$(pwd)/terraform/kubeconfig

# Función para esperar pods
wait_for_pods() {
    local namespace=$1
    local timeout=$2
    echo "⏳ Esperando pods en namespace ${namespace}..."
    kubectl wait --for=condition=ready pod --all -n ${namespace} --timeout=${timeout}s 2>/dev/null || {
        echo "⚠️  Algunos pods no están listos en ${namespace}"
        kubectl get pods -n ${namespace}
    }
}

# 1. Verificar nodos
echo "📊 1. Verificando nodos..."
kubectl get nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "✅ ${NODE_COUNT} nodos encontrados"

# 2. Verificar pods del sistema
echo "📊 2. Verificando pods del sistema..."
kubectl get pods -n kube-system
wait_for_pods "kube-system" 120

# 3. Verificar monitoring stack
echo "📊 3. Verificando monitoring stack..."
kubectl get pods -n monitoring
wait_for_pods "monitoring" 180

# 4. Verificar aplicaciones
echo "📊 4. Verificando aplicaciones..."
kubectl get pods -n default

# 5. Probar acceso a Grafana
echo "📊 5. Probando acceso a Grafana..."
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o name | head -1)
if [ -n "$GRAFANA_POD" ]; then
    kubectl port-forward -n monitoring $GRAFANA_POD 3000:3000 &
    PF_PID=$!
    sleep 5
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302"; then
        echo "✅ Grafana accesible"
    else
        echo "⚠️  Grafana no responde"
    fi
    kill $PF_PID 2>/dev/null || true
fi

# 6. Probar aplicación Nginx
echo "📊 6. Probando aplicación Nginx..."
NGINX_SVC=$(kubectl get svc nginx-app -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -n "$NGINX_SVC" ]; then
    kubectl run test-nginx --image=curlimages/curl --rm --restart=Never -- \
        curl -s http://$NGINX_SVC:80 | grep -q "Welcome to nginx" && echo "✅ Nginx funcionando" || echo "⚠️  Nginx no responde"
fi

echo ""
echo "=== ✅ Pruebas completadas ==="