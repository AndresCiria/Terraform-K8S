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