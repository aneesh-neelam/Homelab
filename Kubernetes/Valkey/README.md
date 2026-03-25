# Valkey

Valkey (Redis-compatible) in-memory data store deployed via Helm chart. Used as a shared cache by Nextcloud, OpenWebUI, Immich, and Superset.

## Prerequisites

- Prometheus operator running in `monitoring` namespace

## Deployment

### 1. Deploy Valkey

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install valkey bitnami/valkey \
  -n valkey --create-namespace \
  -f values.yaml
```

### 2. Apply the NodePort service

```bash
kubectl apply -f valkey-nodeport-service.yaml
```

### 3. Apply Prometheus RBAC

```bash
kubectl apply -f valkey-prometheus-rbac.yaml
```

### 4. Create the Grafana dashboard ConfigMap

```bash
kubectl -n monitoring create configmap valkey-grafana-dashboard \
  --from-file=valkey-dashboard.json=valkey-grafana-dashboard.json
```

Then re-apply the Grafana deployment to mount the new dashboard:

```bash
kubectl apply -f ../Monitoring/grafana.yaml
```

## Configuration

| Parameter | Value |
|-----------|-------|
| Memory Policy | `allkeys-lru` |
| TCP Keep-Alive | 300s |
| Storage | 1Gi PVC (`csi-rawfile-default`) |
| Memory | 512Mi (request = limit) |
| CPU | 100m request, 500m limit |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Valkey | 6379 | 32379 |
