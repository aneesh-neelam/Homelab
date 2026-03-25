# Mac Mini Monitoring

Prometheus monitoring for the Mac Mini host machine (outside the Kubernetes cluster). Creates an Endpoints/Service/ServiceMonitor pointing to the node-exporter running on the Mac Mini.

## Prerequisites

- Prometheus operator running in `monitoring` namespace
- node-exporter running on the Mac Mini (`192.168.213.1:9100`)

## Deployment

```bash
kubectl apply -f mac-mini-node-exporter.yaml
```

## Configuration

| Parameter | Value |
|-----------|-------|
| Host IP | 192.168.213.1 (VMware Fusion host-only network) |
| Port | 9100 |
| Scrape Interval | 30s |
| Service Type | Headless (clusterIP: None) |

The ServiceMonitor uses the `node-exporter` job label so Mac Mini metrics appear alongside cluster node metrics in Grafana dashboards.
