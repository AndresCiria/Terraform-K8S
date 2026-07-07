#!/bin/bash
# scripts/bootstrap.sh - Instala todas las dependencias

set -e

echo "=== 🚀 Instalando dependencias para Kubernetes Platform ==="

# Detectar sistema operativo
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="darwin";;
    *)          echo "❌ Sistema operativo no soportado: ${OS}"; exit 1;;
esac

echo "📦 Sistema: ${OS_TYPE} (${ARCH})"

# 1. Verificar/Instalar Docker
echo "🔍 Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo "📥 Instalando Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "⚠️  Docker instalado. Es posible que necesites cerrar sesión y volver a entrar."
else
    echo "✅ Docker ya está instalado"
fi

# 2. Verificar/Instalar Kind
echo "🔍 Verificando Kind..."
if ! command -v kind &> /dev/null; then
    echo "📥 Instalando Kind..."
    KIND_VERSION="v0.20.0"
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS_TYPE}-${ARCH}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ Kind instalado"
else
    echo "✅ Kind ya está instalado"
fi

# 3. Verificar/Instalar kubectl
echo "🔍 Verificando kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo "📥 Instalando kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS_TYPE}/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    echo "✅ kubectl instalado"
else
    echo "✅ kubectl ya está instalado"
fi

# 4. Verificar/Instalar Helm
echo "🔍 Verificando Helm..."
if ! command -v helm &> /dev/null; then
    echo "📥 Instalando Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm instalado"
else
    echo "✅ Helm ya está instalado"
fi

# 5. Verificar/Instalar Terraform
echo "🔍 Verificando Terraform..."
if ! command -v terraform &> /dev/null; then
    echo "📥 Instalando Terraform..."
    TERRAFORM_VERSION="1.9.4"
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS_TYPE}_${ARCH}.zip"
    unzip terraform_${TERRAFORM_VERSION}_${OS_TYPE}_${ARCH}.zip
    sudo mv terraform /usr/local/bin/
    rm terraform_${TERRAFORM_VERSION}_${OS_TYPE}_${ARCH}.zip
    echo "✅ Terraform instalado"
else
    echo "✅ Terraform ya está instalado"
fi

echo ""
echo "=== ✅ Todas las dependencias instaladas correctamente ==="
echo ""
echo "📋 Versiones instaladas:"
echo "  Docker: $(docker --version 2>/dev/null || echo 'No disponible')"
echo "  Kind: $(kind version 2>/dev/null || echo 'No disponible')"
echo "  kubectl: $(kubectl version --client 2>/dev/null | head -1 || echo 'No disponible')"
echo "  Helm: $(helm version --short 2>/dev/null || echo 'No disponible')"
echo "  Terraform: $(terraform version 2>/dev/null | head -1 || echo 'No disponible')"
echo ""

# Verificar que Docker está corriendo
if ! docker info &> /dev/null; then
    echo "⚠️  Docker no está corriendo. Iniciando..."
    sudo systemctl start docker 2>/dev/null || echo "⚠️  No se pudo iniciar Docker automáticamente"
fi

echo ""
echo "🚀 Ahora puedes ejecutar: make deploy"