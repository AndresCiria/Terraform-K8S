# Cluster
variable "cluster_name" {
  description = "Nombre del cluster Kubernetes"
  type        = string
  default     = "k8s-local"
}

variable "api_server_address" {
  description = "Dirección IP para el API Server (0.0.0.0 = auto-detect)"
  type        = string
  default     = "0.0.0.0"
}

variable "worker_count" {
  description = "Número de nodos worker"
  type        = number
  default     = 2
}

# Credenciales
variable "grafana_admin_password" {
  description = "Contraseña de admin para Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "grafana_url" {
  description = "URL de Grafana para el proveedor de Terraform"
  type        = string
  default     = "http://localhost:30001"
}

variable "grafana_port" {
  description = "Puerto NodePort para Grafana"
  type        = number
  default     = 30001
}

# Aplicaciones de prueba
variable "deploy_test_apps" {
  description = "Desplegar aplicaciones de prueba"
  type        = bool
  default     = true
}

variable "app_replicas" {
  description = "Número de réplicas para aplicaciones de prueba"
  type        = number
  default     = 2
}

variable "nginx_port" {
  description = "Puerto NodePort para Nginx"
  type        = number
  default     = 30002
}

variable "hello_api_port" {
  description = "Puerto NodePort para Hello API"
  type        = number
  default     = 30003
}

# Observabilidad
variable "enable_observability" {
  description = "Habilitar el PLG stack (Loki + Promtail + Grafana)"
  type        = bool
  default     = true
}