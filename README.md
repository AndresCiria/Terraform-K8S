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

# 2. En otra terminal, aplicar Terraform
cd terraform
terraform plan   # Ver qué va a crear
terraform apply  # Crear las alertas