# Container Registry

Docker Distribution Registry (registry:2) for storing custom project Docker images. Accessible from within the cluster for Kubelet image pulls and from the host network for pushing images.

## Prerequisites

- containerd on cluster nodes configured to allow the insecure registry (see below)
- OrbStack (or Docker) on development machines configured to allow the insecure registry (see below)

## Deployment

### 1. Deploy the registry

```bash
kubectl apply -f container-registry.yaml
```

### 2. Configure containerd on cluster nodes

On each cluster node (e.g., `macstation-ubuntu-1.local`), create the hosts.d directory for the registry:

```bash
sudo mkdir -p /etc/containerd/hosts.d/macstation-ubuntu-1.local:30500
sudo tee /etc/containerd/hosts.d/macstation-ubuntu-1.local:30500/hosts.toml > /dev/null << 'EOF'
server = "http://macstation-ubuntu-1.local:30500"

[host."http://macstation-ubuntu-1.local:30500"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
```

No containerd restart is needed — `hosts.d` is read dynamically.

### 3. Configure OrbStack on development machines

Edit `~/.orbstack/config/docker.json`:

```json
{
  "insecure-registries": ["macstation-ubuntu-1.local:30500"]
}
```

Restart OrbStack after the change (quit and reopen from the menu bar).

This has been configured on:
- MacBook Pro (`Aneesh-MacBook-Pro`)
- Mac Mini (`macstation.local`)

> **Note:** If using Docker Desktop instead of OrbStack, edit `~/.docker/daemon.json` with the same content and restart Docker.

## Usage

### Push an image

```bash
docker build -t macstation-ubuntu-1.local:30500/my-project:latest .
docker push macstation-ubuntu-1.local:30500/my-project:latest
```

### Use in Kubernetes manifests

Reference images from the registry in your pod specs:

```yaml
containers:
  - name: my-app
    image: macstation-ubuntu-1.local:30500/my-project:latest
```

### List repositories

```bash
curl http://macstation-ubuntu-1.local:30500/v2/_catalog
```

### List tags for a repository

```bash
curl http://macstation-ubuntu-1.local:30500/v2/my-project/tags/list
```

### Delete an image tag

```bash
# Get the digest for the tag
DIGEST=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://macstation-ubuntu-1.local:30500/v2/my-project/manifests/latest \
  -o /dev/null -w '' -D - | grep Docker-Content-Digest | awk '{print $2}' | tr -d '\r')

# Delete the manifest by digest
curl -X DELETE http://macstation-ubuntu-1.local:30500/v2/my-project/manifests/$DIGEST
```

### Garbage collection (reclaim disk space after deleting images)

Garbage collection runs automatically every Sunday at 3:00 AM via a CronJob (`container-registry-gc`). The GC pod mounts the same PVC (`ReadWriteOnce`) as the registry and uses `podAffinity` to ensure it schedules on the same node. It skips execution if no repositories exist yet.

To trigger it manually:

```bash
kubectl -n container-registry create job --from=cronjob/container-registry-gc container-registry-gc-manual
```

To run it directly in the registry pod:

```bash
kubectl -n container-registry exec deploy/container-registry -- \
  bin/registry garbage-collect /etc/docker/registry/config.yml
```

## Monitoring

Prometheus metrics are exposed natively via the registry's debug endpoint on port 5001.

### Deploy monitoring resources

```bash
kubectl apply -f container-registry-prometheus-rbac.yaml
kubectl apply -f container-registry-servicemonitor.yaml
```

The Grafana dashboard (`container-registry-grafana-dashboard.json`) is provisioned as a ConfigMap in the `monitoring` namespace via `grafana.yaml`. It includes panels for:

- Registry uptime status
- HTTP request rates by handler and status code
- Request latency (p50/p99) by handler
- Storage action rates and latency
- Blob upload/download byte rates and counts

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Container Registry | 5000 | 30500 |
| Container Registry Metrics | 5001 | — |

## Storage

| PVC | Size | Storage Class |
|-----|------|---------------|
| container-registry-data | 50Gi | csi-rawfile-default |
