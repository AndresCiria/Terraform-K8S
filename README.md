# Terraform-K8S

**Plataforma integral de automatización para Kubernetes con observabilidad, seguridad y CI/CD**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Descripción del Proyecto

Este repositorio contiene la automatización completa para desplegar un clúster Kubernetes con un stack integral de observabilidad, seguridad y CI/CD. El proyecto está diseñado para ser **reproducible, modular y fácil de usar**, permitiendo a cualquier desarrollador u operador levantar un entorno de pruebas o producción con un solo comando.

El stack incluye:

- **Orquestación**: Kubernetes (usando Kind para desarrollo local o kubeadm para entornos más robustos).
- **Observabilidad**: Stack PLG (Promtail, Loki, Grafana) + Prometheus y kube-state-metrics.
- **Seguridad**: Kyverno (políticas como código), Falco (detección de amenazas en runtime) y Trivy (escaneo de vulnerabilidades en el pipeline).
- **CI/CD**: Jenkins con pipelines declarativos que integran pruebas de seguridad y observabilidad.
- **Aplicaciones de prueba**: Nginx y una API Hello para validar el sistema de alertas.
- **Infraestructura subyacente**: Scripts para desplegar OpenStack (DevStack) sobre QEMU/KVM, creando las VMs que alojan el clúster.

Todo el proceso está orquestado mediante un `Makefile` y scripts en Bash, lo que reduce el despliegue a tres pasos: `make bootstrap`, `make config` y `make deploy`.

---

## Tabla de Contenidos

- [Requisitos del Sistema](#-requisitos-del-sistema)
- [Estructura del Repositorio](#-estructura-del-repositorio)
- [Despliegue Rápido](#-despliegue-rápido)
- [Despliegue Paso a Paso](#-despliegue-paso-a-paso)
- [Scripts Auxiliares](#-scripts-auxiliares)
- [Comandos Manuales de Referencia](#-comandos-manuales-de-referencia)
- [Contribuir](#-contribuir)
- [Licencia](#-licencia)

---

## Requisitos del Sistema

- **Máquina anfitriona**: Linux (Debian/Ubuntu recomendado) con 8 cores, 32 GB RAM y 500 GB SSD (para el entorno completo con OpenStack).
- **Software**: Docker, Kind, kubectl, Helm, Terraform (se instalan automáticamente con `make bootstrap`).
- **Red**: Acceso a Internet para descargar imágenes y charts.

Si solo deseas probar el clúster Kind sin OpenStack, los requisitos son menores (4 cores, 8 GB RAM).

---

## Estructura del Repositorio

El repositorio se organiza de forma modular para facilitar el mantenimiento y la evolución:
```
k8s-devsecops-platform/
├── Makefile                 # Orquestación principal (bootstrap, config, deploy, etc.)
├── README.md                # Esta documentación
├── deploy.sh                # Script de despliegue rápido
├── destroy.sh               # Script de destrucción de recursos
├── terraform/               # Definición de infraestructura con Terraform
│   ├── main.tf              # Cluster Kind, Helm releases (Loki, Prometheus, Grafana, Jenkins)
│   ├── alerts.tf            # Reglas de alerta en Grafana
│   ├── security.tf          # Kyverno, Falco y alertas de seguridad
│   ├── providers.tf         # Proveedores de Terraform
│   ├── variables.tf         # Variables configurables
│   ├── terraform.tfvars     # Valores concretos (IP, contraseñas, puertos)
│   └── outputs.tf           # Salidas del despliegue (URLs, credenciales)
├── helm/                    # Archivos de valores para Helm
│   ├── loki-values.yaml
│   ├── grafana-values.yaml
│   ├── apps-values.yaml
│   └── jenkins-values.yaml
├── scripts/                 # Scripts auxiliares
│   ├── Cluster-K8S/         # Scripts para el clúster Kubernetes
│   │   ├── bootstrap.sh     # Instalación de dependencias
│   │   ├── auto-config.sh   # Detección de IP y generación de configuración
│   │   ├── create-test-apps.sh
│   │   ├── install-loki-clean.sh
│   │   ├── setup-grafana-security.sh
│   │   ├── alert-generator.sh
│   │   └── test-deployment.sh
│   └── Openstack/           # Scripts para la infraestructura OpenStack
│       ├── install-devstack.sh
│       ├── create-k8s-infrastructure.sh
│       └── deploy-k8s-cluster.sh
└── test/                    # Pruebas de validación
    ├── api_rest.sh
    ├── log_generator.sh
    ├── log_simulator.sh
    ├── pod_crash.sh
    └── simulations.sh
```
---

## Despliegue Rápido

El flujo de trabajo principal está completamente automatizado. Solo necesitas clonar el repositorio y ejecutar:

```bash
git clone https://github.com/tu-usuario/k8s-devsecops-platform.git
cd k8s-devsecops-platform
make full-deploy   # Ejecuta bootstrap + config + deploy
```

Este comando:

1. **Instala todas las dependencias** (Docker, Kind, kubectl, Helm, Terraform, Trivy).
2. **Detecta automáticamente la IP** de tu máquina y genera la configuración adecuada.
3. **Crea el clúster Kind** con 1 nodo control-plane y 2 workers.
4. **Despliega el stack PLG** (Loki, Promtail, Prometheus, Grafana) con valores optimizados.
5. **Instala las aplicaciones de prueba** (Nginx y Hello API).
6. **Configura Jenkins** con NodePort y plugins básicos.
7. **Activa la seguridad** con Kyverno (políticas) y Falco (detección de amenazas).
8. **Configura todas las alertas** en Grafana (disponibilidad, rendimiento, logs, seguridad).

Al finalizar, verás un resumen con las URLs de acceso y las credenciales.

---

## Despliegue Paso a Paso (para depuración)

Si necesitas ejecutar los pasos de forma independiente (por ejemplo, si algún componente falla), puedes usar los siguientes comandos:

```bash
# 1. Instalar dependencias
make bootstrap

# 2. Generar configuración automática
make config

# 3. Desplegar todo
make deploy

# 4. Ver estado del clúster
make status

# 5. Ver logs de todos los pods
make logs

# 6. Ver URL y credenciales de Grafana
make grafana

# 7. Destruir todo
make destroy
```

---

## Scripts Auxiliares (Comandos Frecuentes Encapsulados)

Durante el desarrollo, es común necesitar reinstalar un componente específico o probar una configuración sin redeployar todo. Para eso, hemos encapsulado los comandos más habituales en scripts dentro de `scripts/Cluster-K8S/`:

| Script | Descripción |
|--------|-------------|
| `install-loki-clean.sh` | Reinstala Loki con una configuración limpia (útil si el chart falla). |
| `create-test-apps.sh` | Despliega solo las aplicaciones de prueba (Nginx y Hello API). |
| `setup-grafana-security.sh` | Configura las alertas de seguridad en Grafana sin tocar el resto. |
| `alert-generator.sh` | Genera logs de prueba para validar las alertas. |
| `test-deployment.sh` | Verifica el estado de todos los servicios (pods, servicios, endpoints). |

Estos scripts se pueden ejecutar manualmente si se necesita iterar rápidamente, sin tener que reescribir los comandos largos cada vez. Todos ellos utilizan el `kubeconfig` generado por Terraform.

Ejemplo de uso:

```bash
./scripts/Cluster-K8S/install-loki-clean.sh
./scripts/Cluster-K8S/alert-generator.sh
```

---

## Comandos Manuales de Referencia

Si prefieres ejecutar comandos directamente (por ejemplo, para port-forwarding o para eliminar un recurso), aquí tienes algunos de los más utilizados:

```bash
# Port-forward a Grafana
kubectl port-forward -n monitoring svc/grafana 30001:80 --address=0.0.0.0

# Port-forward a Jenkins (desplegado manualmente)
kubectl port-forward -n default svc/jenkins-manual 30005:8080 --address=0.0.0.0

# Eliminar el clúster Kind
kind delete cluster --name k8s-local

# Instalar Loki manualmente (con configuración específica)
helm install loki grafana/loki -n monitoring \
  --version 5.42.0 \
  --set deploymentMode=SingleBinary \
  --set singleBinary.replicas=1 \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set persistence.enabled=false \
  --set agent.enabled=false

# Desinstalar Jenkins
helm uninstall jenkins -n default
```

---

## Licencia

Este proyecto se distribuye bajo licencia MIT. Consulta el archivo `LICENSE` para más detalles.

---

