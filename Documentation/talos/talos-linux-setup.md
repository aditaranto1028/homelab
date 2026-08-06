# How I installed Talos Linux in my homelab

> [!NOTE]
> Much of the information in this document was sourced from the [siderolabs documentation](https://docs.siderolabs.com/) and the [talos linux and kubernetes install (avoid common mistakes) video](https://www.youtube.com/watch?v=nyJz5odxaTQ).

## Initializing your first control-plane node

### Generate your Talos Linux image

1. Go to https://factory.talos.dev
2. Select `Bare-metal Machine` and select `Next`
3. Select your desired version (1.13.2) and select `Next`
4. Select your machine architecture (amd64) and select `Next`
5. Select the system extensions that you want to include in your image and select `Next`
    - Below are two extensions that are recommended if you plan to run any media services on the node
        1. `siderolabs/i915 (20260410-v1.13.2)`: [core] This system extension provides Intel GPU microcode binaries and kernel modules.
        2. `siderolabs/intel-ucode (20260227)`: [core] This system extension provides Intel microcode binaries.
6. Add any kernel command line arguments and/or pick your bootloader and select `Next`
7. You can now download your ISO and note your schematic ID
    - `4b3cd373a192c8469e859b7a0cfbed3ecc3577c4a2d346a37b0aeff9cd17cdb0`

### Making a bootable USB

Now that we have the ISO image, you will need to make a bootable USB with the image. There are many tools available for this, such as Rufus, Raspberry Pi Imager, etc.

### Boot from the USB

In my experience, booting from the USB with Secure Boot enabled caused issues, so it was disabled for the initial boot.

Once the node boots up, I did the following:

1. Press F3 to enter the `Network Config` tab
2. I configured my nodes with the following information, but you are free to do as you wish:
    - Hostname: I set mine to `talos-01` which will get incremented with each node
    - DNS Servers: I set mine to `1.1.1.1` and `8.8.8.8` but I plan to replace it with my own DNS server eventually
    - Time Servers: I left it blank and it initialized to `time.cloudflare.com`
    - Interface: I picked the only available option which was `eno01`
    - Mode: You should pick static here (the address you pick should not be available in a DHCP pool)
    - Addresses: Supply whatever address you want in the format `x.x.x.x/yy`
    - Gateway: This is the address of the default gateway (usually your router's address)
3. Click `Save`

### Install talosctl

```bash
curl -sL https://talos.dev/install | sh
```

### Generate the configuration file

##### Calico patch file

If you plan on using Calico, create a patch file with the contents below:

```yaml
cluster:
  network:
    cni:
      name: none
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
```

Run the command:

```bash
talosctl gen config [cluster name] https://[node IP]:6443 \
  --config-patch @[path to patch.yaml]
```

##### Flannel CNI (Talos Linux default)

```bash
talosctl gen config [cluster name] https://[node IP]:6443
```

### Verifying and/or installing Talos Linux to the disk

By default, Talos Linux installs itself to `/dev/sda`, which may cause a problem if `/dev/sda` is defaulting to the wrong storage.

You can run the command `talosctl -n [node IP] get disks --insecure` to get the disks on the node. As you can see below, `/dev/sda` is defaulting to the bootable USB while the actual storage has an ID of `nvme0n1`.

```text
NODE   NAMESPACE   TYPE   ID        VERSION   SIZE
       runtime     Disk   loop0     2         184 kB
       runtime     Disk   loop1     2         4.1 kB
       runtime     Disk   loop2     2         4.1 kB
       runtime     Disk   loop3     2         2.2 MB
       runtime     Disk   loop4     2         83 MB
       runtime     Disk   nvme0n1   2         512 GB
       runtime     Disk   sda       2         62 GB
```

If your node is defaulting `/dev/sda` to the USB, you can follow these steps to fix it:

Using `sed`:

1. Run the command: `STORAGE_ID=[storage ID]`
2. Run the command: `sed -i "s/\/dev\/sda/\/dev\/$STORAGE_ID/g" controlplane.yaml`

Manually:

1. Copy down the ID of the storage you want to install the Talos Linux OS to (`nvme0n1` in my case)
2. Edit `controlplane.yaml` in the editor of your choice
3. Search for `disk: /dev/sda`
4. Replace `sda` with the ID of your preferred storage

> [!WARNING]
> If you want your Kubernetes control-plane nodes to run workloads, you can run the command: `sed -i "s/# allowSchedulingOnControlPlanes: true/allowSchedulingOnControlPlanes: true/g" controlplane.yaml`.

### Applying your configuration file

```bash
talosctl apply-config -n [node IP] --insecure --file [path to controlplane.yaml]
```

### Bootstrapping Kubernetes

```bash
talosctl bootstrap --nodes [node IP] --endpoints [node IP] --talosconfig=[path to talosconfig]
```

### Create an environment variable for talosconfig

You may also want to add the line below to `~/.bashrc`

```bash
export TALOSCONFIG=[path to talosconfig]
```

### Define your endpoint

```bash
talosctl config endpoint [node IP]
```

### Download the admin kubeconfig from the node

```bash
talosctl kubeconfig -n [node IP]
```

### Verification

Make sure you have `kubectl` installed.

```bash
kubectl get nodes
```

## Adding an agent node

### Prerequisites

1. A control-plane node that has been bootstrapped with Kubernetes
2. The `worker.yaml` file generated when the configuration files were generated

### Applying the configuration file to the agent node

> [!WARNING]
> Follow the steps from `Verifying and/or installing Talos Linux to the disk` for `worker.yaml`

```bash
talosctl apply-config --insecure --nodes [node IP] --file [path to worker.yaml]
```

### Verification

If you run the command `kubectl get nodes`, you should get the following:

```text
NAME            STATUS   ROLES           AGE     VERSION
talos-01        NotReady    control-plane   4h10m   v1.36.0
talos-02        NotReady    <none>          3h19m   v1.36.0
```

### Install Calico using the Tigera Operator

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

kubectl get pods -n tigera-operator --watch
```

### Create an installation resource

Create a file called `installation.yaml` with the contents below:

```yaml
---
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
    linuxDataplane: Iptables
  flexVolumePath: /var/lib/kubelet/volumeplugins
  nodeMetricsPort: 9091
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
```

Run the command:

```bash
kubectl apply -f [path to installation.yaml]

kubectl get pods -n calico-system --watch
```

### Wait for Calico to be ready

```bash
kubectl get pods -n calico-system

kubectl get pods -n calico-apiserver

kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# talos-01   Ready    control-plane   68m   v1.36.0
# talos-02   Ready    <none>          66m   v1.36.0
```

### Install calicoctl

##### Brew

```bash
brew install calicoctl
```

##### Download directly

```bash
curl -L https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin/

export DATASTORE_TYPE=kubernetes
export KUBECONFIG=/home/anthony/.kube/config
```

##### Verification

```bash
kubectl get pod -n calico-system
# NAME                                       READY   STATUS    RESTARTS   AGE
# calico-kube-controllers-55546b8856-2vs7c   1/1     Running   0          88m
# calico-node-8stnt                          1/1     Running   0          88m
# calico-node-b2mq6                          1/1     Running   0          88m
# calico-typha-64c9c9ff4d-mc8fn              1/1     Running   0          88m
# csi-node-driver-c77jf                      2/2     Running   0          88m
#csi-node-driver-qlxxc                      2/2     Running   0          88m

kubectl exec -n calico-system [calico-node] -- birdcl -s /var/run/calico/bird.ctl show protocols
```
