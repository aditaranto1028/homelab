# How to install Bitnami Sealed Secrets in Kubernetes

> [!NOTE]
> I use [Argo CD](https://github.com/aditaranto1028/homelab/blob/main/Documentation/argocd/argocd-install.md) to manage everything in the sealed-secrets namespace, but everything can be done manually.
>
> The documentation I used to install sealed-secrets can be found [here](https://oneuptime.com/blog/post/2026-01-17-helm-sealed-secrets-management/view).

### Create a values file

Create a file called `values.yaml` with the contents below:

```yaml
fullnameOverride: sealed-secrets-controller
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
containerSecurityContext:
  enabled: true
  runAsNonRoot: true
  runAsUser: 1001
podSecurityContext:
  enabled: true
  fsGroup: 65534
service:
  type: ClusterIP
  port: 8080
metrics:
  serviceMonitor:
    enabled: false
    namespace: monitoring
    interval: 30s
keyrenewperiod: "720h"
updateStatus: true
networkPolicy:
  enabled: true
rbac:
  create: true
  pspEnabled: false
serviceAccount:
  create: true
  name: sealed-secrets-controller
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8081"
nodeSelector: {}
tolerations: []
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - sealed-secrets
          topologyKey: kubernetes.io/hostname
```

### Create an application file

Create a file called `application.yaml` with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: sealed-secrets
      repoURL: https://bitnami.github.io/sealed-secrets
      targetRevision: 2.19.3 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/sealed-secrets/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      path: kubernetes/sealed-secrets/SealedSecrets # Replace
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
```

### Create the Argo CD application

Run the commands:

```bash
argocd login --core
kubectl apply -f [path to application.yaml]
argocd app sync sealed-secrets
```

### Create secrets

You can copy my template for creating secrets [here](https://github.com/aditaranto1028/homelab/blob/main/kubernetes/sealed-secrets/template-SealedSecret.yaml). The template contains a command at the top to seal the secrets.

#### Populate your secret template

Fill in the template values (specified by `<>`) with whatever you want. An example of a filled-in template is:

```yaml
# Encrypt your secrets with the following command:
# kubeseal --format yaml < template-SealedSecret.yaml > [secret]-sealed.yaml; rm template-SealedSecret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: demo-secret
  namespace: default
  labels:
    app.kubernetes.io/name: sealed-secrets
    app.kubernetes.io/managed-by: sealed-secrets
  annotations:
    sealedsecrets.bitnami.com/managed: "true"
type: Opaque
stringData:
  username: admin
  password: P@ssw0rd!
```

#### Seal your secret

Run the command:

```bash
kubeseal --format yaml < template-SealedSecret.yaml > [secret]-sealed.yaml; rm template-SealedSecret.yaml
```

Run the command:

```bash
cat [secret]-sealed.yaml
```

Expected output:

```yaml
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: demo-secret
  namespace: default
spec:
  encryptedData:
    password: AgBx0SyiTBcOKRn/4c2PNBjcphcO70HsZUEVWWbalkvHkQAMu4YJQQBqUdZhJRKy3MH0X8xCL6AidBd7t4iXlQQ7BvL3d5v8Mhhxz5gKiyBJyvAZq7kuXnlWYkNhVgCrYp8n3n+wl7sZdzXXQEkLvHWmvKYMi/OdnL/bVmwMbyzwDnyrZwJ0WMngEpPcw1Qt8gSPfXbEH1pXhumGCkEuC7RlPUhES3YPPosB9PNzwER/MOqo/k3jassAd7rWR5bwnBAupRzRcPmlzsXev4X+C9PcpoTtlAfNezfFEE/Yw5/Rh99IWSDfb3+LTTwC5aX3gII7nrC2PHFR9sH3F2KLNDUBR/sUP3xW6EIxOM80ZIyV9GoY7pRta9tlPl/GZWqZyEZTUqlTHBYDtxKxTH6/JW04aIbcEpm4MI61Bh1fbLilpD/llgjosDDrPlYqDEXMmZ0CjfYgePGsmXmb2qN4QbEmcYN/ACET3BzQTUFQgAsriO6ZGWi7SOTR+WbubCCHqEW4lxIEGoTyieK3qmsZlA9Hlx51+ZXJbwOfBoTniTIVUVmjHwjcFeGaYRIyNMBngu6a9Agf4ySNhssqN2LD52wxDqn0mU0kcdO0rbrI+DZIt8JB9bUr6Wsehd5QXV6RuukHm8X1hnNe0sCxrmON+tbkUUVkObs+BN8Q4cvKzS2Xfj6JZB8fxY9AmwgqaQlPQQ6VM5UFshXfO5M=
    username: AgCNU9inSQd2BOQSnG+LtHbWmaJHMNXDTyodP/LGEfsqT5r92FDBTe1cbRY7uxlTmQfZIKQvlqY2i9r0beFYsSB6dV8VFNakgYlwkuPmHQe3U/cSh4RVWzxALJGoTcTy7wKLe78iWDg21qtrx3kWnsrtjeorEN6dniTG/lUwMdkqBOUiCg6kEQsN8LU0gpTBNTAoHA7WdkD2Jlel+JUwEDhebaVjzS/BfQsu0V8yvmVQFkZyJd+wjSCv1JkmiITefHLNuAFLlL/KQic/jutJS8vC/LUJPm2LSwaRtApWl8SwUBq+iWqkYVfbVbU1VCfb5EAg8Jc7+nlEMrb78/lnriWgNLMKhmEbrdWo8/wvS6jOFuaLfhxRTMDsxsOrLbTH8KtUtz57LtALepnkvSkGfQWZELrTp8PzXQPo2YlbCxqjyTTd4vQF4WzF3wPyKU9dlAPhc/yGQ4zfB5GD5ePypYh892ZNwgHA7rNf0+tD3kGXW1YNDWawW66KM1f5hoSmeBlHfFmszRe4MEZTtnBY4a6tGNt4h5+AwEALLkxKfBO43hcuEKKrsyazPMO/cb7NRXD+KoqBKg+8l2uOa1rLU7s4yMRS5A6Foe+yROesmmBfIvuShi/zxAURRY8PoVlHf7xjhoUvMp6A0q4G+cdvKBK4saVn3mZMP0bxOorf44xiVNsYGSEjKjOpyRtwX8lwdvOloT0RvA==
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/managed: "true"
      labels:
        app.kubernetes.io/managed-by: sealed-secrets
        app.kubernetes.io/name: sealed-secrets
      name: demo-secret
      namespace: default
    type: Opaque
```

#### Apply your sealed secrets

##### Argo CD

Commit your sealed secret to GitHub, specifically a directory that Argo CD is monitoring.

Copy the directory structure from the application file above or modify the source to reflect your own hierarchy.

##### Manual

You can apply the sealed secret into your cluster for the controller to decrypt by doing:

```bash
kubectl apply -f [secret]-sealed.yaml
```

#### Verify your secret

Run the command:

```bash
kubectl get secret [secret name] -n [namespace] -o yaml
```

Expected output:

```yaml
apiVersion: v1
data:
  password: UEBzc3cwcmQh
  username: YWRtaW4=
kind: Secret
metadata:
  annotations:
    sealedsecrets.bitnami.com/managed: "true"
  creationTimestamp: "2026-08-21T02:49:24Z"
  labels:
    app.kubernetes.io/managed-by: sealed-secrets
    app.kubernetes.io/name: sealed-secrets
  name: demo-secret
  namespace: default
  ownerReferences:
  - apiVersion: bitnami.com/v1alpha1
    controller: true
    kind: SealedSecret
    name: demo-secret
    uid: 1c2b36be-da4f-470d-88df-eb1f6b176647
  resourceVersion: "5450366"
  uid: e0c37f5c-014c-4ea0-a2dd-fa9894a25787
type: Opaque
```

> [!NOTE]
> The username and password are both base64 encoded and can be decoded with `base64 --decode`

##### Fetching secret values

You can run the following command to fetch the exact value of a secret:

```bash
kubectl get secret demo-secret -n default -o json | jq -r '.data["password"]' | base64 --decode
```

Output:

```text
P@ssw0rd!
```
