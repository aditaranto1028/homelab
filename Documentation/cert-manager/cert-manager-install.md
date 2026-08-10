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
  --from-literal=token='[API token]' \
  -n cert-manager
```

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
