#!/bin/bash
# destroy.sh

echo "=== Destruyendo toda la infraestructura ==="

export OS_AUTH_URL="http://127.0.0.1:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="TU_PASSWORD"
export OS_TENANT_NAME="admin"

# Destruir todo
terraform destroy -auto-approve

echo "=== Infraestructura destruida ==="
