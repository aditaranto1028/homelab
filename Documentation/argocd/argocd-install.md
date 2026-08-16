# How to install Argo CD

### Prerequisites

Before installing Argo CD, you should have the following:

- `kubectl` command-line tool
- `kubeconfig` file (default location `~/.kube/config`)
- CoreDNS
- Traefik & cert-manager (optional)

### Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Install the Argo CD CLI

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### Access Argo CD

There are many ways to access Argo CD, with some options being:
- Making Argo CD the `LoadBalancer` service type (my current choice)
- Kubernetes ingress controller
- Kubernetes port forwarding

#### Port forwarding (default)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### Ingress controller (my current choice)

> [!NOTE]
> Prerequisites:
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md)
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md)
> - A registered domain (i.e. ditaranto-homelab.com)

Follow my [documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) on how to set up the ingress route, certificate, and published application route.

If you notice you are getting an `ERR_TOO_MANY_REDIRECTS` error, do the following:

- Run the command: `kubectl edit configmap argocd-cmd-params-cm -n argocd`
- At the bottom of the YAML, put the following:

```yaml
data:
  server.insecure: "true"
```

- Run the command: `kubectl rollout restart deployment argocd-server -n argocd`

#### Load balancer (good alternative)

> [!NOTE]
> Prerequisites:
> - You need to have some load balancer (MetalLB in my case) to give out the IP address
>   - Documentation can be found [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/metallb/metallb-install.md)
> - There shouldn't be an endpoint that is currently using this IP address
> - The IP address below should not be within a DHCP pool

Create a file called `service.yaml` with the following contents:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.16 # Replace
  selector:
    app.kubernetes.io/name: argocd-server
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: 8080
    - name: https
      port: 443
      protocol: TCP
      targetPort: 8080
```

Run the following command to set the type and load balancer IP:

```bash
kubectl apply -f [path to service.yaml]
```

### Log in to the Argo CD CLI

> [!NOTE]
> The username is `admin` and the password can be found from `argocd admin initial-password -n argocd`.

```bash
argocd login --port-forward --port-forward-namespace argocd
```

### Update the password

```bash
argocd account update-password
```

### Delete the old namespace secret

Once you change the password, you should delete `argocd-initial-admin-secret`.

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```
