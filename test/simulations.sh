#Simular un pod en CrashLoopBackOff
#Pod que falla intencionalmente
kubectl run crash-loop --image=busybox --restart=Always --command -- sh -c "echo 'Starting'; sleep 5; echo 'ERROR: Crash!'; exit 1"
#Simular pod con alto consumo de CPU
kubectl run cpu-stress --image=busybox --restart=Never --command -- sh -c "yes > /dev/null & sleep 60"
#Simular pod con alto consumo de memoria
kubectl run mem-stress --image=busybox --restart=Never --command -- sh -c "dd if=/dev/zero of=/dev/null bs=1M count=1000"
#Simular servicio sin endpoints (escalar deployment a 0)
kubectl scale deployment nginx-app --replicas=0
# Esperar 2 minutos y restaurar:
kubectl scale deployment nginx-app --replicas=2
#Simular errores HTTP en api-demo
#Ejecutar llamadas a la API para generar logs de acceso
API_IP=$(kubectl get svc api-demo -o jsonpath='{.spec.clusterIP}')
for i in {1..20}; do
  kubectl run curl-$i --image=curlimages/curl --rm --restart=Never -- curl http://$API_IP:80 2>/dev/null || echo "Error en llamada $i"
  sleep 1
done

# Crear Script para Generar Logs Continuos de Incidentes

cat > simulate-events.sh << 'EOF'
#!/bin/bash
# simulate-events.sh - Genera eventos continuos para probar alertas

echo "🚀 Generando eventos de prueba..."

# 1. Generar logs de error en log-generator
kubectl exec -it deployment/log-generator -- sh -c "echo 'ERROR: $(date) - Simulated failure' >> /dev/termination-log 2>/dev/null || true" 2>/dev/null

# 2. Causar un fallo temporal (kill un pod)
POD=$(kubectl get pods -l app=log-generator -o name | head -1)
kubectl delete $POD --wait=false 2>/dev/null

# 3. Generar tráfico HTTP con errores
API_IP=$(kubectl get svc api-demo -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$API_IP" ]; then
  for i in {1..50}; do
    STATUS=$(shuf -i 200-500 -n 1)
    if [ $STATUS -gt 400 ]; then
      echo "🔴 Error $STATUS en llamada $i a API"
      kubectl run curl-$i --image=curlimages/curl --rm --restart=Never -- curl -s -o /dev/null -w "%{http_code}\n" http://$API_IP:80 2>/dev/null || true
    fi
    sleep 1
  done
fi

echo "✅ Eventos generados. Revisa Grafana para ver alertas."
EOF

chmod +x simulate-events.sh
./simulate-events.sh

7. Dashboard de Resumen (Recomendado)

Puedes crear un dashboard personalizado con paneles que muestren:

    Estado general: Nodos, pods, deployments (con colores verdes/rojos)

    Recursos: CPU y memoria por namespace

    Últimas alertas: Tabla de alertas recientes

    Logs de errores: Visor de logs con |= "error"

    Eventos del cluster: kubectl get events