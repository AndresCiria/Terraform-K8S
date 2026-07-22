#!/bin/bash

echo "Simulando incidentes para probar alertas..."

echo "Generando intentos de login fallidos..."
for i in {1..5}; do
  kubectl exec deployment/nginx-app -- sh -c "echo 'Failed login attempt for admin from 10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)' >> /var/log/nginx/error.log" 2>/dev/null || true
  sleep 1
done

echo "Simulando escalada de privilegios..."
kubectl run sudo-test --image=busybox --restart=Never --command -- sh -c "echo 'sudo: user admin executed privileged command' && exit 0" 2>/dev/null || true

echo "Simulando ataque..."
kubectl run attack-test --image=busybox --restart=Never --command -- sh -c "echo 'attack pattern detected: SQL injection attempt on /api/users' && exit 0" 2>/dev/null || true

echo "Generando logs de error..."
kubectl run error-generator --image=busybox --restart=Never --command -- sh -c "for i in 1 2 3 4 5 6 7 8 9 10; do echo 'ERROR: Critical error in pod' ; sleep 1; done" 2>/dev/null || true

echo "Forzando caída de pod..."
kubectl delete pod -l app=nginx-app --wait=false 2>/dev/null || true

echo "Generando panic..."
kubectl run panic-test --image=busybox --restart=Never --command -- sh -c "echo 'panic: runtime error: invalid memory address' && exit 1" 2>/dev/null || true

echo "Incidentes simulados. Espera 1-2 minutos y revisa Grafana."
echo "Ve a Alerting > Alert rules para ver las alertas."
echo "Ve a Explore > Loki y busca: {namespace=\"default\"} |= \"Failed login\""