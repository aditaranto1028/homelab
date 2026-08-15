# How to install Cert-Manager in Kubernetes

### Set up your Cloudflare API token

Navigate to https://dash.cloudflare.com/ and do the following:
- In the top-right corner, select the profile icon
- Select `Profile`
- Select `API Tokens`
- Select `+ Create Token`
- Find `Edit zone DNS` and select `Use template`
- Under `Zone Resources`, set the zone to be your domain

Run the command:

```bash
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token='[API token]' \
  -n cert-manager
```

### Create a values file

Create a file called `values.yaml` with the contents:

```yaml
namespace: "cert-manager"
crds:
  enabled: true
extraArgs:
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
```

### Create a cluster issuer file

Create a file called `cluster-issuer.yaml` with the contents:

```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-clusterissuer
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  acme:
    email: [email] # Replace
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudflare-clusterissuer-account-key
    solvers:
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
```

### Create an application file

#### File contents

Create a file called `application.yaml` with the contents:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
  project: default
  sources:
    - chart: cert-manager
      repoURL: https://charts.jetstack.io
      targetRevision: v1.16.2 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/cert-manager/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      path: kubernetes/cert-manager/config # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      path: kubernetes/cert-manager/certificates # Replace
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
```

#### Create and sync the application

Run the command:

```bash
argocd app sync cert-manager
```

Alternatively, you can sync the application through the Argo CD UI.

### Verification

#### Pods

Run the command:

```bash
kubectl get pods -n cert-manager
```

Expected output:

```text
NAME                                          READY   STATUS    RESTARTS   AGE
pod/cert-manager-65b98f8bb5-pcwkd             1/1     Running   0          2m25s
pod/cert-manager-cainjector-df474c4b7-42ls7   1/1     Running   0          2m25s
pod/cert-manager-webhook-54b9fbfd68-g2b9z     1/1     Running   0          2m25s
```

#### CRDs

Run the command:

```bash
kubectl get crd | grep cert-manager
```

Expected output:

```text
anthony@DESKTOP-9PQ8GF3:~/homelab/argocd/cert-manager$ kubectl get crd | grep cert-manager
certificaterequests.cert-manager.io                   2026-08-09T23:42:42Z
certificates.cert-manager.io                          2026-08-09T23:42:42Z
challenges.acme.cert-manager.io                       2026-08-09T23:42:42Z
clusterissuers.cert-manager.io                        2026-08-09T23:42:42Z
issuers.cert-manager.io                               2026-08-09T23:42:42Z
orders.acme.cert-manager.io                           2026-08-09T23:42:42Z
```

#### Cluster issuer

Run the command:

```bash
kubectl get clusterissuer cloudflare-clusterissuer -o yaml | grep -E "message|reason|status"
```

Expected output:

```text
status:
    message: The ACME account was registered with the ACME server
    reason: ACMEAccountRegistered
    status: "True"
```
