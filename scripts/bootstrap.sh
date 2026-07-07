#!/bin/bash
# scripts/bootstrap.sh - Instala TODAS las dependencias necesarias

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

# ============================================
# 1. INSTALAR DEPENDENCIAS CON APT (Linux)
# ============================================
if [ "${OS_TYPE}" = "linux" ]; then
    echo "📦 Instalando dependencias del sistema con apt..."
    
    # Actualizar repositorios
    sudo apt update || true
    
    # Instalar dependencias básicas (sin el repositorio de Helm que da problemas)
    sudo apt install -y \
        curl \
        wget \
        git \
        vim \
        nano \
        unzip \
        jq \
        tree \
        htop \
        net-tools \
        openssl \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        make \
        build-essential \
        python3 \
        python3-pip \
        python3-yaml
    
    echo "✅ Dependencias del sistema instaladas"
fi

# ============================================
# 2. INSTALAR DOCKER
# ============================================
echo "🔍 Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo "📥 Instalando Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado"
else
    echo "✅ Docker ya está instalado"
fi

# Iniciar Docker si no está corriendo
if ! docker info &> /dev/null; then
    echo "▶️  Iniciando Docker..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start || true
    sudo systemctl enable docker 2>/dev/null || sudo update-rc.d docker defaults || true
fi

# ============================================
# 3. INSTALAR KUBECTL (vía APT - más fiable)
# ============================================
echo "🔍 Verificando kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo "📥 Instalando kubectl..."
    
    if [ "${OS_TYPE}" = "linux" ]; then
        # Usando repositorio oficial de Kubernetes
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt update
        sudo apt install -y kubectl
        sudo apt-mark hold kubectl
    else
        # Para macOS
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    echo "✅ kubectl instalado"
else
    echo "✅ kubectl ya está instalado"
fi

# ============================================
# 4. INSTALAR KIND
# ============================================
echo "🔍 Verificando Kind..."
if ! command -v kind &> /dev/null; then
    echo "📥 Instalando Kind..."
    
    KIND_VERSION="v0.20.0"
    if [ "${OS_TYPE}" = "linux" ]; then
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
    else
        curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-darwin-${ARCH}"
    fi
    
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    echo "✅ Kind instalado"
else
    echo "✅ Kind ya está instalado"
fi

# ============================================
# 5. INSTALAR HELM (vía script oficial - más fiable)
# ============================================
echo "🔍 Verificando Helm..."
if ! command -v helm &> /dev/null; then
    echo "📥 Instalando Helm (vía script oficial)..."
    
    # Usar el script oficial de Helm (más fiable que apt)
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    echo "✅ Helm instalado"
else
    echo "✅ Helm ya está instalado"
fi

# ============================================
# 6. INSTALAR TERRAFORM (vía APT - más fiable)
# ============================================
echo "🔍 Verificando Terraform..."
if ! command -v terraform &> /dev/null; then
    echo "📥 Instalando Terraform..."
    
    if [ "${OS_TYPE}" = "linux" ]; then
        # Usando repositorio oficial de HashiCorp
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update
        sudo apt install -y terraform
    else
        # Para macOS
        TERRAFORM_VERSION="1.9.4"
        curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_${ARCH}.zip"
        unzip terraform_${TERRAFORM_VERSION}_darwin_${ARCH}.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_${TERRAFORM_VERSION}_darwin_${ARCH}.zip
    fi
    
    echo "✅ Terraform instalado"
else
    echo "✅ Terraform ya está instalado"
fi

# ============================================
# 7. HERRAMIENTAS ADICIONALES
# ============================================
echo "🔍 Instalando herramientas adicionales..."

# Instalar yq para procesar YAML
if ! command -v yq &> /dev/null; then
    echo "📥 Instalando yq..."
    if [ "${OS_TYPE}" = "linux" ]; then
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH} -O /usr/local/bin/yq 2>/dev/null || \
        sudo curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH} -o /usr/local/bin/yq
        sudo chmod +x /usr/local/bin/yq
    fi
fi

# ============================================
# 8. CREAR DIRECTORIOS NECESARIOS
# ============================================
mkdir -p ~/.kube
mkdir -p ~/.local/bin

# ============================================
# 9. CONFIGURAR ALIAS ÚTILES
# ============================================
if ! grep -q "# Kubernetes Platform aliases" ~/.bashrc 2>/dev/null; then
    echo "📝 Configurando alias en ~/.bashrc..."
    cat >> ~/.bashrc << 'EOF'

# Kubernetes Platform aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kx='kubectl exec -it'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Autocompletado para kubectl
source <(kubectl completion bash) 2>/dev/null || true

# Comandos de proyecto
alias k8s-status='make status'
alias k8s-logs='make logs'
alias k8s-grafana='make grafana'
EOF
fi

# ============================================
# 10. INSTALAR DEPENDENCIAS DE TERRAFORM
# ============================================
echo "📥 Instalando proveedores de Terraform..."
cd terraform 2>/dev/null && terraform init || true
cd .. 2>/dev/null || true

# ============================================
# RESUMEN FINAL
# ============================================
echo ""
echo "=== ✅ Todas las dependencias instaladas correctamente ==="
echo ""
echo "📋 Versiones instaladas:"
echo "  Docker: $(docker --version 2>/dev/null || echo 'No disponible')"
echo "  Kind: $(kind version 2>/dev/null | head -1 || echo 'No disponible')"
echo "  kubectl: $(kubectl version --client 2>/dev/null | head -1 || echo 'No disponible')"
echo "  Helm: $(helm version --short 2>/dev/null || echo 'No disponible')"
echo "  Terraform: $(terraform version 2>/dev/null | head -1 || echo 'No disponible')"
echo "  make: $(make --version 2>/dev/null | head -1 || echo 'No disponible')"
echo "  git: $(git --version 2>/dev/null || echo 'No disponible')"
echo ""
echo "📂 Directorios creados:"
echo "  ~/.kube - Configuración de kubectl"
echo "  ~/.local/bin - Binarios locales"
echo ""
echo "🔧 Aliases configurados en ~/.bashrc"
echo "   k, kg, kd, kl, kx, kgp, kgn, kgs, kgd"
echo ""
echo "🚀 Ahora puedes ejecutar:"
echo "   make config   - Configurar automáticamente"
echo "   make deploy   - Desplegar el cluster"
echo "   make status   - Ver estado del cluster"
echo ""
echo "⚠️  IMPORTANTE: Cierra sesión y vuelve a entrar para que los aliases funcionen"
echo "   O ejecuta: source ~/.bashrc"