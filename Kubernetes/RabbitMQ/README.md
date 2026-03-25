# RabbitMQ

RabbitMQ message broker deployed via the RabbitMQ Cluster Operator with 3 replicas for high availability.

## Prerequisites

- RabbitMQ Cluster Operator installed
- Prometheus operator running in `monitoring` namespace

## Deployment

### 1. Install the RabbitMQ Cluster Operator

```bash
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml
```

### 2. Deploy the RabbitMQ cluster

```bash
kubectl apply -f rabbitmq-cluster.yaml
```

### 3. Apply the NodePort services

```bash
kubectl apply -f rabbitmq-cluster-service.yaml
```

### 4. Apply Prometheus monitoring

```bash
kubectl apply -f rabbitmq-prometheus-rbac.yaml
kubectl apply -f rabbitmq-podmonitor.yaml
```

### 5. Create the Grafana dashboard ConfigMap

```bash
kubectl -n monitoring create configmap rabbitmq-grafana-dashboard \
  --from-file=rabbitmq-dashboard.json=rabbitmq-grafana-dashboard.json
```

Then re-apply the Grafana deployment to mount the new dashboard:

```bash
kubectl apply -f ../Monitoring/grafana.yaml
```

### 6. Retrieve the default credentials

```bash
kubectl -n rabbitmq get secret rabbitmq-default-user -o jsonpath='{.data.username}' | base64 -d
kubectl -n rabbitmq get secret rabbitmq-default-user -o jsonpath='{.data.password}' | base64 -d
```

## Configuration

| Parameter | Value |
|-----------|-------|
| Replicas | 3 |
| Storage | 1Gi per instance |
| Memory | 384Mi (request = limit) |
| CPU | 100m request, 500m limit |
| Memory Watermark | 0.9 (relative) |
| Disk Free Limit | 850MiB |
| Plugins | `rabbitmq_prometheus` |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| AMQP | 5672 | 30672 |
| Management UI | 15672 | 32672 |

## Monitoring

Prometheus scrapes metrics via a PodMonitor on the `prometheus` port with a 15s interval. The Grafana dashboard is provisioned as a ConfigMap.
