# How to set up a Cloudflare Tunnel in Kubernetes

> [!NOTE]
> Prerequisites:
> - You have a domain with the nameservers set to Cloudflare's nameservers

### Create the tunnel in Cloudflare's dashboard

Navigate to https://one.dash.cloudflare.com/ and do the following:
- On the left-hand side select `Networks`
- Select `Tunnels & Mesh`
- Select `+ Create a tunnel`
- Select `Cloudflared`
- Name and save your tunnel
- Get the token:
  - Make sure the device OS is set to Windows
  - Press the copy icon for step 4
  - Paste the command somewhere temporarily and extract the token

```bash
cloudflared.exe service install [token]
```

### Secure your Cloudflare tunnel

> [!WARNING]
> By default the Cloudflare tunnel created in this documentation will allow anyone to publicly access the services that you configure. The following will show you how to set up some security for your tunnel.

##### Get your public IP

Run the command:

```bash
curl https://www.cloudflare.com/cdn-cgi/trace | grep ip=
```

##### Create an IP list (can be updated by an API) and block rule

Navigate to https://dash.cloudflare.com and do the following:

- Click on your domain
- On the left-hand side click `Security`
- Click `Security rules`
- In the `Custom rules` section, click `Create rule`
- Give the rule a name you will remember later (only so you can identify the rule)
- Click `Manage lists`
- Click `Create IP list` and name it `home_ip`
- Click `Create`
- Paste the public IP and select `Add to list`
- Click `< Back`
- Navigate back to where you selected `Manage lists`
- Click `Edit expression`
- Paste in `(not ip.src in $home_ip)`
- Under `Then take action...` put `Block`
- Click `Deploy`
- Click `Deploy`

### Create the Cloudflare tunnel token secret

Run the command:

```bash
kubectl create secret generic cf-tunnel \
  --from-literal=token='[token]' \
  -n default
```

### Create the Cloudflare tunnel deployment

Create a file called `deployment.yaml` with the following contents:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    tunnel: cf-tunnel
  name: cf-tunnel
  namespace: default
spec:
  replicas: 2 # Replace
  selector:
    matchLabels:
      tunnel: cf-tunnel
  strategy:
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
  template:
    metadata:
      labels:
        tunnel: cf-tunnel
    spec:
      containers:
        - args:
            - tunnel
            - --no-autoupdate
            - --metrics
            - 0.0.0.0:8081
            - run
            - --token
            - $(token)
          envFrom:
            - secretRef:
                name: cf-tunnel
          env:
            - name: TZ
              value: UTC
          image: cloudflare/cloudflared:2026.7.3 # Replace the version number
          imagePullPolicy: Always
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /ready
              port: 8081
            initialDelaySeconds: 10
            periodSeconds: 10
          name: tunnel
          ports:
            - containerPort: 8081
              name: http-metrics
```

### Verification

When you look at the tunnel in Cloudflare's dashboard it should have a status of `Healthy`.

### Create a record

You can create a record in Cloudflare by doing the following:
- Navigate to https://one.dash.cloudflare.com/
- On the left-hand side select `Networks`
- Select `Tunnels & Mesh`
- Select the tunnel you just made
- Select `Published application routes`
- Select `+ Add a published application route`

> [!NOTE]
> Hostnames in Kubernetes are formatted like this:
> `<service-name>.<namespace>.svc.cluster.local:<port>`
