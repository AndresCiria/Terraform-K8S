#!/bin/bash
# setup-grafana-security.sh
# Configuración completa de Grafana para seguridad

cd ~/Terraform-k8s/terraform
export KUBECONFIG=$(pwd)/kubeconfig

echo "🔧 Configurando Grafana para seguridad..."

GRAFANA_URL="http://192.168.122.53:30001"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"
FOLDER_UID="ffsozcllt70n4a"

echo ""
echo "Configurando datasources..."

LOKI_EXISTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/Loki" | jq -r '.uid' 2>/dev/null)
if [ -z "$LOKI_EXISTS" ] || [ "$LOKI_EXISTS" == "null" ]; then
    echo "📝 Creando datasource Loki..."
    curl -s -X POST -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Loki",
        "type": "loki",
        "url": "http://loki:3100",
        "access": "proxy",
        "isDefault": true,
        "version": 1,
        "editable": true
      }' > /dev/null
    echo "Datasource Loki creado"
else
    echo "Datasource Loki ya existe (UID: $LOKI_EXISTS)"
fi

PROM_EXISTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/Prometheus" | jq -r '.uid' 2>/dev/null)
if [ -z "$PROM_EXISTS" ] || [ "$PROM_EXISTS" == "null" ]; then
    echo "📝 Creando datasource Prometheus..."
    curl -s -X POST -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus-server:80",
        "access": "proxy",
        "isDefault": false,
        "version": 1,
        "editable": true
      }' > /dev/null
    echo "Datasource Prometheus creado"
else
    echo "Datasource Prometheus ya existe (UID: $PROM_EXISTS)"
fi

echo ""
echo "Creando alertas de seguridad..."

create_alert() {
    local TITLE="$1"
    local EXPR="$2"
    local SEVERITY="$3"
    local SUMMARY="$4"
    local DESCRIPTION="$5"
    local FOR="${6:-1m}"
    
    echo "   - $TITLE"
    curl -s -X POST -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/v1/provisioning/alert-rules" \
      -H "Content-Type: application/json" \
      -d "{
        \"title\": \"$TITLE\",
        \"condition\": \"A\",
        \"data\": [
          {
            \"refId\": \"A\",
            \"relativeTimeRange\": {
              \"from\": 300,
              \"to\": 0
            },
            \"datasourceUid\": \"loki\",
            \"model\": {
              \"expr\": \"$EXPR\",
              \"intervalMs\": 1000,
              \"maxDataPoints\": 43200,
              \"refId\": \"A\"
            }
          }
        ],
        \"for\": \"$FOR\",
        \"labels\": {
          \"severity\": \"$SEVERITY\",
          \"namespace\": \"security\"
        },
        \"annotations\": {
          \"summary\": \"$SUMMARY\",
          \"description\": \"$DESCRIPTION\"
        },
        \"folderUID\": \"$FOLDER_UID\"
      }" | jq -r '.message' 2>/dev/null | grep -v "null" || echo "   ✅ Creada"
}

create_alert \
  "Acceso no autorizado detectado" \
  "sum(count_over_time({namespace=~\"default|monitoring|security\"} |= \"Failed login\" [5m])) > 3" \
  "warning" \
  "Intentos de login fallidos detectados" \
  "Se han detectado más de 3 intentos de login fallidos en los últimos 5 minutos" \
  "1m"

create_alert \
  "Posible escalada de privilegios" \
  "sum(count_over_time({namespace=~\"default|monitoring|security\"} |= \"sudo\" or |= \"privileged\" [5m])) > 0" \
  "critical" \
  "Escalada de privilegios detectada" \
  "Se ha detectado una posible escalada de privilegios" \
  "30s"

create_alert \
  "Posible ataque detectado" \
  "sum(count_over_time({namespace=~\"default|monitoring|security\"} |= \"attack\" or |= \"exploit\" [5m])) > 0" \
  "critical" \
  "Posible ataque detectado" \
  "Se ha detectado actividad sospechosa que podría indicar un ataque" \
  "30s"

echo ""
echo "Creando Dashboard de Seguridad..."

DASHBOARD_JSON=$(cat <<'EOF'
{
  "dashboard": {
    "title": "Security Dashboard",
    "tags": ["security", "falco", "kubernetes"],
    "timezone": "browser",
    "schemaVersion": 16,
    "panels": [
      {
        "id": 1,
        "title": "Eventos de Seguridad (Falco)",
        "type": "logs",
        "targets": [
          {
            "expr": "{namespace=\"security\"} |= \"Critical\"",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Alertas Activas",
        "type": "stat",
        "targets": [
          {
            "expr": "sum by (severity) (alertmanager_alerts{state=\"active\"})",
            "legendFormat": "{{severity}}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 4, "w": 8, "x": 0, "y": 12}
      },
      {
        "id": 3,
        "title": "Reglas de Falco",
        "type": "table",
        "targets": [
          {
            "expr": "{namespace=\"security\"} |= \"Critical\" | json",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 16, "x": 8, "y": 12}
      }
    ],
    "refresh": "10s",
    "time": {
      "from": "now-1h",
      "to": "now"
    }
  },
  "overwrite": true
}
EOF
)

curl -s -X POST -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/dashboards/db" \
  -H "Content-Type: application/json" \
  -d "$DASHBOARD_JSON" > /dev/null

echo "Dashboard creado"

echo ""
echo "=========================================="
echo "Configuración completada"
echo "=========================================="
echo ""
echo "Acceso a Grafana: http://192.168.122.53:30001"
echo "   Usuario: admin"
echo "   Contraseña: admin123"
echo ""
echo "Componentes configurados:"
echo "   ✅ Datasource: Loki (http://loki:3100)"
echo "   ✅ Datasource: Prometheus (http://prometheus-server:80)"
echo "   ✅ Carpeta: Security Alerts (UID: $FOLDER_UID)"
echo "   ✅ Alerta: Acceso no autorizado detectado"
echo "   ✅ Alerta: Posible escalada de privilegios"
echo "   ✅ Alerta: Posible ataque detectado"
echo "   ✅ Dashboard: Security Dashboard"
echo ""
echo "Para ver logs de Falco:"
echo "   1. Ve a Explore"
echo "   2. Selecciona datasource Loki"
echo "   3. Query: {namespace=\"security\"} |= \"Critical\""