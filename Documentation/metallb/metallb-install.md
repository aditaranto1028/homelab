# How to install MetalLB

### Create the namespace

Create a file called `namespace.yaml` with the following contents:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: metallb
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

Run the following command to create the namespace:

```bash
kubectl apply -f [path to namespace.yaml]
```

### Create your values file

> [!WARNING]
> The value set below does not need to be false, but it does need to be specified in the values file.

Create a file called `values.yaml` with the following contents:

```yaml
---
frr-k8s:
  prometheus:
    serviceMonitor:
      enabled: false
```

### Create your IP address pool and L2 advertisement

> [!NOTE]
> The files below should be in the same directory which will be specified as the third source in the Argo CD application file.

#### IP address pool

```yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-static # Replace
  namespace: metallb
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  addresses:
  - x.x.x.x-y.y.y.y # Replace
```

#### L2 advertisement

```yaml
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2adv # Replace
  namespace: metallb
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  ipAddressPools:
    - homelab-static # Replace
```

### Create your application file

Create a file called `application.yaml` with the following contents:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metallb
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: metallb
      repoURL: https://metallb.github.io/metallb
      targetRevision: 0.16.0 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/metallb/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      path: kubernetes/metallb/config # Replace
  destination:
    server: https://kubernetes.default.svc
    namespace: metallb
```

Apply the application resource:

```bash
kubectl apply -f [path to application.yaml]
```

#### Deploy MetalLB

```bash
argocd app sync metallb
```

### Verify installation

Command: `kubectl get pods -n metallb`

Output:

```text
NAME                                             READY   STATUS    RESTARTS   AGE
metallb-controller-6796564f7f-ks6sc              1/1     Running   0          7m42s
metallb-frr-k8s-92gfd                            5/5     Running   0          7m42s
metallb-frr-k8s-h4vfn                            5/5     Running   0          7m42s
metallb-frr-k8s-statuscleaner-75b695f48d-wgjt4   1/1     Running   0          7m42s
metallb-speaker-7l4bg                            1/1     Running   0          7m42s
metallb-speaker-llgnl                            1/1     Running   0          7m42s
```
