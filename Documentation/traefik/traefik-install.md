# How to install Traefik in Kubernetes

> [!NOTE]
> Prerequisites:
> - DNS setup so you can put your hostname in the values file
> - I had [cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md) and a [Cloudflare](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cloudflare/cloudflare-install.md) tunnel for DNS and certificates

### Cloudflare setup

Navigate to https://one.dash.cloudflare.com/ and do the following:

- Click on `Networks`
- Click on `Tunnels & Mesh`
- Click on your tunnel
  - If the tunnel hasn't been made, you can follow my documentation [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cloudflare/cloudflare-install.md)
- Click on `Published application routes`
- Click on `+ Add a published application route`
- Make the subdomain whatever you want (i.e. traefik)
- Make the domain your specified domain
- Under service, set the type to `HTTPS`
- Under URL, set it to `<service>.<namespace>.svc.cluster.local` (i.e `traefik.traefik.svc.cluster.local`)
- Click on `Origin request and connection settings`
- Click on `TLS`
- Make sure No TLS Verify is checked

### Create the dashboard authentication secret

#### Generate your password

Run the command:

```bash
htpasswd -nb [username] '[password]'
```

Example:

```text
htpasswd -nb admin 'password'
admin:$apr1$c85VBtWB$5/6BWGxw56Q6BwPdNAfYH0
```

#### Create the Kubernetes secret

Run the command:

```bash
kubectl create secret generic traefik-dashboard-auth \
  --from-literal=users='[output from previous command]' \
  -n traefik
```

### Create a values file

Create a file called `values.yaml` with the contents below:

```yaml
ports:
  web:
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
ingressRoute:
  dashboard:
    enabled: true
    entryPoints: [web, websecure]
    matchRule: Host(`traefik.ditaranto-homelab.com`) # Replace
    middlewares:
      - name: dashboard-auth
        namespace: traefik

extraObjects:
  - apiVersion: traefik.io/v1alpha1
    kind: Middleware
    metadata:
      name: dashboard-auth
      namespace: traefik
    spec:
      basicAuth:
        secret: traefik-dashboard-auth
```

### Create an application file

Create a file called `application.yaml` with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: traefik
      repoURL: https://traefik.github.io/charts
      targetRevision: 41.2.0
      helm:
        valueFiles:
          - $values/kubernetes/traefik/values.yaml
    - repoURL: https://github.com/aditaranto1028/homelab.git
      targetRevision: HEAD
      ref: values
    - repoURL: https://github.com/aditaranto1028/homelab.git
      targetRevision: HEAD
      path: kubernetes/traefik/ingressRoutes
  destination:
    server: https://kubernetes.default.svc
    namespace: traefik
```

Run the commands:

```bash
argocd login --core
kubectl config set-context --current --namespace=argocd
argocd app sync traefik
```

### Verification

Navigate to https://traefik.ditaranto-homelab.com/ and you should be prompted for a password. After you authenticate, you should land on the dashboard page.

Run the command:

```bash
kubectl get all -n traefik
```

Expected output:

```text
NAME                           READY   STATUS    RESTARTS      AGE
pod/traefik-85d9546c78-hhnxg   1/1     Running   8 (72m ago)   10h
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/traefik   LoadBalancer   10.100.245.136   192.168.1.2   80:32596/TCP,443:31224/TCP   21h
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/traefik   1/1     1            1           21h
NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/traefik-85d9546c78   1         1         1       21h
```

### Configure HTTPS and ingressRoutes for other services

You can follow [my documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) to set up ingressRoute resources and certificates for whatever services you want.
