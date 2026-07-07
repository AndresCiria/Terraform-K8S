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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

locals {
  kubeconfig_path = "${path.module}/kubeconfig"
}

# 1. Crear cluster Kind
resource "kind_cluster" "k8s_cluster" {
  name = var.cluster_name
  
  kubeconfig_path = local.kubeconfig_path
  
  kind_config {
    kind = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    
    networking {
      api_server_address = var.api_server_address == "0.0.0.0" ? "127.0.0.1" : var.api_server_address
      api_server_port    = 6443
      pod_subnet         = "10.244.0.0/16"
      service_subnet     = "10.96.0.0/12"
    }
    
    node {
      role = "control-plane"
    }
    
    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }
  }
}

# 2. Esperar a que el cluster esté listo
resource "null_resource" "wait_for_cluster" {
  depends_on = [kind_cluster.k8s_cluster]
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      echo "⏳ Esperando a que el cluster esté listo..."
      kubectl wait --for=condition=ready node --all --timeout=180s
      echo "✅ Cluster listo"
    EOT
  }
}

# 3. Añadir repositorios Helm
resource "null_resource" "helm_repos" {
  depends_on = [null_resource.wait_for_cluster]
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      echo "📝 Añadiendo repositorios Helm..."
      helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
      helm repo update
    EOT
  }
}

# 4. Desplegar PLG Stack con Helm (usando null_resource)
resource "null_resource" "deploy_plg" {
  depends_on = [null_resource.helm_repos]
  count      = var.enable_observability ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Creando namespace monitoring..."
      kubectl create namespace monitoring 2>/dev/null || true
      
      echo "📝 Instalando Loki (con los mismos parámetros que funcionaron manualmente)..."
      helm upgrade --install loki grafana/loki \
        --namespace monitoring \
        --set deploymentMode=SingleBinary \
        --set singleBinary.replicas=1 \
        --set loki.commonConfig.replication_factor=1 \
        --set loki.storage.type=filesystem \
        --set persistence.enabled=false \
        --wait
      
      echo "📝 Instalando Promtail..."
      helm upgrade --install promtail grafana/promtail \
        --namespace monitoring \
        --set loki.serviceName=loki \
        --set loki.scheme=http \
        --wait
      
      echo "📝 Instalando Grafana..."
      helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set adminPassword=${var.grafana_admin_password} \
        --set persistence.enabled=false \
        --set service.type=NodePort \
        --set service.nodePort=${var.grafana_port} \
        --set datasources.prometheus.type=prometheus \
        --set datasources.prometheus.url=http://prometheus-server:80 \
        --set datasources.prometheus.isDefault=false \
        --wait
      
      echo "✅ PLG Stack desplegado correctamente"
    EOT
  }
}

# 6. Desplegar Prometheus y kube-state-metrics
resource "null_resource" "deploy_prometheus" {
  depends_on = [null_resource.deploy_plg]
  count      = var.enable_observability ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Añadiendo repositorio prometheus-community..."
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
      helm repo update
      
      echo "📝 Instalando kube-state-metrics..."
      helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
        --namespace monitoring \
        --set replicas=1 \
        --wait
      
      echo "📝 Instalando Prometheus (modo simple)..."
      helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring \
        --set alertmanager.enabled=false \
        --set pushgateway.enabled=false \
        --set server.persistentVolume.enabled=false \
        --set server.service.type=ClusterIP \
        --wait
      
      echo "✅ Prometheus y kube-state-metrics desplegados"
    EOT
  }
}

# 5. Desplegar aplicaciones de prueba
resource "null_resource" "deploy_apps" {
  depends_on = [null_resource.deploy_plg]
  count      = var.deploy_test_apps ? 1 : 0
  
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Desplegando aplicaciones de prueba..."
      
      helm upgrade --install nginx-app bitnami/nginx \
        --set replicaCount=${var.app_replicas} \
        --set service.type=NodePort \
        --set service.nodePorts.http=${var.nginx_port} \
        --wait
      
      helm upgrade --install hello-api bitnami/hello-world \
        --set replicaCount=${var.app_replicas} \
        --set service.type=NodePort \
        --set service.nodePorts.http=${var.hello_api_port} \
        --wait
      
      echo "✅ Aplicaciones desplegadas correctamente"
    EOT
  }
}
