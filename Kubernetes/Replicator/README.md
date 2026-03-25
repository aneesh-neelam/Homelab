# Replicator

Kubernetes Secret Replicator (mittwald/kubernetes-replicator) deployed via Helm chart. Automatically copies secrets across namespaces based on annotations, used by services that need database credentials from the `postgresql` namespace.

## Deployment

### 1. Deploy Replicator

```bash
helm repo add mittwald https://helm.mittwald.de
helm install replicator mittwald/kubernetes-replicator \
  -n kube-system \
  -f values.yaml
```

## Usage

To replicate a secret, annotate the source secret:

```bash
kubectl -n postgresql annotate secret my-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="target-namespace" \
  replicator.v1.mittwald.de/replicate-to="target-namespace"
```

The secret will be automatically created and kept in sync in the target namespace.

## Resource Allocation

| Container | CPU Request | CPU Limit | Memory (Request = Limit) |
|-----------|------------|-----------|--------------------------|
| Replicator | 25m | 100m | 64Mi |
