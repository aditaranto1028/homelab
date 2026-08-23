# How to install OpenProject in Kubernetes

> [!NOTE]
> Prerequisites:
> - Some way to create secrets
> - Some way to create ingress routes
> - Some way to create certificates
>
> I use the following:
> - [Bitnami Sealed Secrets](https://github.com/aditaranto1028/homelab/blob/main/Documentation/sealed-secrets/sealed-secrets-install.md)
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md)
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md)
> - [Cloudflare tunnel](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cloudflare/cloudflare-install.md)

### Create the Cloudflare DNS published application route

Follow my [documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) on how to set up the published application route. You just need to follow the `Cloudflare published application route` section. There are other sections in the documentation that may help you later in this guide.

### Create the certificate

If you are using cert-manager like me, create a certificate file with the contents below:

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: openproject-certificate
  namespace: openproject
spec:
  secretName: openproject-certificate-secret
  issuerRef:
    name: cloudflare-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - openproject.ditaranto-homelab.com # Replace
```

You can either run `kubectl apply -f [certificate file].yaml` or have Argo CD apply the file.

### Create the ingress route

If you are using Traefik like me, create an ingress route file with the contents below:

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: openproject-ingressroute
  namespace: openproject
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`openproject.ditaranto-homelab.com`) # Replace
      kind: Rule
      services:
        - name: openproject
          port: 8080
  tls:
    secretName: openproject-certificate-secret
```

You can either run `kubectl apply -f [ingress route file].yaml` or have Argo CD apply the file.

### Create the secret

> [!NOTE]
> - The only secret you need to make is called `openproject-postgresql` with it having two key value pairs
> - The key-value pairs are `password` and `postgres-password`
> - These passwords can be generated using `openssl rand -hex 24`

If you are using Sealed Secrets like me you can follow my documentation on how to make sealed-secrets found [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/sealed-secrets/sealed-secrets-install.md).

The output of the sealed-secret should be the following:

```yaml
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: openproject-postgresql
  namespace: openproject
spec:
  encryptedData:
    password: AgCUwg5UHy+YwDZtJqUWK/YxPsalkfagvgb3i4mSsF34OHApyY8Q4cO1zC6GH0nQsMfmwKSUDwp2YeasHx03/wSuIuQUtizcePuZZ2fZv9pyfsNTk8jCGAo1VPK3rp9YuUmzj16w5MeO5nR82f/90kRzWz25cN/Hq2XXViQIPMxhn7IkoDfPROq1Y0D8JRj5uQntS/+jqb6Hk1yW5aYTgPTPZHrejm12ujUNZ6PUtbSqhwKghw+hg5d/5IsPwCdu8XLJ7/x2/djkwQoBevoy8AhLeYTsqvrAt0Cksw7sb2Qvi8zCTIvlor5DvyMvVjwvUjjNUSSax2LK89ZZnT4+Idt3qw9NVDfrYSK3GPp0BNndHaTScyqnjlRkPw9tuSWyacV2XrOiE+Rbz1e5Q8z6GQbqxAmdAGrs6hvScW2SJKKJCx9HbnTGEf4v2KnUUBGHsPVyk6SXWjbL9SQgV1rZqi0OCGwCZLfblVXH7srdIWiUsgo0tO7OT0TUx/Vtvns7C1ZMLs9+coHBiP7iN9mxZs17FqP8kx3PL5Tw0aQlnnIMxz3Wdbv/a10i9b2ILuLcw9shNeUbQscOJxTFFkZNkGYqMvlR7i0Tt7tjpJm9xi5sDRmyCZa2Zqw0w2Qon+ipii/QKxk8KJuCyXilez4xb+YYvtMfU1gXiv6ZUWhyiDF3v1uUoiMI9fsmX+AgN3h2QG4cXW3Kp0+dYS5rLGDVl8+Ugcct+2sumu+anc49hBjvRUspM5/lP5vOEDgvVhJrsJM=
    postgres-password: AgCVvoxQlPzYPKGPjMcd5DVJs3zj95xaPksEMu9TXzbJXasEVrNXqd1lmgLrSM34GK0bO7Qir58LF+vxamgnVkJP5Ud//CBS79dzexr1lLgRytVUbM814okFdptGKJIhtB5M9GOhv/0vST5Mx98idbB9oJmZs47Oy82sBM9nKc5EqQJBx9H+A0BoCwUwjuj/gJh58KANeks+hvDyLrgWsiRh4jTOClJ5YSFyoFHiBBHAt5uJGNNJydDxG2tC9+9lch9y/LGuV6vAJ9nxnCJU9YD2k036XrBzMd+X2tWPClBdKf9hOALxEoBLUpcmGlkcAXUs0NEqSFANQBhwjydR3FBIzjeFRk4zqDxNmhV2UqOX7tSo4yNa2lUfXEzsjuzYZE4b7NsKZkOOdROGZc6Gl+Xczb6mOO9v2a3bc2bsobvdnlSm1+S7mJZqxD3rsxXDjH7avwJfdcT9OHE547vfYlHlK0UaCZLXS+ZC1rSOH45PzNgSsdt9J4m6JCVCL/gxY9rEk808sjRzOFG2Z9pOHGQ0CJMdU20WkiSAG7QdjmTW02wRAwmQ+xxKWxBH+XfMbP2EerBmpre8BKdpOFNb4/4sJZpDwUieVek/NMGwkd+rn4b0nu6W03E47FldRFOjrWowNq+FLZLSJXZc4YFzisSwy8RS8IrGEm7qIcE2VCq0V6OegAMQensCnTF2bjQ/ZvHKrAlmJehvXgE9CvFblEyLLR9X/VqwW+4rGd4yJbdNYUiAE4gXdfsKj0skcx2kfVE=
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/managed: "true"
      labels:
        app.kubernetes.io/managed-by: sealed-secrets
        app.kubernetes.io/name: sealed-secrets
      name: openproject-postgresql
      namespace: openproject
    type: Opaque
```

You can either run `kubectl apply -f [sealed secret file].yaml` or have Argo CD apply the file.

### Create the values file

Create a file called `values.yaml` with the following contents:

```yaml
ingress:
  ingressClassName: "traefik"
  annotations:
    cert-manager.io/cluster-issuer: "cloudflare-clusterissuer"
  host: "openproject.ditaranto-homelab.com" # Replace
  tls:
    secretName: "openproject-certificate"
image:
  imagePullPolicy: "IfNotPresent"
  tag: "16.5-slim" # Replace
memcached:
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "250m"
openproject:
  admin_user:
    password: 'admin'
    name: 'Anthony DiTaranto' # Replace
    mail: 'aditaranto1028@gmail.com' # Replace
persistence:
  size: "15Gi"
  storageClassName: "longhorn"
postgresql:
  auth:
    existingSecret: "openproject-postgresql"
    secretKeys:
      adminPasswordKey: "postgres-password"
      userPasswordKey: "password"
  primary:
    persistence:
      enabled: true
      size: "8Gi"
      storageClass: "longhorn"
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "1"
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1500m"
```

### Create the application file

Create a file called `application.yaml` with the following contents:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openproject
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: openproject
      repoURL: https://charts.openproject.org
      targetRevision: 13.10.2 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/openproject/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: openproject
```

Run the commands:

```bash
argocd login --core
kubectl config set-context --current --namespace=argocd
argocd app sync cert-manager
argocd app sync traefik
argocd app sync sealed-secrets
argocd app sync openproject
```

### Verification

Run the command:

```bash
kubectl get all -n openproject
```

Expected output:

```text
NAME                                             READY   STATUS      RESTARTS   AGE
pod/openproject-hocuspocus-644c58d4bb-jwjd2      1/1     Running     0          83m
pod/openproject-memcached-6468cdddcb-9wbff       1/1     Running     0          83m
pod/openproject-postgresql-0                     1/1     Running     0          83m
pod/openproject-seeder-1-7jz25                   0/1     Completed   0          83m
pod/openproject-web-67d69c4dbf-m9bnc             1/1     Running     0          83m
pod/openproject-worker-default-d8cb567c7-t9mbm   1/1     Running     0          83m

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/openproject                 ClusterIP   10.105.35.140    <none>        8080/TCP    83m
service/openproject-hocuspocus      ClusterIP   10.101.194.118   <none>        1234/TCP    83m
service/openproject-memcached       ClusterIP   10.98.52.72      <none>        11211/TCP   83m
service/openproject-postgresql      ClusterIP   10.104.151.225   <none>        5432/TCP    83m
service/openproject-postgresql-hl   ClusterIP   None             <none>        5432/TCP    83m

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/openproject-cron             0/0     0            0           83m
deployment.apps/openproject-hocuspocus       1/1     1            1           83m
deployment.apps/openproject-memcached        1/1     1            1           83m
deployment.apps/openproject-web              1/1     1            1           83m
deployment.apps/openproject-worker-default   1/1     1            1           83m

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/openproject-cron-75d5bf5775            0         0         0       83m
replicaset.apps/openproject-hocuspocus-644c58d4bb      1         1         1       83m
replicaset.apps/openproject-memcached-6468cdddcb       1         1         1       83m
replicaset.apps/openproject-web-67d69c4dbf             1         1         1       83m
replicaset.apps/openproject-worker-default-d8cb567c7   1         1         1       83m

NAME                                      READY   AGE
statefulset.apps/openproject-postgresql   1/1     83m

NAME                             STATUS     COMPLETIONS   DURATION   AGE
job.batch/openproject-seeder-1   Complete   1/1           51m        83m
```
