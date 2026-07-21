# terraform/alerts.tf
# Configuración de alertas en Grafana usando el proveedor de Grafana

# ============================================
# GRUPO 1: ALERTAS DE DISPONIBILIDAD (CAÍDAS)
# ============================================
resource "grafana_rule_group" "availability_alerts" {
  name             = "Availability Alerts"
  folder_uid       = "kubernetes-alerts"
  interval_seconds = 60

  depends_on = [null_resource.deploy_plg]

  # 1. Pod en CrashLoopBackOff
  rule {
    name      = "Pod en CrashLoopBackOff"
    condition = "A"
    for       = "1m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "pod_crash"
    }
    annotations = {
      summary     = "Pod {{ $labels.pod }} está en estado Failed o Unknown"
      description = "El pod {{ $labels.pod }} en el namespace {{ $labels.namespace }} no está ejecutándose correctamente. Revisa los logs: kubectl logs -n {{ $labels.namespace }} {{ $labels.pod }}"
      runbook     = "https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_pod_status_phase{phase=~\"Failed|Unknown\"} > 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 2. Node Not Ready
  rule {
    name      = "Node Not Ready"
    condition = "A"
    for       = "2m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "node_not_ready"
    }
    annotations = {
      summary     = "Nodo {{ $labels.node }} no está listo"
      description = "El nodo {{ $labels.node }} no está en estado Ready desde hace más de 2 minutos"
      runbook     = "https://kubernetes.io/docs/tasks/debug/debug-cluster/troubleshooting/"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_node_status_condition{condition=\"Ready\",status=\"false\"} > 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 3. Deployment sin réplicas disponibles
  rule {
    name      = "Deployment sin réplicas disponibles"
    condition = "A"
    for       = "1m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "deployment_no_replicas"
    }
    annotations = {
      summary     = "Deployment {{ $labels.deployment }} tiene 0 réplicas disponibles"
      description = "El deployment {{ $labels.deployment }} en el namespace {{ $labels.namespace }} no tiene réplicas disponibles"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_deployment_status_replicas_available == 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 4. Job fallido
  rule {
    name      = "Job fallido"
    condition = "A"
    for       = "30s"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "job_failed"
    }
    annotations = {
      summary     = "Job {{ $labels.job }} ha fallado"
      description = "El job {{ $labels.job }} en el namespace {{ $labels.namespace }} ha fallado"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_job_status_failed > 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 5. Service sin endpoints
  rule {
    name      = "Servicio sin endpoints disponibles"
    condition = "A"
    for       = "1m"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "service_no_endpoints"
    }
    annotations = {
      summary     = "Servicio {{ $labels.service }} sin endpoints"
      description = "El servicio {{ $labels.service }} en el namespace {{ $labels.namespace }} no tiene endpoints disponibles"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_endpoint_address_available < 1"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }
}

# ============================================
# GRUPO 2: ALERTAS DE RECURSOS (RENDIMIENTO)
# ============================================
resource "grafana_rule_group" "resource_alerts" {
  name             = "Resource Alerts"
  folder_uid       = "kubernetes-alerts"
  interval_seconds = 60

  depends_on = [null_resource.deploy_plg]
  
  # 1. Alto uso de CPU (pod)
  rule {
    name      = "Alto uso de CPU en pod"
    condition = "A"
    for       = "3m"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "high_cpu"
    }
    annotations = {
      summary     = "Pod {{ $labels.pod }} usando >80% de CPU"
      description = "El pod {{ $labels.pod }} en el namespace {{ $labels.namespace }} está usando más del 80% de CPU"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "kube_pod_status_phase{phase=~\"Failed|Unknown\"} > 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 2. Alto uso de Memoria (pod)
  rule {
    name      = "Alto uso de Memoria en pod"
    condition = "A"
    for       = "3m"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "high_memory"
    }
    annotations = {
      summary     = "Pod {{ $labels.pod }} usando >80% de memoria límite"
      description = "El pod {{ $labels.pod }} en el namespace {{ $labels.namespace }} está usando más del 80% de su memoria límite"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "sum(container_memory_working_set_bytes{namespace!=\"kube-system\",container!=\"\"}) by (pod, namespace) / sum(kube_pod_container_resource_limits{resource=\"memory\"}) by (pod, namespace) > 0.8"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 3. Memoria disponible baja en nodo
  rule {
    name      = "Memoria disponible baja en nodo"
    condition = "A"
    for       = "5m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "node_low_memory"
    }
    annotations = {
      summary     = "Nodo {{ $labels.node }} con <10% de memoria disponible"
      description = "El nodo {{ $labels.node }} tiene menos del 10% de memoria disponible"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 4. Disco casi lleno en nodo
  rule {
    name      = "Disco casi lleno en nodo"
    condition = "A"
    for       = "5m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "node_low_disk"
    }
    annotations = {
      summary     = "Nodo {{ $labels.node }} con <15% de espacio disponible"
      description = "El nodo {{ $labels.node }} tiene menos del 15% de espacio en disco disponible"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "(node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100 < 15"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }
}

# ============================================
# GRUPO 3: ALERTAS DE LOGS (LOKI)
# ============================================
resource "grafana_rule_group" "logs_alerts" {
  name             = "Logs Alerts"
  folder_uid       = "kubernetes-alerts"
  interval_seconds = 60

  depends_on = [null_resource.deploy_plg]

  # 1. Demasiados errores en logs
  rule {
    name      = "Demasiados errores en logs (5m)"
    condition = "A"
    for       = "2m"
    labels = {
      severity   = "warning"
      namespace  = "loki"
      alert_type = "too_many_errors"
    }
    annotations = {
      summary     = "Más de 10 errores en los últimos 5 minutos"
      description = "Se han detectado más de 10 errores en los logs del namespace {{ $labels.namespace }} en los últimos 5 minutos"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "loki"
      model = jsonencode({
        expr          = "sum(count_over_time({namespace!=\"kube-system\"} |= \"error\" or |= \"ERROR\" or |= \"panic\" [5m])) > 10"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 2. Detectar panic en logs
  rule {
    name      = "Panic detectado en logs"
    condition = "A"
    for       = "30s"
    labels = {
      severity   = "critical"
      namespace  = "loki"
      alert_type = "panic_detected"
    }
    annotations = {
      summary     = "Panic detectado en {{ $labels.pod }}"
      description = "Se ha detectado un panic en el pod {{ $labels.pod }} del namespace {{ $labels.namespace }}"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 60
        to   = 0
      }
      datasource_uid = "loki"
      model = jsonencode({
        expr          = "sum(count_over_time({namespace!=\"kube-system\"} |= \"panic\" [1m])) > 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 3. Intentos de login fallidos (seguridad)
  rule {
    name      = "Intentos de login fallidos detectados"
    condition = "A"
    for       = "1m"
    labels = {
      severity   = "warning"
      namespace  = "security"
      alert_type = "failed_login_attempts"
    }
    annotations = {
      summary     = "Intentos de login fallidos detectados"
      description = "Se han detectado intentos de login fallidos en el sistema"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "loki"
      model = jsonencode({
        expr          = "sum(count_over_time({namespace!=\"kube-system\"} |= \"Failed login attempt\" [5m])) > 3"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 4. Pods reiniciándose frecuentemente
  rule {
    name      = "Pod reiniciándose frecuentemente"
    condition = "A"
    for       = "2m"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "pod_restarting"
    }
    annotations = {
      summary     = "Pod {{ $labels.pod }} reiniciándose frecuentemente"
      description = "El pod {{ $labels.pod }} en el namespace {{ $labels.namespace }} se ha reiniciado más de 3 veces en los últimos 5 minutos"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "loki"
      model = jsonencode({
        expr          = "sum(count_over_time({namespace!=\"kube-system\"} |= \"restart\" or |= \"Restarting\" [5m])) > 3"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }
}

# ============================================
# GRUPO 4: ALERTAS DE SERVICIOS Y APIs
# ============================================
resource "grafana_rule_group" "service_alerts" {
  name             = "Service Alerts"
  folder_uid       = "kubernetes-alerts"
  interval_seconds = 60

  depends_on = [null_resource.deploy_plg]
  
  # 1. Errores HTTP 5xx
  rule {
    name      = "Errores HTTP 5xx detectados"
    condition = "A"
    for       = "2m"
    labels = {
      severity   = "warning"
      namespace  = "kubernetes"
      alert_type = "http_5xx_errors"
    }
    annotations = {
      summary     = "Más de 5 errores HTTP 5xx en los últimos 5 minutos"
      description = "Se han detectado más de 5 errores HTTP 5xx en las aplicaciones"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "sum(rate(nginx_ingress_controller_requests{status=~\"5..\"}[5m])) > 5"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }

  # 2. Certificado expirando
  rule {
    name      = "Certificado expirando pronto"
    condition = "A"
    for       = "1m"
    labels = {
      severity   = "critical"
      namespace  = "kubernetes"
      alert_type = "certificate_expiring"
    }
    annotations = {
      summary     = "Certificado expira en menos de 7 días"
      description = "El certificado para {{ $labels.kubernetes_ingress_name }} expira en menos de 7 días ({{ $value }} segundos)"
    }

    data {
      ref_id = "A"
      relative_time_range {
        from = 604800
        to   = 0
      }
      datasource_uid = "prometheus"
      model = jsonencode({
        expr          = "(avg by (kubernetes_ingress_name) (nginx_ingress_controller_ssl_expire_time_seconds) - time()) < 604800"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }
  }
}