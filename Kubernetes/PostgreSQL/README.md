# PostgreSQL

PostgreSQL cluster deployed via CloudNative PG (CNPG) operator.

## Cluster

- **Name:** pg-cluster
- **Namespace:** postgresql
- **Instances:** 2 (primary + replica)
- **Storage:** 10Gi per instance

## Managed Roles and Databases

### 1. Create credential secrets

Create each secret with an auto-generated password, then add replicator annotations.

> **Important:** Do NOT use `kubectl apply -f` on the credentials YAML files — it will overwrite the secret data (password). Always create the secret first with `kubectl create secret`, then add annotations with `kubectl annotate`.

#### NextCloud

```bash
kubectl -n postgresql create secret generic nextcloud-db-credentials \
  --from-literal=username=nextcloud \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=nextcloud

kubectl -n postgresql annotate secret nextcloud-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="nextcloud" \
  replicator.v1.mittwald.de/replicate-to="nextcloud"
```

Replicated automatically to the `nextcloud` namespace by kubernetes-replicator.

#### CurrencyExchangeRatesSync

```bash
kubectl -n postgresql create secret generic currencyexchangeratessync-db-credentials \
  --from-literal=username=currencyexchangeratessync \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=currency_exchange_rates

kubectl -n postgresql annotate secret currencyexchangeratessync-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="currency-exchange-rates-sync" \
  replicator.v1.mittwald.de/replicate-to="currency-exchange-rates-sync"
```

Replicated automatically to the `currency-exchange-rates-sync` namespace by kubernetes-replicator.

#### OpenWebUI

```bash
kubectl -n postgresql create secret generic openwebui-db-credentials \
  --from-literal=username=openwebui \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=openwebui

kubectl -n postgresql annotate secret openwebui-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="open-webui" \
  replicator.v1.mittwald.de/replicate-to="open-webui"
```

Replicated automatically to the `open-webui` namespace by kubernetes-replicator.

#### Superset

```bash
kubectl -n postgresql create secret generic superset-db-credentials \
  --from-literal=username=superset \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=superset

kubectl -n postgresql annotate secret superset-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="superset" \
  replicator.v1.mittwald.de/replicate-to="superset"
```

Replicated automatically to the `superset` namespace by kubernetes-replicator.

#### Grafana (read-only)

```bash
kubectl -n postgresql create secret generic grafana-db-credentials \
  --from-literal=username=grafana \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16)

kubectl -n postgresql annotate secret grafana-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="monitoring" \
  replicator.v1.mittwald.de/replicate-to="monitoring"
```

Replicated automatically to the `monitoring` namespace by kubernetes-replicator.

### 2. Apply the cluster to create roles

```bash
kubectl apply -f pg-cluster.yaml
```

CNPG manages the roles declaratively. Databases are not managed by CNPG in this version.

### 3. Create databases and grant read access

Run the job to create the databases:

```bash
kubectl delete job pg-create-databases -n postgresql --ignore-not-found
kubectl apply -f create-databases-job.yaml
```

The job is idempotent and will skip databases that already exist. It auto-cleans up after 5 minutes.

The job also grants read-only access (CONNECT, SELECT on all tables, default privileges) to the `superset` and `grafana` roles across all databases.

### Retrieve generated passwords

```bash
kubectl -n postgresql get secret nextcloud-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

kubectl -n postgresql get secret currencyexchangeratessync-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

kubectl -n postgresql get secret openwebui-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

kubectl -n postgresql get secret superset-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

kubectl -n postgresql get secret grafana-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d
```

## Roles Summary

| Role | Database | Read-Only Access | Replicated To |
|------|----------|------------------|---------------|
| nextcloud | nextcloud | own DB only | nextcloud |
| currencyexchangeratessync | currency_exchange_rates | own DB only | currency-exchange-rates-sync |
| openwebui | openwebui | own DB only | open-webui |
| superset | superset | all databases | superset |
| grafana | — | all databases | monitoring |

## Services

| Service | Type | Port | NodePort |
|---------|------|------|----------|
| pg-cluster-rw-nodeport | NodePort | 5432 | 30432 |
| pg-cluster-ro-nodeport | NodePort | 5432 | 30433 |

## Monitoring

- PodMonitor for Prometheus scraping (`pg-cluster-monitoring.yaml`)
- Prometheus RBAC (`pg-cluster-prometheus-rbac.yaml`)
- Grafana dashboard (`cnpg-grafana-dashboard.json`)
