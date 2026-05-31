# How to add Talos Linux extensions

> [!NOTE]
> When a user is creating their Talos Linux image through the `Talos Linux Image Factory`, they have to specify which extensions are needed. Later on, when a user wants to run a service that requires certain extensions (specifically one(s) that they don't already have), they will have to install the extensions. This document explains how to do that.

### Generating your image

1. Navigate to the [Talos Linux Image Factory](https://factory.talos.dev/)
2. Fill out the following:
    - Hardware Type
    - Talos Linux Version
    - Machine Architecture
3. Select all new **AND** old system extensions
4. Fill out the customizations as needed
5. You should now be on a page that includes the following:
    - First Boot (ISO, Disk Image, etc)
    - Initial Installation
    - Upgrading Talos Linux
6. Copy the image from the `Upgrading Talos Linux` section
    - It should look like `factory.talos.dev/metal-installer/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.13.3`

### Upgrading Talos Linux

Run the command below for each node in the cluster:

```bash
talosctl -n [Node IP] upgrade --image [Image from earlier]
```
