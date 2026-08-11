cd ~/Terraform-k8s/terraform
export KUBECONFIG=$(pwd)/kubeconfig

kubectl scale deployment -n security kyverno-admission-controller --replicas=0
kubectl scale deployment -n security kyverno-background-controller --replicas=0
kubectl scale deployment -n security kyverno-cleanup-controller --replicas=0
kubectl scale deployment -n security kyverno-reports-controller --replicas=0

helm uninstall jenkins -n default 2>/dev/null || true
kubectl delete statefulset jenkins -n default 2>/dev/null || true
kubectl delete pod jenkins-0 -n default 2>/dev/null || true
kubectl delete pvc jenkins -n default 2>/dev/null || true

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts-jdk17
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 50000
          name: agent
        env:
        - name: JENKINS_OPTS
          value: "--prefix=/jenkins"
        - name: JAVA_OPTS
          value: "-Xmx512m -Dhudson.slaves.NodeProvisioner.initialDelay=0"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        securityContext:
          runAsUser: 1000
          runAsNonRoot: true
          allowPrivilegeEscalation: false
      volumes:
      - name: jenkins-home
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: default
spec:
  type: NodePort
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30005
  - name: agent
    port: 50000
    targetPort: 50000
  selector:
    app: jenkins
EOF

echo "Esperando 30 segundos..."
sleep 30

kubectl get pods -n default | grep jenkins
kubectl get svc -n default | grep jenkins

kubectl scale deployment -n security kyverno-admission-controller --replicas=1
kubectl scale deployment -n security kyverno-background-controller --replicas=1
kubectl scale deployment -n security kyverno-cleanup-controller --replicas=1
kubectl scale deployment -n security kyverno-reports-controller --replicas=1

JENKINS_PASS=$(kubectl exec -n default deployment/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
echo ""
echo "Jenkins URL: http://192.168.122.53:30005/jenkins"
echo "Usuario: admin"
echo "Contraseña inicial: $JENKINS_PASS"