# Eliminar los helm releases
helm uninstall nginx-app -n default 2>/dev/null || true
helm uninstall hello-api -n default 2>/dev/null || true
kubectl delete deployment nginx-app -n default 2>/dev/null || true
kubectl delete deployment hello-api -n default 2>/dev/null || true
kubectl delete service nginx-app -n default 2>/dev/null || true
kubectl delete service hello-api -n default 2>/dev/null || true

# Desplegar con kubectl (evita problemas de Kyverno)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.3
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-app
  namespace: default
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30002
  selector:
    app: nginx-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-api
  template:
    metadata:
      labels:
        app: hello-api
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo:latest
        args:
        - "-text=Hello API v1.0 - $(hostname)"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: hello-api
  namespace: default
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 5678
    nodePort: 30003
  selector:
    app: hello-api
EOF