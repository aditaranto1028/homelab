# How to install Victoria Metrics and Grafana with the Victoria-Metrics-k8s-Stack Helm Chart

> [!NOTE]
> Prerequisites:
> - MetalLB (only if you want a load balancer IP)
> - Longhorn (or equivalent)
> - Argo CD

### Create the namespace

Create a file called `namespace.yaml` with the contents below:

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

Run the command:

```bash
kubectl apply -f [path to namespace.yaml]
```

### Create the values file

Create a file called `values.yaml` with the contents below:

```yaml
victoria-metrics-operator:
  admissionWebhooks:
    certManager:
      enabled: false
grafana:
  enabled: true
  persistence:
    enabled: true
    type: pvc
    storageClassName: longhorn # Replace if you do not use longhorn
    accessModes:
      - ReadWriteOnce
    size: 2Gi # Replace
  service:
    type: LoadBalancer
    loadBalancerIP: "x.x.x.x" # Replace
vmsingle:
  enabled: false
vmcluster:
  enabled: true
  spec:
    retentionPeriod: "12" # Replace
    vmstorage:
      replicaCount: 2
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: longhorn # Replace if you do not use longhorn
            resources:
              requests:
                storage: 20Gi # Replace
    vminsert:
      replicaCount: 2
    vmselect:
      replicaCount: 2
      serviceSpec:
        spec:
          type: LoadBalancer
          loadBalancerIP: "x.x.x.y"
```

Alternatively, if you want to always port-forward your pod or use traefik, your `values.yaml` can look like this:

```yaml
victoria-metrics-operator:
  admissionWebhooks:
    certManager:
      enabled: false
grafana:
  enabled: true
  persistence:
    enabled: true
    type: pvc
    storageClassName: longhorn
    accessModes:
      - ReadWriteOnce
    size: 2Gi
vmsingle:
  enabled: false
vmcluster:
  enabled: true
  spec:
    retentionPeriod: "12"
    vmstorage:
      replicaCount: 2
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: longhorn
            resources:
              requests:
                storage: 20Gi
    vminsert:
      replicaCount: 2
    vmselect:
      replicaCount: 2
```

### Create the application file

Create a file called `application.yaml` with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vmks
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: ""
      kind: Secret
      name: vmks-victoria-metrics-operator-validation
      namespace: monitoring
      jsonPointers:
        - /data
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      name: vmks-victoria-metrics-operator-admission
      jqPathExpressions:
      - '.webhooks[]?.clientConfig.caBundle'
    - kind: "Secret"
      jsonPointers:
        - /data/admin-password
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/template/metadata/annotations/checksum~1secret
  project: default
  sources:
    - chart: victoria-metrics-k8s-stack
      repoURL: https://victoriametrics.github.io/helm-charts/
      targetRevision: 0.87.0 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/victoria-metrics-k8s-stack/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
```

Run the command:

```bash
argocd app sync vmks
```

### Verification

The following are some verification steps:
- Run the command: `kubectl get app -n argocd`
- Expected output:
```text
 NAME       SYNC STATUS   HEALTH STATUS
vmks       Synced        Healthy
```
- You can also verify that the persistent volumes were created in Longhorn

### Access the UI

#### ClusterIP (my current choice)

When the services have ClusterIPs, you can use an ingress controller like Traefik or port-forward the service every time.

> [!NOTE]
> Prerequisites:
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md)
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md)
> - A registered domain (i.e. ditaranto-homelab.com)

Follow my [documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) on how to set up the ingress route, middleware, certificate, and published application route.

Grafana can use a simple ingress route and certificate, while Victoria Metrics UI also requires a middleware to redirect `/` to `select/<accountID>/vmui/`.

An example ingress route + middleware for Victoria Metrics UI would be:

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: vmui-ingressroute
  namespace: monitoring
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`vmui.ditaranto-homelab.com`) && Path(`/`)
      kind: Rule
      middlewares:
        - name: vmui-redirect
      services:
        - name: vmselect-vmks-victoria-metrics-k8s-stack
          port: 8481
    - match: Host(`vmui.ditaranto-homelab.com`) # Replace
      kind: Rule
      services:
        - name: vmselect-vmks-victoria-metrics-k8s-stack
          port: 8481
  tls:
    secretName: vmui-certificate-secret
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: vmui-redirect
  namespace: monitoring
spec:
  redirectRegex:
    regex: "^https://vmui\\.ditaranto-homelab\\.com/?$" # Replace
    replacement: "https://vmui.ditaranto-homelab.com/select/0/vmui" # Replace
    permanent: true
```

#### LoadBalancerIP

##### Grafana

Open a web browser and navigate to "http://[grafana IP / hostname]" and sign in with the following credentials:
- Username: admin
- Password: [Run the command: `kubectl get secrets vmks-grafana -o json -n monitoring | jq -r '.data["admin-password"]' | base64 --decode`]

##### VMSelect

Open a web browser and navigate to "http://[VMSelect IP / hostname]:8481/select/0/vmui"
