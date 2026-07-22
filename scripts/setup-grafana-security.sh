#!/bin/bash

cd ~/Terraform-k8s/terraform
export KUBECONFIG=$(pwd)/kubeconfig

GRAFANA_URL="http://192.168.122.53:30001"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"
FOLDER_UID="ffsozcllt70n4a"
LOKI_UID="ffsoxnir2g934a"
PROMETHEUS_UID="efsoxsiavp8u8d"

echo "Configurando Grafana para seguridad..."

if ! curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/health" | grep -q "ok"; then
    echo "Error: Grafana no responde"
    exit 1
fi

echo "Creando datasource Loki..."
LOKI_EXISTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/Loki" | jq -r '.uid' 2>/dev/null)
if [ -z "$LOKI_EXISTS" ] || [ "$LOKI_EXISTS" == "null" ]; then
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
    echo "Datasource Loki ya existe"
fi

echo "Creando datasource Prometheus..."
PROM_EXISTS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/Prometheus" | jq -r '.uid' 2>/dev/null)
if [ -z "$PROM_EXISTS" ] || [ "$PROM_EXISTS" == "null" ]; then
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
    echo "Datasource Prometheus ya existe"
fi

echo "Creando alertas de seguridad..."
curl -X POST -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/ruler/grafana/api/v1/rules/$FOLDER_UID" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Security Alerts\",
    \"interval\": \"60s\",
    \"rules\": [
      {
        \"grafana_alert\": {
          \"title\": \"Acceso no autorizado detectado\",
          \"condition\": \"A\",
          \"data\": [
            {
              \"refId\": \"A\",
              \"relativeTimeRange\": {
                \"from\": 300,
                \"to\": 0
              },
              \"datasourceUid\": \"$LOKI_UID\",
              \"model\": {
                \"expr\": \"sum(count_over_time({namespace=~\\\"default|monitoring|security\\\"} |= \\\"Failed login\\\" [5m])) > 3\",
                \"intervalMs\": 1000,
                \"maxDataPoints\": 43200,
                \"refId\": \"A\"
              }
            }
          ],
          \"for\": \"60s\",
          \"labels\": {
            \"severity\": \"warning\",
            \"namespace\": \"security\"
          },
          \"annotations\": {
            \"summary\": \"Intentos de login fallidos detectados\",
            \"description\": \"Se han detectado mas de 3 intentos de login fallidos en los ultimos 5 minutos\"
          }
        }
      },
      {
        \"grafana_alert\": {
          \"title\": \"Posible escalada de privilegios\",
          \"condition\": \"A\",
          \"data\": [
            {
              \"refId\": \"A\",
              \"relativeTimeRange\": {
                \"from\": 300,
                \"to\": 0
              },
              \"datasourceUid\": \"$LOKI_UID\",
              \"model\": {
                \"expr\": \"sum(count_over_time({namespace=~\\\"default|monitoring|security\\\"} |= \\\"sudo\\\" or |= \\\"privileged\\\" [5m])) > 0\",
                \"intervalMs\": 1000,
                \"maxDataPoints\": 43200,
                \"refId\": \"A\"
              }
            }
          ],
          \"for\": \"30s\",
          \"labels\": {
            \"severity\": \"critical\",
            \"namespace\": \"security\"
          },
          \"annotations\": {
            \"summary\": \"Escalada de privilegios detectada\",
            \"description\": \"Se ha detectado una posible escalada de privilegios\"
          }
        }
      },
      {
        \"grafana_alert\": {
          \"title\": \"Posible ataque detectado\",
          \"condition\": \"A\",
          \"data\": [
            {
              \"refId\": \"A\",
              \"relativeTimeRange\": {
                \"from\": 300,
                \"to\": 0
              },
              \"datasourceUid\": \"$LOKI_UID\",
              \"model\": {
                \"expr\": \"sum(count_over_time({namespace=~\\\"default|monitoring|security\\\"} |= \\\"attack\\\" or |= \\\"exploit\\\" [5m])) > 0\",
                \"intervalMs\": 1000,
                \"maxDataPoints\": 43200,
                \"refId\": \"A\"
              }
            }
          ],
          \"for\": \"30s\",
          \"labels\": {
            \"severity\": \"critical\",
            \"namespace\": \"security\"
          },
          \"annotations\": {
            \"summary\": \"Posible ataque detectado\",
            \"description\": \"Se ha detectado actividad sospechosa que podria indicar un ataque\"
          }
        }
      }
    ]
  }" | jq '.'

echo "Creando dashboard de seguridad..."
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

echo "Configuracion completada"
echo "Acceso a Grafana: http://192.168.122.53:30001"
echo "Usuario: admin"
echo "Contraseña: admin123"
echo "Carpeta Security Alerts UID: $FOLDER_UID"
echo "Datasource Loki UID: $LOKI_UID"
echo "Datasource Prometheus UID: $PROMETHEUS_UID"