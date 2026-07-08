cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
  namespace: default
  labels:
    app: log-generator
    type: test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
        type: test
    spec:
      containers:
      - name: logger
        image: busybox:latest
        command:
          - sh
          - -c
          - |
            while true; do
              # Logs INFO
              echo "INFO: $(date -Iseconds) - Service log-generator running normally - Pod: \$HOSTNAME"
              sleep 2
              
              # Logs WARN (10% de probabilidad)
              if [ \$(shuf -i 1-10 -n 1) -eq 1 ]; then
                echo "WARN: $(date -Iseconds) - High latency detected on pod \$HOSTNAME - Response time: \$(shuf -i 100-500 -n 1)ms"
              fi
              
              # Logs ERROR (5% de probabilidad)
              if [ \$(shuf -i 1-20 -n 1) -eq 1 ]; then
                echo "ERROR: $(date -Iseconds) - Connection timeout in pod \$HOSTNAME - Retrying..."
              fi
              
              sleep 2
            done
EOF