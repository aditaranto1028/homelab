# How to install Longhorn in Talos Linux

> [!NOTE]
> These instructions are for a Talos Linux node running v1.10+

## Preparing the nodes

### Prerequisites

1. The `siderolabs/iscsi-tools` extension installed
2. The `siderolabs/util-linux-tools` extension installed

If you need instructions on how to add extensions in Talos Linux, you can use my documentation found [here](https://github.com/aditaranto1028/homelab/blob/main/Documentation/talos-linux-upgrade.md).

### Patching your cluster

You will need three of the following patch files which can be found on my GitHub:

1. ephemeral-cap.yaml
    - Limits the size of the EPHEMERAL system partition to 150 GB (adjust as needed)
2. longhorn-kubelet-patch.yaml
    - Bind-mounts `/var/mnt/longhorn` into the `kubelet` container so Kubernetes pods can access the path as a `hostPath` volume
3. longhorn-volume-patch.yaml
    - Creates a dedicated XFS partition on the NVMe disk, automatically mounted at `/var/mnt/longhorn`

### Resetting your nodes

> [!WARNING]
> When I first tried applying my patch files, I noticed that the EPHEMERAL partition was taking up 510 GB, leaving no room for the XFS partition for Longhorn. To fix this, I reset the existing nodes back to maintenance mode and re-applied the `controlplane.yaml` or `worker.yaml` file with the patches.

```bash
kubectl drain [Node Name] --ignore-daemonsets --delete-emptydir-data

talosctl reset \
  --nodes [Node IP] \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL \
  --reboot \
  --graceful=false
```

### Apply your config

After applying the config to a control plane node, do not forget to bootstrap your control-plane node. This is required when resetting with `--graceful=false`.

```bash
talosctl apply-config \
  --nodes [Node IP] \
  --file [worker|controlplane].yaml \
  --config-patch @ephemeral-cap.yaml \
  --config-patch @longhorn-volume-patch.yaml \
  --config-patch @longhorn-kubelet-patch.yaml \
  --insecure
```

## Installing Longhorn

I used the documentation from Josh Noll which can be found [here](https://joshrnoll.com/installing-longhorn-on-talos-with-helm/).

### Create the namespace

```bash
kubectl create namespace longhorn-system && \
kubectl label namespace longhorn-system \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/enforce-version=latest
```

### Create the values file

Create a YAML file with the following contents:

```yaml
---
defaultSettings:
  defaultDataPath: /var/mnt/longhorn
  defaultReplicaCount: 1
persistence:
  reclaimPolicy: Retain
  defaultClassReplicaCount: 1
```

### Install Longhorn using Helm

```bash
helm repo add longhorn https://charts.longhorn.io && helm repo update

helm install longhorn longhorn/longhorn --namespace longhorn-system --values=[values file]
```

### Verification

After a few minutes you should be able to run the command `kubectl -n longhorn-system get pod` and get the output below:

```text
NAME                                                READY   STATUS    RESTARTS      AGE
csi-attacher-5c5b4c7fb-7cfdr                        1/1     Running   0             77m
csi-attacher-5c5b4c7fb-fv856                        1/1     Running   0             77m
csi-attacher-5c5b4c7fb-tgppw                        1/1     Running   0             77m
csi-provisioner-56b448bc97-bdbdw                    1/1     Running   0             77m
csi-provisioner-56b448bc97-lzn2f                    1/1     Running   0             77m
csi-provisioner-56b448bc97-w68hm                    1/1     Running   0             77m
csi-resizer-7fdc44bd7f-7k96d                        1/1     Running   0             77m
csi-resizer-7fdc44bd7f-cns86                        1/1     Running   0             77m
csi-resizer-7fdc44bd7f-lvq5d                        1/1     Running   0             77m
csi-snapshotter-77c5b9867d-2vpd2                    1/1     Running   0             77m
csi-snapshotter-77c5b9867d-bntgl                    1/1     Running   0             77m
csi-snapshotter-77c5b9867d-m6gph                    1/1     Running   0             77m
engine-image-ei-c9fa6d45-dsxdt                      1/1     Running   0             77m
engine-image-ei-c9fa6d45-t5wpq                      1/1     Running   0             77m
instance-manager-25f8d6872fbdeda4f2aaee470da65c17   1/1     Running   0             77m
instance-manager-f4b0a2ce9631d00ffee66f49c3da79bc   1/1     Running   0             77m
longhorn-csi-plugin-94x6g                           3/3     Running   0             77m
longhorn-csi-plugin-rgt22                           3/3     Running   0             77m
longhorn-driver-deployer-859d46c889-d887x           1/1     Running   0             77m
longhorn-manager-5s44s                              2/2     Running   0             77m
longhorn-manager-9smsd                              2/2     Running   1 (77m ago)   77m
longhorn-ui-69b7cc4775-5828x                        1/1     Running   0             77m
longhorn-ui-69b7cc4775-k4lkb                        1/1     Running   0             77m
```

### Accessing the UI

There are more steps to access the Longhorn UI which I have not done yet, but you can run the command below to temporarily access it:

```bash
kubectl port-forward service/longhorn-frontend 8080:80 -n longhorn-system
```
