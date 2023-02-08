# Gitlab Custom Runner

Custom runner for Gitlab runner to use it with Kubernetes

## How it works

The new entrypoint will register the runner and change the configs if the runner executor is kubernets. This custom runner also has an option to use host aliases.

## Example deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubernetes-runner
  labels:
    app: kubernetes-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubernetes-runner
  template:
    metadata:
      labels:
        app: kubernetes-runner
    spec:
      hostAliases:
        - ip: "10.0.2.2"
          hostnames:
          - "gitlab.local"
      containers:
      - name: kubernetes-runner
        resources:
          limits:
            cpu: "0.3"
            memory: 100Mi
          requests:
            cpu: 200m
            memory: 100Mi
        image: docker.io/kamuri/custom-runner:0.0.6
        env:
        - name: GITLAB_HOST
          value: http://gitlab.local
        - name: REGISTRATION_TOKEN
          value: xxxxxxxxxxxxxxxxxxxx
        - name: EXECUTOR
          value: kubernetes
        - name: DESCRIPTION
          value: "image-build runner"
        - name: TAG
          value: "image-build"
        - name: NAMESPACE
          value: gitlab-runner
        - name: DNS_IP_LIST
          value: "10.0.2.209:gitlab.local"
        ports:
        - containerPort: 80
```