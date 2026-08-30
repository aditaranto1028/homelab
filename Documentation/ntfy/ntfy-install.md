# How to install ntfy

> [!NOTE]
> I use Cloudflare tunneling, cert-manager, and Traefik, but this can be modified to fit your environment.

### Create a values file

Create a file called `values.yaml` with the contents below:

```yaml
ntfy:
  baseUrl: "https://ntfy.ditaranto-homelab.com" # Replace
  authDefaultAccess: "deny-all"
persistence:
  storageClass: "longhorn"
ingress:
  enabled: false
```

### Create an ingress route and certificate

You can use my documentation found [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) to create the ingress route and certificate.

Ingress route template:

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: ntfy-ingressroute
  namespace: ntfy
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`ntfy.ditaranto-homelab.com`) # Replace
      kind: Rule
      services:
        - name: ntfy-ntfy
          port: 80
  tls:
    secretName: ntfy-certificate-secret
```

Certificate template:

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ntfy-certificate
  namespace: ntfy
spec:
  secretName: ntfy-certificate-secret
  issuerRef:
    name: cloudflare-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - ntfy.ditaranto-homelab.com # Replace
```

I use Argo CD to apply my resources but you can just use the following commands:

```bash
kubectl apply -f [path to certificate]
kubectl apply -f [path to ingress route]
```

Follow my [documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) on how to set up the published application route. You just need to follow the `Cloudflare published application route` section. There are other sections in the documentation that may help you later in this guide.

### Create an application file

Create a file called `application.yaml` with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ntfy
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: ntfy
      repoURL: https://repo.helmforge.dev
      targetRevision: 1.2.1 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/ntfy/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: ntfy
```

Run the following commands:

```bash
argocd login --core
kubectl config set-context --current --namespace=argocd
argocd app sync ntfy
```

### Verification

Run the command:

```bash
kubectl get all -n ntfy
```

Expected output:

```text
NAME                             READY   STATUS    RESTARTS   AGE
pod/ntfy-ntfy-5d87779476-ldc68   1/1     Running   0          104s

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/ntfy-ntfy   ClusterIP   10.110.89.210   <none>        80/TCP    104s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ntfy-ntfy   1/1     1            1           104s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/ntfy-ntfy-5d87779476   1         1         1       104s
```

### Usage

#### Create a user and topic

Create a user using the following command:

```bash
kubectl exec -it -n ntfy deploy/ntfy-ntfy -- ntfy user add [username]
```

Give the user access to the topic with the following command:

```bash
kubectl exec -n ntfy deploy/ntfy-ntfy -- ntfy access [username] [topic] read-write
```

Confirm access with the following command:

```bash
kubectl exec -n ntfy deploy/ntfy-ntfy -- ntfy user list
```

Expected output:

```text
user anthony (role: user, tier: none)
- read-write access to topic homelab-test
```

#### Subscribe to the topic

I will be giving the instructions on my phone, but they should be universal:
- Download the `ntfy` app and launch it
- Click `Settings`
- Click `Default server` and enter the URL
  - In my case it is `https://ntfy.ditaranto-homelab.com`
- Click `Notifications`
- Click `+` in the top-right corner
- Enter the exact topic name
- Click `Use another server` and enter the server URL
- Enter the credentials

#### Test the topic notifications

Send a test message with the following command:

```bash
curl -u [username]:[password] -d "Test message" [server URL]/[topic name]
```

#### Modify the user's access rights (optional)

If you want the user to be read only instead of read-write, run the following command:

```bash
kubectl exec -n ntfy deploy/ntfy-ntfy -- ntfy access [username] [topic] read
```
