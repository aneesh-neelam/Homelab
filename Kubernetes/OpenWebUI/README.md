# Open WebUI

Open WebUI deployed via Kubernetes manifests for running LLMs locally. Connects to Ollama running on the host machine, with PostgreSQL for persistence, pgvector for embeddings, and Valkey for caching/WebSocket.

## Prerequisites

- PostgreSQL (CNPG operator) running in `postgresql` namespace
- Valkey running in `valkey` namespace
- kubernetes-replicator running in `kube-system` namespace
- Prometheus operator running in `monitoring` namespace
- Ollama running on the host machine (192.168.213.1:11434)

## Deployment

### 1. Create the database and credentials

#### Create the secret

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

#### Add the role to the CNPG cluster

Add the following to the `managed.roles` section in `../PostgreSQL/pg-cluster.yaml`:

```yaml
- name: openwebui
  ensure: present
  login: true
  createdb: false
  superuser: false
  passwordSecret:
    name: openwebui-db-credentials
```

Apply the updated cluster:

```bash
kubectl apply -f ../PostgreSQL/pg-cluster.yaml
```

#### Create the database and extensions

Add the following lines to `../PostgreSQL/create-databases-job.yaml`:

```bash
psql -h pg-cluster-rw -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'openwebui'" | grep -q 1 || psql -h pg-cluster-rw -U postgres -c "CREATE DATABASE openwebui OWNER openwebui;"
psql -h pg-cluster-rw -U postgres -d openwebui -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

Run the job:

```bash
kubectl delete job pg-create-databases -n postgresql --ignore-not-found
kubectl apply -f ../PostgreSQL/create-databases-job.yaml
```

### 2. Apply Prometheus RBAC

```bash
kubectl apply -f open-webui-prometheus-rbac.yaml
```

### 3. Deploy Open WebUI

```bash
kubectl apply -f open-webui.yaml
```

## Resource Allocation

| Container | CPU Request | CPU Limit | Memory (Request = Limit) |
|-----------|------------|-----------|--------------------------|
| Open WebUI | 500m | 2 | 1536Mi |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Open WebUI | 8080 | 30180 |

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| PostgreSQL | pg-cluster-rw.postgresql.svc.cluster.local:5432 | postgresql |
| Valkey | valkey.valkey.svc.cluster.local:6379 | valkey |
| Ollama | 192.168.213.1:11434 | Host machine |
