# Currency Exchange Rates Sync

Kubernetes CronJob that syncs currency exchange rates into PostgreSQL. The application code and container image are maintained in a separate repository.

**Code Repository:** [aneesh-neelam/currency-exchange-rates-sync-job](https://github.com/aneesh-neelam/currency-exchange-rates-sync-job)

## Prerequisites

- PostgreSQL (CNPG operator) running in `postgresql` namespace
- kubernetes-replicator running in `kube-system` namespace

## Deployment

### 1. Create the namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Create the database and credentials

#### Create the secret

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

#### Add the role to the CNPG cluster

Add the following to the `managed.roles` section in `../PostgreSQL/pg-cluster.yaml`:

```yaml
- name: currencyexchangeratessync
  ensure: present
  login: true
  createdb: false
  superuser: false
  passwordSecret:
    name: currencyexchangeratessync-db-credentials
```

Apply the updated cluster:

```bash
kubectl apply -f ../PostgreSQL/pg-cluster.yaml
```

#### Create the database

Add the following line to `../PostgreSQL/create-databases-job.yaml`:

```bash
psql -h pg-cluster-rw -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'currency_exchange_rates'" | grep -q 1 || psql -h pg-cluster-rw -U postgres -c "CREATE DATABASE currency_exchange_rates OWNER currencyexchangeratessync;"
```

Run the job:

```bash
kubectl delete job pg-create-databases -n postgresql --ignore-not-found
kubectl apply -f ../PostgreSQL/create-databases-job.yaml
```

### 3. Deploy the CronJob

Follow the deployment instructions in the [code repository](https://github.com/aneesh-neelam/currency-exchange-rates-sync-job).

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| PostgreSQL | pg-cluster-rw.postgresql.svc.cluster.local:5432 | postgresql |
