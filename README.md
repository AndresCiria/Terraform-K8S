# Kubernetes Platform con Observabilidad

## 🚀 Despliegue automático en 2 pasos

### Paso 1: Clonar y ejecutar

```bash
git clone https://github.com/tu-usuario/terraform-k8s-platform.git
cd terraform-k8s-platform
make bootstrap
make config
make deploy

export KUBECONFIG=$(pwd)/terraform/kubeconfig
echo 'export KUBECONFIG=/root/Terraform-k8s/terraform/kubeconfig' >> ~/.bashrc
source ~/.bashrc
# Ver estado
kubectl get nodes
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Mostrar acceso
make grafana
kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0

kind delete cluster --name k8s-local

helm install loki grafana/loki -n monitoring \
  --version 5.42.0 \
  --set deploymentMode=SingleBinary \
  --set singleBinary.replicas=1 \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set persistence.enabled=false \
  --set agent.enabled=false

kubectl scale deployment loki-grafana-agent-operator -n monitoring --replicas=0
kubectl delete daemonset loki-logs -n monitoring 2>/dev/null || true


# 1. Asegurar que el port-forward está activo
kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0
kubectl port-forward -n default svc/jenkins-manual 30005:8080 --address=0.0.0.0

# 2. En otra terminal, aplicar Terraform
cd terraform
terraform plan   # Ver qué va a crear
terraform apply  # Crear las alertas

# 1. Desinstalar Helm
helm uninstall jenkins -n default

# 2. Crear deployment manual
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-manual
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-manual
  template:
    metadata:
      labels:
        app: jenkins-manual
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts-jdk17
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 50000
          name: agent
        env:
        - name: JENKINS_OPTS
          value: "--prefix=/jenkins"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-home
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-manual
  namespace: default
spec:
  type: NodePort
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30005
  - name: agent
    port: 50000
    targetPort: 50000
  selector:
    app: jenkins-manual
EOF