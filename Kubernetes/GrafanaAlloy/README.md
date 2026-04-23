# Grafana Alloy

Grafana Alloy deployed via Helm chart. Federates metrics from the local Prometheus and `remote_write`s them to Grafana Cloud.

## Prerequisites

- Prometheus running in `monitoring` namespace (exposed at `prometheus-k8s.monitoring.svc.cluster.local:9090`)
- Grafana Cloud account with a Prometheus stack and an API token with `metrics:write` scope

## Deployment

### 1. Create the namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Create the Grafana Cloud credentials secret

Get the username (stack ID) and API token from https://grafana.com/orgs/aneeshneelam/hosted-metrics, then:

```bash
kubectl -n grafana-alloy create secret generic grafana-cloud-credentials \
  --from-literal=username=<Grafana Cloud Stack ID> \
  --from-literal=password=<Grafana Cloud API Token>
```

### 3. Deploy Grafana Alloy

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install alloy grafana/alloy \
  -n grafana-alloy \
  -f values.yaml
```

### 4. Verify metrics are flowing

Check that samples are being pushed (no failures):

```bash
kubectl -n grafana-alloy port-forward deploy/alloy 12345:12345
curl -s http://localhost:12345/metrics | grep -E "prometheus_remote_storage_samples_(in_total|failed_total|pending)"
```

Then query metrics in Grafana Cloud at https://aneeshneelam.grafana.net via **Explore** with the `grafanacloud-aneeshneelam-prom` data source.

## Upgrades

After updating `values.yaml`:

```bash
helm upgrade alloy grafana/alloy -n grafana-alloy -f values.yaml
```

## Configuration Notes

- The Alloy config uses `sys.env()` to read credentials from environment variables injected from the `grafana-cloud-credentials` secret.
- Metrics are federated from local Prometheus via `/federate` with a `{__name__=~".+"}` matcher (scrapes all series).
- Scrape interval is set to `60s` to reduce Grafana Cloud ingestion volume.

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| Prometheus | prometheus-k8s.monitoring.svc.cluster.local:9090 | monitoring |
| Grafana Cloud | https://prometheus-prod-43-prod-ap-south-1.grafana.net/api/prom/push | — (external) |
