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
  depends_on = [null_resource.wait_for_cluster]
  count      = var.enable_observability ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}

      echo "📝 Creando namespace monitoring..."
      kubectl create namespace monitoring 2>/dev/null || true

      echo "📝 Añadiendo repositorios Helm..."
      helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
      helm repo update

      echo "📝 Instalando Loki (versión 5.42.0, sin gateway ni agente)..."
      helm upgrade --install loki grafana/loki \
        --namespace monitoring \
        --version 5.42.0 \
        --set deploymentMode=SingleBinary \
        --set loki.storage.type=filesystem \
        --set persistence.enabled=false \
        --set agent.enabled=false \
        --set gateway.enabled=false \
        --wait

      echo "🧹 Eliminando agentes problemáticos de Loki..."
      kubectl scale deployment loki-grafana-agent-operator -n monitoring --replicas=0 2>/dev/null || true
      kubectl delete daemonset loki-logs -n monitoring 2>/dev/null || true

      echo "📝 Instalando Promtail (con límite de archivos abiertos)..."
      helm upgrade --install promtail grafana/promtail \
        --namespace monitoring \
        -f - <<YAML
loki:
  url: http://loki:3100
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
  scrape_configs:
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container
        # Elimina o comenta la siguiente línea para recoger TODOS los namespaces
        # - action: keep
        #   source_labels: [__meta_kubernetes_namespace]
        #   regex: "^(default|monitoring)$"
      max_open_files: 50
      file_watch:
        min_poll_frequency: 1s
        max_poll_frequency: 30s
resources:
  limits:
    memory: 128Mi
    cpu: 200m
  requests:
    memory: 64Mi
    cpu: 100m
YAML

      echo "📝 Instalando Prometheus y kube-state-metrics..."
      helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring \
        --set alertmanager.enabled=false \
        --set pushgateway.enabled=false \
        --set server.persistentVolume.enabled=false \
        --set server.service.type=ClusterIP \
        --wait

      helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
        --namespace monitoring \
        --set replicas=1 \
        --wait

      echo "📝 Instalando Grafana con datasources preconfigurados..."
      helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set adminPassword=${var.grafana_admin_password} \
        --set persistence.enabled=false \
        --set service.type=NodePort \
        --set service.nodePort=${var.grafana_port} \
        --wait

      echo "📝 Configurando datasources en Grafana..."
      kubectl apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
        isDefault: true
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus-server:80
        isDefault: false
YAML

      echo "🔄 Reiniciando Grafana para aplicar la configuración..."
      kubectl rollout restart deployment grafana -n monitoring
      kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0
      echo "✅ PLG Stack y Prometheus desplegados correctamente"
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
