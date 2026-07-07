# terraform/terraform.tfvars.example
# Copiar a terraform.tfvars y ajustar según necesidad

cluster_name         = "k8s-local"
api_server_address   = "127.0.0.1"  # Cambiar por IP real si es necesario
worker_count         = 2
grafana_admin_password = "admin123"
loki_storage_size    = "5Gi"
app_replicas         = 2
enable_observability = true
deploy_test_apps     = true