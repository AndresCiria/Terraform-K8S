output "cluster_name" {
  description = "Nombre del cluster"
  value       = var.cluster_name
}

output "api_server" {
  description = "Dirección del API Server"
  value       = "https://${var.api_server_address == "0.0.0.0" ? "127.0.0.1" : var.api_server_address}:6443"
}

output "grafana_url" {
  description = "URL para acceder a Grafana"
  value       = var.enable_observability ? "http://${var.api_server_address == "0.0.0.0" ? "127.0.0.1" : var.api_server_address}:${var.grafana_port}" : "No disponible"
}

output "grafana_password" {
  description = "Contraseña de admin para Grafana"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig"
  value       = "./kubeconfig"
}

output "nginx_app_url" {
  description = "URL para acceder a la aplicación Nginx"
  value       = var.deploy_test_apps ? "http://${var.api_server_address == "0.0.0.0" ? "127.0.0.1" : var.api_server_address}:${var.nginx_port}" : "No disponible"
}

output "hello_api_url" {
  description = "URL para acceder a la API Hello World"
  value       = var.deploy_test_apps ? "http://${var.api_server_address == "0.0.0.0" ? "127.0.0.1" : var.api_server_address}:${var.hello_api_port}" : "No disponible"
}
