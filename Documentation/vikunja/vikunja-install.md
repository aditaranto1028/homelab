# How to install Vikunja

> [!NOTE]
> Prerequisites:
> - Argo CD is installed in the Kubernetes cluster
> - MetalLB is installed in the Kubernetes cluster (optional if you want to port-forward the service)

### Create the namespace

Create a file called `namespace.yaml` with the contents below:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: vikunja
```

Run the command:

```bash
kubectl apply -f [path to namespace.yaml]
```

### Create an email to send your notifications

The instructions below use a custom Gmail account with an app password. The instructions should be the same for alternative email services as long as you can authenticate with a username and password.

### Create the values file

Create a file called `values.yaml` with the contents below:

```yaml
---
vikunja:
  configMaps:
    config:
      data:
        config.yml: |
          mailer:
            enabled: true
            host: "smtp.gmail.com"
            username: "vikunja.ditaranto@gmail.com"
            port: 587
            forcessl: false
          service:
            publicurl: "http://192.168.1.18" # Replace
          defaultsettings:
            email_reminders_enabled: true
  env:
    VIKUNJA_DATABASE_TYPE: "sqlite"
  envFrom:
    - secretRef:
        name: vikunja-mailer-secret
```

If you do not care about email reminders, your `values.yaml` file can be replaced by:

```yaml
---
vikunja:
  configMaps:
    config:
      data:
        config.yml: |
          service:
            publicurl: "http://192.168.1.18" # Replace
  env:
    VIKUNJA_DATABASE_TYPE: "sqlite"
```

### Create the load balancer service file (optional but recommended)

If you are fine with port-forwarding the vikunja service, you can skip the section below.

Create a file called `service.yaml` with the contents below:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: vikunja-service
  namespace: vikunja
spec:
  type: LoadBalancer
  loadBalancerIP: x.x.x.x # Replace
  selector:
    app.kubernetes.io/name: vikunja
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3456
```

### Create the Kubernetes secret

If you are using a username and password for your email account to send notifications, you need to run the command below:

```bash
kubectl create secret generic vikunja-mailer-secret \
  --from-literal=VIKUNJA_MAILER_PASSWORD='[PASSWORD]' \
  -n vikunja
```

### Create the Argo CD application file

Create a file called `application.yaml` with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vikunja
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: vikunja
      repoURL: oci://ghcr.io/go-vikunja/helm-chart/vikunja
      targetRevision: v2.0.2 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/vikunja/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      path: kubernetes/vikunja/config # Replace
  destination:
    server: https://kubernetes.default.svc
    namespace: vikunja
```

Run the command:

```bash
kubectl apply -f [path to application.yaml]
```

### Sync the Argo CD application

#### UI

- Go to the Argo CD UI in the browser
- Select "Applications"
- Select the vikunja application
- Select "Sync"

#### CLI

Run the commands:

```bash
argocd login --core
argocd app sync vikunja
```

### Verification

You can do the following verification steps:
- The vikunja application should be healthy in Argo CD
- Run the command `kubectl get all -n vikunja` and you should get something similar to the below:

```text
NAME                           READY   STATUS    RESTARTS   AGE
pod/vikunja-7f59b57595-b2r2q   1/1     Running   0          6h25m

NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)        AGE
service/vikunja           ClusterIP      10.101.159.237   <none>         3456/TCP       6h25m
service/vikunja-service   LoadBalancer   10.111.33.104    192.168.1.18   80:32563/TCP   9h

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/vikunja   1/1     1            1           6h25m

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/vikunja-7f59b57595   1         1         1       6h25m
```

### Verification of email notifications

If you choose to utilize email notifications, you should do the following.

Get the pod name using the command `kubectl get pods -n vikunja` with the output looking like:

```text
NAME                       READY   STATUS    RESTARTS   AGE
vikunja-7f59b57595-b2r2q   1/1     Running   0          6h29m
```

To test the email notifications, run the command below:

```bash
kubectl exec -it pod/[pod name] -n vikunja -- /app/vikunja/vikunja testmail [email]
```

Expected output:

```text
time=2026-08-02T18:52:10.129Z level=INFO msg="Using config file: /etc/vikunja/config.yml"
time=2026-08-02T18:52:10.130Z level=INFO msg="Sending testmail..."
time=2026-08-02T18:52:11.300Z level=INFO msg="Testmail successfully sent."
```
