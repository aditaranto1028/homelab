# How to install Longhorn in Talos Linux

> [!NOTE]
> The following Talos Linux extensions need to be installed as a prerequisite for Longhorn:
> - `iscsi-tools`
> - `linux-utils`
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md) (optional)
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md) (optional)
>
> You can find my documentation on how to add extensions in Talos Linux [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/talos/talos-linux-upgrade.md). You **must** also have `argocd` installed in your cluster and the `argocd` CLI tool.

### Create a namespace with privileged access

Create a file with the following contents:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

Apply the namespace with the following command:

```bash
kubectl apply -f [path to namespace.yaml]
```

### Install Longhorn

#### Log in to `argocd`

```bash
argocd login --core
```

#### Set the Kubernetes namespace to `argocd`

```bash
kubectl config set-context --current --namespace=argocd
```

#### Create a values file

> [!NOTE]
> If you do not have a network load balancer like MetalLB, you can skip below to the `ClusterIP` section to see what you should do differently.

Create the values file with the contents below:

```yaml
---
service:
  ui:
    type: LoadBalancer
    loadBalancerIP: "x.x.x.x" # Replace
preUpgradeChecker:
  jobEnabled: false
```

#### Create an ArgoCD application resource

Create an application resource file with the contents below:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
  project: default
  sources:
    - chart: longhorn
      repoURL: https://charts.longhorn.io/
      targetRevision: v1.12.0 # Replace
      helm:
        valueFiles:
          - $values/kubernetes/longhorn/values.yaml # Replace
    - repoURL: https://github.com/aditaranto1028/homelab.git # Replace
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: longhorn-system
```

Apply the application resource:

```bash
kubectl apply -f [path to application.yaml]
```

#### Deploy Longhorn

```bash
argocd app sync longhorn
```

### Configure default backup target

Create a backup target file with the following contents:

```yaml
---
apiVersion: longhorn.io/v1beta2
kind: BackupTarget
metadata:
  name: default
  namespace: longhorn-system
spec:
  backupTargetURL: ""
```

Apply the backup target with the following command:

```bash
kubectl apply -f [path to backup-target.yaml]
```

### Verify installation

Command: `kubectl get pods -n longhorn-system`
Output:

```text
NAME                                                READY   STATUS    RESTARTS   AGE
csi-attacher-866df4b764-bhpbj                       1/1     Running   0          13d
csi-attacher-866df4b764-m9wvk                       1/1     Running   0          13d
csi-attacher-866df4b764-r9pzl                       1/1     Running   0          13d
csi-provisioner-6f7c8f8fb9-2zqct                    1/1     Running   0          13d
csi-provisioner-6f7c8f8fb9-s2n9x                    1/1     Running   0          13d
csi-provisioner-6f7c8f8fb9-s84x9                    1/1     Running   0          13d
csi-resizer-7cc5c4687-57shl                         1/1     Running   0          13d
csi-resizer-7cc5c4687-pkzw8                         1/1     Running   0          13d
csi-resizer-7cc5c4687-v94s7                         1/1     Running   0          13d
csi-snapshotter-789ffd5dcd-8cdth                    1/1     Running   0          13d
csi-snapshotter-789ffd5dcd-hr279                    1/1     Running   0          13d
csi-snapshotter-789ffd5dcd-k7gjm                    1/1     Running   0          13d
engine-image-ei-a4d05f02-hr48s                      1/1     Running   0          13d
engine-image-ei-a4d05f02-jdwhs                      1/1     Running   0          13d
instance-manager-13cd7cdae415b6cf2b2ff7399ca7e8ab   1/1     Running   0          13d
instance-manager-ee47bc06b64e1a992654ba3d9f0893ac   1/1     Running   0          13d
longhorn-csi-plugin-42n4h                           3/3     Running   0          13d
longhorn-csi-plugin-h7hk5                           3/3     Running   0          13d
longhorn-driver-deployer-6b97f48b5b-nwnn7           1/1     Running   0          13d
longhorn-manager-9ffdt                              2/2     Running   0          13d
longhorn-manager-zt7pt                              2/2     Running   0          13d
longhorn-ui-887d56cd8-hct7x                         1/1     Running   0          13d
longhorn-ui-887d56cd8-jqw5h                         1/1     Running   0          13d
```

Command: `kubectl get storageclass`
Output:

```text
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   13d
longhorn-static      driver.longhorn.io   Delete          Immediate           true                   13d
```

> [!NOTE]
> After syncing longhorn, if ArgoCD says the application is out of sync. If you are able to identify that the only resource out of sync is `longhorn-frontend`, you can do the following.
> - Click on the `longhorn-frontend` resource in ArgoCD
> - Scroll down and select DIFF
> - If the only difference is a node port, run the command: `kubectl patch svc longhorn-frontend -n longhorn-system --type=merge -p '{"spec":{"allocateLoadBalancerNodePorts":false}}'`

### Access the UI

#### LoadBalancerIP (good choice)

Longhorn should automatically get a load balancer IP.

To verify, you can run the command: `kubectl get svc -n longhorn-system`

Expected output:

```text
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)    AGE
longhorn-admission-webhook   ClusterIP      10.111.43.20    <none>         9502/TCP   6d3h
longhorn-backend             ClusterIP      10.106.18.119   <none>         9500/TCP   6d3h
longhorn-frontend            LoadBalancer   10.100.75.108   192.168.1.17   80/TCP     6d3h
longhorn-recovery-backend    ClusterIP      10.107.91.10    <none>         9503/TCP   6d3h
```

### ClusterIP

#### Create a values file

Create the values file with the contents below:

```yaml
---
preUpgradeChecker:
  jobEnabled: false
```

With the change above, you can follow in the documentation from where you left off. With the ClusterIP, to access the UI, you have two options:

- Port-forwarding the service every time
- Ingress controller

##### Ingress controller (my current choice)

> [!NOTE]
> Prerequisites:
> - [Traefik](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/traefik-install.md)
> - [Cert-manager](https://github.com/aditaranto1028/homelab/blob/main/Documentation/cert-manager/cert-manager-install.md)
> - A registered domain (i.e. ditaranto-homelab.com)

Follow my [documentation](https://github.com/aditaranto1028/homelab/blob/main/Documentation/traefik/ingressRoute-and-certificate.md) on how to set up the ingress route, certificate, and published application route.

##### Port-forward

You will need to run this command every time: `kubectl port-forward service/longhorn-frontend 8080:80 -n longhorn-system`.

> [!NOTE]
> To upgrade to a `loadBalancerIP` later on, you just need to use the previous values file and then sync longhorn with Argo CD.

### Add more space to Longhorn

When I first started using Longhorn, I noticed it was only using ~140 GB while I had a 512 GB NVMe in my node.

If there is unallocated space on the disk, you can add more space by doing the following:

#### Create a Talos Linux patch file

Create a file with the contents below:

```yaml
---
apiVersion: v1alpha1
kind: UserVolumeConfig
name: longhorn
provisioning:
  diskSelector:
    match: disk.transport == 'nvme'
  minSize: 340GB # Replace
  # maxSize: 360GB # Replace
  grow: true
filesystem:
  type: xfs
```

> [!NOTE]
> You can modify the minimum and maximum size of the added space in the YAML file. If you leave `maxSize` commented out, it will take up the remaining space.

#### Apply the Talos Linux patch file

Run the command:

```bash
talosctl patch mc -n [node IP] --patch-file longhorn-volume.yaml
```
#### Verify the volume status

Run the command:

```bash
talosctl -n [node IP] get volumestatus | grep longhorn
```

Expected output:

```text
192.168.1.11   runtime     MountStatus   u-longhorn                          2         /dev/nvme0n1p5   /var/mnt/longhorn                   xfs          u-longhorn
```

#### Verify the mount status

Run the command:

```bash
talosctl -n [node IP] get mountstatus | grep longhorn
```

Expected output:

```text
192.168.1.11   runtime     MountStatus   u-longhorn                          2         /dev/nvme0n1p5   /var/mnt/longhorn                   xfs          u-longhorn
```

### Add the allocated space in Longhorn UI

Access the longhorn UI and do the following:
- Select the `Nodes` tab
- Find the node you just applied the patch to
- Select the 3 dots drop down menu
- Select `Edit node and disks`
- Scroll down and select `Add Disk`
- Enter the following information:
  - Name: choose whatever you want (e.g. nvme-extra)
  - Disk Type: File System
  - Path: output from the `mountstatus` command (i.e. `/var/mnt/longhorn`)
  - Storage Reserved: ~10% of the allocated volume
  - Scheduling: Enable
  - Eviction Requested: False
- Select `Save`
- After a couple of seconds, you should see the change reflected in the UI
