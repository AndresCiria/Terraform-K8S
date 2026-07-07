# terraform/variables.tf
variable "cluster_name" {
  description = "Nombre del cluster Kubernetes"
  type        = string
  default     = "k8s-local"
}

variable "api_server_address" {
  description = "Dirección IP para el API Server"
  type        = string
  default     = "127.0.0.1"
}

variable "worker_count" {
  description = "Número de nodos worker"
  type        = number
  default     = 2
}

variable "grafana_admin_password" {
  description = "Contraseña de admin para Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "loki_storage_size" {
  description = "Tamaño de almacenamiento para Loki"
  type        = string
  default     = "5Gi"
}

variable "app_replicas" {
  description = "Número de réplicas para aplicaciones de prueba"
  type        = number
  default     = 2
}

variable "enable_observability" {
  description = "Habilitar el PLG stack (Loki + Promtail + Grafana)"
  type        = bool
  default     = true
}

variable "deploy_test_apps" {
  description = "Desplegar aplicaciones de prueba"
  type        = bool
  default     = true
}