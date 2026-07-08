cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-demo
  namespace: default
  labels:
    app: api-demo
    type: test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-demo
  template:
    metadata:
      labels:
        app: api-demo
        type: test
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:latest
        args:
          - "-text=API v1.0 - Pod: $(hostname) - $(date)"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: api-demo
  namespace: default
spec:
  selector:
    app: api-demo
  ports:
  - port: 80
    targetPort: 5678
  type: ClusterIP
EOF