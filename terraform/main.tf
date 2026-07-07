# terraform/main.tf - Infraestructura completa

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Proveedores
provider "kind" {}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

# Variables locales
locals {
  kubeconfig_path = "${path.module}/kubeconfig"
  kind_config     = "${path.module}/kind-config.yaml"
}

# 1. Generar configuración de Kind
resource "local_file" "kind_config" {
  filename = local.kind_config
  
  content = templatefile("${path.module}/templates/kind-config.yaml.tpl", {
    cluster_name         = var.cluster_name
    api_server_address   = var.api_server_address
    worker_count        = var.worker_count
  })
}

# 2. Crear cluster Kind
resource "null_resource" "create_cluster" {
  triggers = {
    config_hash = filesha256(local.kind_config)
  }
  
  provisioner "local-exec" {
    command = "kind create cluster --config ${local.kind_config} --name ${var.cluster_name}"
  }
  
  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${var.cluster_name}"
  }
}

# 3. Obtener kubeconfig
resource "null_resource" "get_kubeconfig" {
  depends_on = [null_resource.create_cluster]
  
  provisioner "local-exec" {
    command = "kind get kubeconfig --name ${var.cluster_name} > ${local.kubeconfig_path}"
  }
}

data "local_file" "kubeconfig" {
  depends_on = [null_resource.get_kubeconfig]
  filename   = local.kubeconfig_path
}

# 4. Añadir repositorios Helm
resource "null_resource" "helm_repos" {
  depends_on = [null_resource.get_kubeconfig]
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      helm repo add grafana https://grafana.github.io/helm-charts
      helm repo add bitnami https://charts.bitnami.com/bitnami
      helm repo update
    EOT
  }
}

# 5. Desplegar PLG Stack
resource "helm_release" "loki" {
  depends_on = [null_resource.helm_repos]
  count      = var.enable_observability ? 1 : 0
  
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = "monitoring"
  create_namespace = true
  
  values = [
    templatefile("${path.module}/../helm/loki-values.yaml", {
      storage_size = var.loki_storage_size
    })
  ]
}

resource "helm_release" "promtail" {
  depends_on = [helm_release.loki]
  count      = var.enable_observability ? 1 : 0
  
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = "monitoring"
  
  values = [
    <<-EOT
    loki:
      serviceName: loki
      scheme: http
    EOT
  ]
}

resource "helm_release" "grafana" {
  depends_on = [helm_release.loki]
  count      = var.enable_observability ? 1 : 0
  
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  
  values = [
    templatefile("${path.module}/../helm/grafana-values.yaml", {
      admin_password = var.grafana_admin_password
    })
  ]
}

# 6. Desplegar aplicaciones de prueba
resource "helm_release" "nginx_app" {
  depends_on = [helm_release.loki]
  count      = var.deploy_test_apps ? 1 : 0
  
  name       = "nginx-app"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace  = "default"
  
  values = [
    <<-EOT
    replicaCount: ${var.app_replicas}
    service:
      type: NodePort
      nodePorts:
        http: 30002
    EOT
  ]
}

resource "helm_release" "hello_app" {
  depends_on = [helm_release.loki]
  count      = var.deploy_test_apps ? 1 : 0
  
  name       = "hello-api"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "hello-world"
  namespace  = "default"
  
  values = [
    <<-EOT
    replicaCount: ${var.app_replicas}
    service:
      type: NodePort
      nodePorts:
        http: 30003
    EOT
  ]
}