cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-test
  namespace: default
  labels:
    app: crash-test
    type: test
spec:
  containers:
  - name: crash
    image: busybox:latest
    command:
      - sh
      - -c
      - "echo 'Starting...' && sleep 5 && echo 'ERROR: Simulated crash' && exit 1"
  restartPolicy: Always
EOF