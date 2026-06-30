# How to install Grafana

> [!NOTE]
> You **must** also have `argocd` installed in your cluster and the `argocd` CLI tool.
>
> If you followed my [guide](https://github.com/aditaranto1028/homelab/blob/main/Documentation/prometheus/prometheus-install.md) on setting up Prometheus, you do not need to make the namespace.

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
  name: grafana
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
  - repoURL: https://grafana.github.io/helm-charts
    chart: grafana
    targetRevision: 8.3.0 # Replace
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
service:
  type: ClusterIP
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local
        access: proxy
        isDefault: true
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
      - name: "default"
        orgId: 1
        folder: ""
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
dashboards:
  default:
    kubernetes:
      gnetId: 10000
      revision: 1
      datasource: Prometheus
```

### Install Grafana

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

#### Deploy Grafana

```bash
argocd app sync grafana
```

### Verify installation

Command: `kubectl get pods -n monitoring` Output:

```text
NAME                                                 READY   STATUS    RESTARTS   AGE
grafana-9f746bfd-59gvl                               1/1     Running   0          22h
prometheus-alertmanager-0                            1/1     Running   0          46h
prometheus-kube-state-metrics-b5f898776-gschp        1/1     Running   0          46h
prometheus-prometheus-node-exporter-dvrmw            1/1     Running   0          45h
prometheus-prometheus-node-exporter-lhszq            1/1     Running   0          45h
prometheus-prometheus-pushgateway-7984d68f7d-z5f4f   1/1     Running   0          46h
prometheus-server-6969f9bb94-2q7bs                   2/2     Running   0          46h
```

You can also use the `argocd` UI:
- Log in to the `argocd` UI
- Select Applications
- Find `grafana`
- The card should look like the following:
![grafana-tile](https://raw.githubusercontent.com/aditaranto1028/homelab/refs/heads/main/assets/images/grafana-argocd-tile.png)

### Access the Grafana UI

#### Get the admin password

```bash
kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

#### Port forward the UI

```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```

#### Change the admin password

- Navigate to http://localhost:3000
- Log in with the credentials:
  - Username: admin
  - Password: [The string from "Get the admin password"]
- Click the profile icon in the top-right corner
- Select `Change password`
