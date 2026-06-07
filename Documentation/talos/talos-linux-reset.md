# How to reset Talos Linux nodes

> [!NOTE]
> This reset documentation is based on my needs/goals. Please look into what the commands do 
and tailor them to your needs.

### Prevent new workloads from starting

Do this to each of the nodes that you want to reset.

```bash
kubectl cordon [Node Name]
```

### Drain the existing workloads

Do this to each of the nodes that you want to reset.

```bash
kubectl drain [Node Name] --ignore-daemonsets --delete-emptydir-data
```

### Leave the etcd cluster (control-plane nodes only)

```bash
talosctl etcd leave --nodes [Node IP]
```

### Reset your nodes

Do this to each of the nodes that you want to reset.

```bash
talosctl reset --nodes [Node IP(s)] \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL \
  --graceful=true \
  --reboot
```
