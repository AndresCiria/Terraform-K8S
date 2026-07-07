# terraform/outputs.tf
output "cluster_name" {
  description = "Nombre del cluster"
  value       = var.cluster_name
}

output "api_server" {
  description = "Dirección del API Server"
  value       = "https://${var.api_server_address}:6443"
}

output "grafana_url" {
  description = "URL para acceder a Grafana"
  value       = var.enable_observability ? "http://${var.api_server_address}:30001" : "No disponible"
}

output "grafana_password" {
  description = "Contraseña de admin para Grafana"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig"
  value       = local.kubeconfig_path
}

output "nginx_app_url" {
  description = "URL para acceder a la aplicación Nginx"
  value       = var.deploy_test_apps ? "http://${var.api_server_address}:30002" : "No disponible"
}

output "hello_api_url" {
  description = "URL para acceder a la API Hello World"
  value       = var.deploy_test_apps ? "http://${var.api_server_address}:30003" : "No disponible"
}