# PostgreSQL

PostgreSQL cluster deployed via CloudNative PG (CNPG) operator.

## Cluster

- **Name:** pg-cluster
- **Namespace:** postgresql
- **Instances:** 2 (primary + replica)
- **Storage:** 10Gi per instance

## Managed Roles and Databases

### 1. Create credential secrets

Create the secrets with replicator annotations and auto-generated passwords:

#### NextCloud

```bash
kubectl apply -f nextcloud-db-credentials.yaml
kubectl -n postgresql patch secret nextcloud-db-credentials -p \
  "{\"stringData\":{\"username\":\"nextcloud\",\"password\":\"$(openssl rand -base64 12 | head -c 16)\",\"database\":\"nextcloud\"}}"
```

Replicated automatically to the `nextcloud` namespace by kubernetes-replicator.

#### CurrencyExchangeRatesSync

```bash
kubectl apply -f currencyexchangeratessync-db-credentials.yaml
kubectl -n postgresql patch secret currencyexchangeratessync-db-credentials -p \
  "{\"stringData\":{\"username\":\"currencyexchangeratessync\",\"password\":\"$(openssl rand -base64 12 | head -c 16)\",\"database\":\"currency_exchange_rates\"}}"
```

Replicated automatically to the `currency-exchange-rates-sync` namespace by kubernetes-replicator.

### 2. Apply the cluster to create roles

```bash
kubectl apply -f pg-cluster.yaml
```

CNPG manages the roles declaratively. Databases are not managed by CNPG in this version.

### 3. Create databases

Run the job to create the databases:

```bash
kubectl apply -f create-databases-job.yaml
```

The job is idempotent and will skip databases that already exist. It auto-cleans up after 5 minutes.

### Retrieve generated passwords

```bash
kubectl -n postgresql get secret nextcloud-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d

kubectl -n postgresql get secret currencyexchangeratessync-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d
```

## Services

| Service | Type | Port | NodePort |
|---------|------|------|----------|
| pg-cluster-rw-nodeport | NodePort | 5432 | 30432 |
| pg-cluster-ro-nodeport | NodePort | 5432 | 30433 |

## Monitoring

- PodMonitor for Prometheus scraping (`pg-cluster-monitoring.yaml`)
- Prometheus RBAC (`pg-cluster-prometheus-rbac.yaml`)
- Grafana dashboard (`cnpg-grafana-dashboard.json`)
