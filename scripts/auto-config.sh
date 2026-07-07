#!/bin/bash
# scripts/auto-config.sh - Genera terraform.tfvars automáticamente

echo "🔍 Detectando configuración automática..."

# Detectar IP
DETECTED_IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -z "$DETECTED_IP" ]; then
    DETECTED_IP="127.0.0.1"
fi

echo "📡 IP detectada: $DETECTED_IP"

# Verificar si existe terraform.tfvars
if [ -f "terraform/terraform.tfvars" ]; then
    echo "✅ terraform.tfvars ya existe"
    
    # Actualizar IP si es necesario
    CURRENT_IP=$(grep "api_server_address" terraform/terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
    if [ "$CURRENT_IP" != "$DETECTED_IP" ] && [ "$CURRENT_IP" != "127.0.0.1" ]; then
        read -p "La IP detectada ($DETECTED_IP) es diferente a la configurada ($CURRENT_IP). ¿Actualizar? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sed -i "s/api_server_address.*/api_server_address = \"$DETECTED_IP\"/" terraform/terraform.tfvars
            echo "✅ IP actualizada a $DETECTED_IP"
        fi
    fi
else
    echo "📝 Creando terraform.tfvars desde ejemplo..."
    if [ -f "terraform/terraform.tfvars.example" ]; then
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        # Actualizar IP
        sed -i "s/api_server_address.*/api_server_address = \"$DETECTED_IP\"/" terraform/terraform.tfvars
        echo "✅ terraform.tfvars creado con IP: $DETECTED_IP"
    else
        echo "❌ No se encuentra terraform.tfvars.example"
        exit 1
    fi
fi

echo ""
echo "📋 Configuración actual:"
cat terraform/terraform.tfvars