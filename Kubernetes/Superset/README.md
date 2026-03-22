# Apache Superset

Apache Superset deployed as raw Kubernetes manifests with external PostgreSQL (CNPG) for metadata and Valkey for caching. Superset has read access to all PostgreSQL databases for data exploration. Database connections are provisioned automatically via the init container.

## Prerequisites

- PostgreSQL (CNPG operator) running in `postgresql` namespace
- Valkey running in `valkey` namespace
- kubernetes-replicator running in `kube-system` namespace

## Deployment

### 1. Create the database credentials secret

```bash
kubectl -n postgresql create secret generic superset-db-credentials \
  --from-literal=username=superset \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=superset
```

Then add the replicator annotations:

```bash
kubectl -n postgresql annotate secret superset-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="superset" \
  replicator.v1.mittwald.de/replicate-to="superset"
```

### 2. Apply the updated PostgreSQL cluster (adds the superset role)

```bash
kubectl apply -f ../PostgreSQL/pg-cluster.yaml
```

### 3. Run the create-databases job (creates the superset DB and grants read access)

```bash
kubectl delete job pg-create-databases -n postgresql --ignore-not-found
kubectl apply -f ../PostgreSQL/create-databases-job.yaml
```

### 4. Create the Superset secret key

```bash
kubectl -n superset create secret generic superset-secret-key \
  --from-literal=secret-key=$(openssl rand -base64 42)
```

### 5. Deploy Superset

```bash
kubectl apply -f superset.yaml
```

### 6. Create an admin user

Once the pod is running:

```bash
kubectl -n superset exec deploy/superset -c superset -- \
  sh -c "export PYTHONPATH=/tmp/pip-packages:\$PYTHONPATH && \
  superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@localhost \
  --password admin"
```

Change the password after first login.

## Database Connections

The following read-only PostgreSQL connections are provisioned automatically by the init container via `superset set-database-uri`:

| Name | Database | Endpoint |
|------|----------|----------|
| PostgreSQL - nextcloud | nextcloud | pg-cluster-ro:5432 |
| PostgreSQL - currency_exchange_rates | currency_exchange_rates | pg-cluster-ro:5432 |
| PostgreSQL - openwebui | openwebui | pg-cluster-ro:5432 |
| PostgreSQL - superset | superset | pg-cluster-ro:5432 |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Superset | 8088 | 30088 |

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| PostgreSQL (metadata) | pg-cluster-rw.postgresql.svc.cluster.local:5432 | postgresql |
| PostgreSQL (read-only queries) | pg-cluster-ro.postgresql.svc.cluster.local:5432 | postgresql |
| Valkey | valkey.valkey.svc.cluster.local:6379 | valkey |
