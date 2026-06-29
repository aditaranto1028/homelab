# How to install Prometheus

> [!NOTE]
> You **must** also have `argocd` installed in your cluster and the `argocd` CLI tool.

### Create the monitoring namespace

Create a namespace file with the contents below:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

To apply the namespace, run the command: `kubectl apply -f [path to namespace.yaml]`

### Create your `argocd` manifest

Create an `argocd` application file with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  destination:
    namespace: monitoring
    server: https://kubernetes.default.svc
  project: default
  sources:
    - repoURL: https://github.com/[username]/[repository].git # Replace
      targetRevision: HEAD
      ref: values
    - repoURL: https://prometheus-community.github.io/helm-charts/
      chart: prometheus
      targetRevision: 29.9.0 # Replace
      helm:
        valueFiles:
          - $values/[path to values.yaml] # Replace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Create your `helm` values file

At the path specified above, create a file with the contents below:

> [!NOTE]
> These were the values I saw from the [documentation](https://medium.com/hostspaceng/deploying-prometheus-and-grafana-monitoring-stack-to-kubernetes-the-gitops-way-using-argocd-1049704d0cbe) I found, but feel free to test different values.

```yaml
---
server:
  service:
    type: ClusterIP
```

### Install Prometheus

#### Log in to `argocd`

```bash
argocd login --core
```

#### Set the Kubernetes namespace to `argocd`

```bash
kubectl config set-context --current --namespace=argocd
```

#### Apply the application resources

```bash
kubectl apply -f [path to application.yaml]
```

#### Deploy Prometheus

```bash
argocd app sync prometheus
```

### Verify installation

Command: `kubectl get pods -n monitoring` Output:

```text
NAME                                                 READY   STATUS    RESTARTS   AGE
prometheus-alertmanager-0                            1/1     Running   0          27m
prometheus-kube-state-metrics-b5f898776-gschp        1/1     Running   0          27m
prometheus-prometheus-pushgateway-7984d68f7d-z5f4f   1/1     Running   0          27m
prometheus-server-6969f9bb94-2q7bs                   2/2     Running   0          27m
```

You can also use the `argocd` UI:
- Log in to the `argocd` UI
- Select Applications
- Find `prometheus`
- The card should look like the following:
![prometheus-tile](https://raw.githubusercontent.com/aditaranto1028/homelab/refs/heads/main/assets/images/prometheus-argocd-tile.png)
