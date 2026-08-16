# How to set up ingress routes with Traefik in Kubernetes with TLS

> [!NOTE]
> Prerequisites:
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md)
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md)
> - [Cloudflare tunnel](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cloudflare/cloudflare-install.md)
>
> These services are not fully needed to set up ingress routes and SSL, but many of the secrets that are needed for this documentation are created while I deployed the services above.

### Test service

I have created a test-nginx deployment that I will use to set up the ingressRoute and certificate. Please note that you can do this with your services as well.

```text
NAME                              READY   STATUS    RESTARTS   AGE
pod/test-nginx-7ff5cd7655-5mhjc   1/1     Running   0          9s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/test-nginx   ClusterIP   10.98.64.102   <none>        80/TCP    9s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/test-nginx   1/1     1            1           9s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/test-nginx-7ff5cd7655   1         1         1       9s
```

### Cloudflare published application route

Navigate to https://one.dash.cloudflare.com/ and do the following:
- Click on `Networks`
- Click on `Tunnels & Mesh`
- Click on your tunnel which should have a healthy status
- Click on `Published application routes`
- Click on `+ Add a published application route`
- Enter a meaningful subdomain
- Click on the Domain drop down and select yours
- Click on the Type drop down and select `https`
- Enter the internal cluster URL for traefik
  - Mine was `traefik.traefik.svc.cluster.local`
- Click on `Origin request and connection settings`
- Click on `TLS`
- In `Origin Server Name`, enter the full URL of the service you are going to make the `ingressRoute` for
  - For example, if you are making the published application route for test-nginx.example.com, that is what you would put
- Click `Save`

### Create the certificate

> [!WARNING]
> If you have Argo CD set up like me and notice that the resources are not being applied, do not forget to sync the application.

You can find a certificate template [here](https://github.com/aditaranto1028/homelab/blob/main/kubernetes/cert-manager/template-certificate.yaml).

Below is the filled in template for my `test-nginx` deployment:

```yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-nginx-certificate
  namespace: test-nginx
spec:
  secretName: test-nginx-certificate-secret
  issuerRef:
    name: cloudflare-clusterissuer
    kind: ClusterIssuer
  dnsNames:
    - test-nginx.ditaranto-homelab.com
```

I have Argo CD apply my certificates as long as they are in the `kubernetes/cert-manager/certificates/` directory. Alternatively, you can do `kubectl apply -f [path to certificate.yaml]`

### Create the ingress route

> [!WARNING]
> If you have Argo CD set up like me and notice that the resources are not being applied, do not forget to sync the application.

You can find an ingress route template [here](https://github.com/aditaranto1028/homelab/blob/main/kubernetes/traefik/template-IngressRoute.yaml).

Below is the filled in template for my `test-nginx` deployment:

```yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: test-nginx-ingressroute
  namespace: test-nginx
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`test-nginx.ditaranto-homelab.com`)
      kind: Rule
      services:
        - name: test-nginx
          port: 80
  tls:
    secretName: test-nginx-certificate-secret
```

I have Argo CD apply my ingress routes as long as they are in the `kubernetes/traefik/ingressRoutes` directory. Alternatively, you can do `kubectl apply -f [path to ingressRoute.yaml]`

### Verification

Run the command:

```bash
kubectl get certificate -n [namespace]
```

Expected output:

```text
NAME                     READY   SECRET                          AGE
test-nginx-certificate   True    test-nginx-certificate-secret   28m
```

Run the command:

```bash
kubectl get secret [certificate name] -n [namespace] -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | grep Issuer
```

Expected output:

```text
        Issuer: C = US, O = Let's Encrypt, CN = YR1
                CA Issuers - URI:http://yr1.i.lencr.org/
```

Run the command:

```bash
kubectl describe certificate [certificate name] -n [namespace] | grep -A10 -e '^Status'
```

Expected output:

```text
Status:
  Conditions:
    Last Transition Time:  2026-08-15T22:07:03Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2026-11-13T20:50:29Z
  Not Before:              2026-08-15T20:50:30Z
  Renewal Time:            2026-10-14T20:50:29Z
```
