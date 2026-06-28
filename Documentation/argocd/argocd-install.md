# How to install Argo CD

### Prerequisites

Before installing Argo CD, you should have the following:

- `kubectl` command-line tool
- `kubeconfig` file (default location `~/.kube/config`)
- CoreDNS

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

- Making Argo CD the `LoadBalancer` service type
- Kubernetes ingress controller
- Kubernetes port forwarding (my current choice)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
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
