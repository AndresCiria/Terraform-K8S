cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-simulator
  namespace: default
  labels:
    app: log-simulator
    type: test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-simulator
  template:
    metadata:
      labels:
        app: log-simulator
        type: test
    spec:
      containers:
      - name: simulator
        image: busybox:latest
        command:
          - sh
          - -c
          - |
            while true; do
              # Logs de diferentes servicios simulados
              echo "ACCESS: \$(date -Iseconds) - GET /api/v1/users - 200 - \$(shuf -i 10-200 -n 1)ms - User: user\$(shuf -i 1-100 -n 1)"
              sleep 3
              
              echo "AUTH: \$(date -Iseconds) - Login attempt user\$(shuf -i 1-100 -n 1) - SUCCESS - IP: 192.168.\$(shuf -i 1-255 -n 1).\$(shuf -i 1-255 -n 1)"
              sleep 4
              
              # ERROR 401 (15% de probabilidad)
              if [ \$(shuf -i 1-100 -n 1) -lt 15 ]; then
                echo "SECURITY: \$(date -Iseconds) - WARNING - Failed login attempt for admin - IP: 10.0.\$(shuf -i 1-255 -n 1).\$(shuf -i 1-255 -n 1)"
              fi
              
              # ERROR 500 (10% de probabilidad)
              if [ \$(shuf -i 1-100 -n 1) -lt 10 ]; then
                echo "ERROR: \$(date -Iseconds) - API /api/v1/orders - 500 Internal Server Error - Trace: 78a9f1c\$(shuf -i 1000-9999 -n 1)"
              fi
              
              # Logs de base de datos
              echo "DB: \$(date -Iseconds) - Query SELECT * FROM orders - \$(shuf -i 1-100 -n 1) rows - \$(shuf -i 5-50 -n 1)ms"
              sleep 5
              
              # Kill el pod después de 5 minutos para simular reinicio (opcional)
              # if [ \$(date +%M) -eq 0 ]; then exit 1; fi
            done
EOF