# terraform/security.tf - DevSecOps: Kyverno + Falco

# ============================================
# 1. DESPLEGAR KYVERNO (Políticas como Código)
# ============================================
resource "null_resource" "deploy_kyverno" {
  depends_on = [null_resource.wait_for_cluster]
  count      = var.enable_security ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Instalando Kyverno (motor de políticas)..."
      helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
      helm repo update
      
      helm upgrade --install kyverno kyverno/kyverno \
        --namespace kyverno \
        --create-namespace \
        --set replicaCount=1
      
      echo "📝 Aplicando políticas de seguridad..."
      kubectl apply -f - <<YAML
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: enforce
  rules:
    - name: require-image-tag
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "El tag 'latest' no está permitido. Utiliza una versión específica."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-ports
spec:
  validationFailureAction: enforce
  rules:
    - name: validate-host-ports
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Los puertos host están restringidos."
        pattern:
          spec:
            containers:
              - hostPort: 0
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: enforce
  rules:
    - name: privilege-escalation
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "No se permite la escalada de privilegios."
        pattern:
          spec:
            containers:
              - securityContext:
                  allowPrivilegeEscalation: false
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: enforce
  rules:
    - name: check-run-as-non-root
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Los contenedores deben ejecutarse como usuario no root."
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true
YAML
      
      echo "✅ Kyverno y políticas desplegadas correctamente"
    EOT
  }
}

# ============================================
# 2. DESPLEGAR FALCO (Detección de amenazas)
# ============================================
resource "null_resource" "deploy_falco" {
  depends_on = [null_resource.deploy_kyverno]
  count      = var.enable_security ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Instalando Falco (detección de amenazas)..."
      helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
      helm repo update
      
      helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --create-namespace \
        --set falco.jsonOutput=true \
        --set falco.logLevel=info \
        --set falco.fileOutput.enabled=false \
        --set falco.fileOutput.keepAlive=false \
        --set falco.syslogOutput.enabled=true \
        --set falco.httpOutput.enabled=true \
        --set falco.httpOutput.url="http://loki.monitoring:3100/loki/api/v1/push" \
        --set falco.httpOutput.headers.Content-Type="application/json" \
        --set falco.rulesFile="/etc/falco/rules.d/custom_rules.yaml" \
        -f - <<YAML
# Configuración adicional de Falco (custom rules)
falco:
  rules:
    - rule: Terminal shell in container
      desc: Detecta un shell interactivo en un contenedor
      condition: spawned_process and proc.name in (ash, bash, sh, ksh, zsh) and proc.args contains "-i" and container.id != host
      output: "Shell interactivo ejecutado en contenedor (user=%user.name command=%proc.cmdline)"
      priority: WARNING
    - rule: Write below etc
      desc: Escritura no autorizada en /etc
      condition: open_write and fd.name startswith /etc and container.id != host
      output: "Escritura en /etc (user=%user.name command=%proc.cmdline)"
      priority: WARNING
    - rule: Database connection from unexpected source
      desc: Conexión a base de datos desde fuera del clúster
      condition: fd.type = ipv4 and fd.sip != "127.0.0.1" and fd.dport = 5432
      output: "Conexión a PostgreSQL detectada (ip=%fd.sip port=%fd.sport)"
      priority: CRITICAL
YAML
      
      echo "✅ Falco desplegado correctamente"
    EOT
  }
}

# ============================================
# 3. ALERTAS DE SEGURIDAD EN GRAFANA
# ============================================
resource "null_resource" "security_alerts" {
  depends_on = [null_resource.deploy_falco, null_resource.deploy_plg]
  count      = var.enable_security ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=${local.kubeconfig_path}
      
      echo "📝 Configurando alertas de seguridad en Grafana..."
      
      # Añadir reglas de alerta de seguridad
      kubectl apply -f - <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-security-rules
  namespace: monitoring
  labels:
    grafana_alert: "1"
data:
  security-alerts.yaml: |
    apiVersion: 1
    groups:
      - name: Security Alerts
        folder: Security
        interval: 60s
        rules:
          - uid: security_failed_login
            title: "Acceso no autorizado detectado"
            condition: A
            data:
              - refId: A
                datasourceUid: __expr__
                model:
                  expr: "sum(count_over_time({namespace=~\"default|monitoring\"} |= \"Failed login\" [5m])) > 3"
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "Intentos de login fallidos detectados"
              description: "Se han detectado más de 3 intentos de login fallidos en los últimos 5 minutos"
          
          - uid: security_privilege_escalation
            title: "Posible escalada de privilegios"
            condition: A
            data:
              - refId: A
                datasourceUid: __expr__
                model:
                  expr: "sum(count_over_time({namespace=~\"default|monitoring\"} |= \"sudo\" or |= \"privileged\" [5m])) > 0"
            for: 30s
            labels:
              severity: critical
            annotations:
              summary: "Escalada de privilegios detectada"
              description: "Se ha detectado una posible escalada de privilegios"
          
          - uid: security_attack
            title: "Posible ataque detectado"
            condition: A
            data:
              - refId: A
                datasourceUid: __expr__
                model:
                  expr: "sum(count_over_time({namespace=~\"default|monitoring\"} |= \"attack\" or |= \"exploit\" [5m])) > 0"
            for: 30s
            labels:
              severity: critical
            annotations:
              summary: "Posible ataque detectado"
              description: "Se ha detectado actividad sospechosa que podría indicar un ataque"
YAML
      
      echo "🔄 Reiniciando Grafana para aplicar alertas..."
      kubectl rollout restart deployment grafana -n monitoring
      
      echo "✅ Alertas de seguridad configuradas"
    EOT
  }
}