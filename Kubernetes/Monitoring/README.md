# Monitoring

Complete observability stack deployed via Kubernetes manifests: Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter, blackbox-exporter, and prometheus-adapter.

## Components

| Component | Version | Replicas |
|-----------|---------|----------|
| Prometheus Operator | 0.85.0 | 1 |
| Prometheus | 3.5.0 | 2 |
| Grafana | 12.1.0 | 1 |
| Alertmanager | 0.28.1 | 2 |
| Kube-State-Metrics | 2.16.0 | 1 |
| Node-Exporter | 1.9.1 | DaemonSet |
| Blackbox-Exporter | 0.27.0 | 1 |
| Prometheus-Adapter | 0.12.0 | 2 |

## Deployment

### 1. Create the namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Deploy the Prometheus Operator

```bash
kubectl apply -f prometheus-operator.yaml
```

Wait for the operator pod to be ready before proceeding.

### 3. Deploy core monitoring components

```bash
kubectl apply -f prometheus.yaml
kubectl apply -f alertmanager.yaml
kubectl apply -f grafana.yaml
```

### 4. Deploy exporters and adapters

```bash
kubectl apply -f kube-state-metrics.yaml
kubectl apply -f node-exporter.yaml
kubectl apply -f blackbox-exporter.yaml
kubectl apply -f prometheus-adapter.yaml
```

## Prometheus

- **Retention:** 30 days or 5020MB (whichever comes first)
- **Scrape interval:** 30s
- **Storage:** 5Gi PVC (`local-path`)
- **Discovery:** Watches all ServiceMonitors and PodMonitors cluster-wide

## Grafana

- **Data sources:** Prometheus, PostgreSQL (nextcloud, openwebui, superset, currency_exchange_rates)
- **Dashboards:** Provisioned from ConfigMaps created by each service (CNPG, Nextcloud, Immich, Superset, Container Registry, Valkey, RabbitMQ, etc.)
- **Authentication:** Credentials from Kubernetes secrets

## Alertmanager

- **Retention:** 720h (30 days)
- **Routing:** Groups by namespace with severity-based receivers (Critical, Warning, Info)

## Resource Allocation

| Component | CPU Request | CPU Limit | Memory (Request = Limit) |
|-----------|------------|-----------|--------------------------|
| Prometheus Operator | 50m | 100m | 100Mi |
| Prometheus | 100m | 200m | 384Mi |
| Alertmanager | 10m | 50m | 64Mi |
| Grafana | 100m | 200m | 256Mi |
| Kube-State-Metrics | 25m | 50m | 128Mi |
| Node-Exporter | 100m | 200m | 180Mi |
| Blackbox-Exporter | 5m | 10m | 20Mi |
| Prometheus-Adapter | 50m | 100m | 128Mi |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Prometheus | 9090 | 30090 |
| Prometheus Reloader | 8080 | 30080 |
| Alertmanager | 9093 | 30093 |
| Alertmanager Reloader | 8080 | 30880 |
| Grafana | 3000 | 30300 |
| Kube-State-Metrics | 8080 | — |
| Node-Exporter | 9100 | — |
| Blackbox-Exporter | 9115 | — |
