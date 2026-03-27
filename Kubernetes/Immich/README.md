# Immich

Immich deployed via Kubernetes manifests with external PostgreSQL (CNPG) and Valkey for caching. Shares media directories with Nextcloud via hostPath volumes and Immich External Libraries.

## Prerequisites

- PostgreSQL (CNPG operator) running in `postgresql` namespace with the VectorChord image (see [PostgreSQL changes](#postgresql-changes) below)
- Valkey running in `valkey` namespace
- kubernetes-replicator running in `kube-system` namespace
- Prometheus operator running in `monitoring` namespace
- VMware Shared Folders mounted on the node (see [Ubuntu-K8s-1](../../Ubuntu-K8s-1/))

## PostgreSQL Changes

Immich requires the **VectorChord** extension (successor to pgvecto.rs, required since Immich v1.133.0), which depends on **pgvector**. These are compiled C extensions that must be present in the PostgreSQL image — they cannot be installed at runtime on a vanilla image.

### Switch the CNPG cluster image

Replace the CNPG cluster image with TensorChord's CNPG-compatible image that includes VectorChord + pgvector. This is a drop-in replacement — all existing databases (Nextcloud, OpenWebUI, Superset, etc.) will continue to work without changes.

In `pg-cluster.yaml`, add `imageName` and `shared_preload_libraries` to the spec, and add `postInitSQL` to bootstrap the extension for new databases:

```yaml
spec:
  imageName: ghcr.io/tensorchord/cloudnative-vectorchord:18.3-1.1.1

  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"
    shared_preload_libraries:
      - "vchord.so"

```

Apply the updated cluster:

```bash
kubectl apply -f ../PostgreSQL/pg-cluster.yaml
```

CNPG will perform a rolling update of the PostgreSQL instances.

## Deployment

### 1. Create the namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Create the database and credentials

#### Create the secret

```bash
kubectl -n postgresql create secret generic immich-db-credentials \
  --from-literal=username=immich \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16) \
  --from-literal=database=immich

kubectl -n postgresql annotate secret immich-db-credentials \
  replicator.v1.mittwald.de/replication-allowed="true" \
  replicator.v1.mittwald.de/replication-allowed-namespaces="immich" \
  replicator.v1.mittwald.de/replicate-to="immich"
```

Replicated automatically to the `immich` namespace by kubernetes-replicator.

#### Add the role to the CNPG cluster

Add the following to the `managed.roles` section in `../PostgreSQL/pg-cluster.yaml`:

```yaml
- name: immich
  ensure: present
  login: true
  createdb: false
  superuser: false
  passwordSecret:
    name: immich-db-credentials
```

Apply the updated cluster:

```bash
kubectl apply -f ../PostgreSQL/pg-cluster.yaml
```

#### Create the database and extensions

Add the following lines to `../PostgreSQL/create-databases-job.yaml`:

```bash
psql -h pg-cluster-rw -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'immich'" | grep -q 1 || psql -h pg-cluster-rw -U postgres -c "CREATE DATABASE immich OWNER immich;"
psql -h pg-cluster-rw -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS vchord CASCADE;"
psql -h pg-cluster-rw -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS cube;"
psql -h pg-cluster-rw -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS earthdistance;"
```

Run the job:

```bash
kubectl delete job pg-create-databases -n postgresql --ignore-not-found
kubectl apply -f ../PostgreSQL/create-databases-job.yaml
```

Retrieve the generated password:

```bash
kubectl -n postgresql get secret immich-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d
```

### 3. Apply Prometheus RBAC

```bash
kubectl apply -f immich-prometheus-rbac.yaml
```

### 4. Create the Grafana dashboard ConfigMap

```bash
kubectl -n monitoring create configmap immich-grafana-dashboard \
  --from-file=immich-dashboard.json=immich-grafana-dashboard.json
```

Then re-apply the Grafana deployment to mount the new dashboard:

```bash
kubectl apply -f ../Monitoring/grafana.yaml
```

### 5. Deploy Immich

```bash
kubectl apply -f immich.yaml
```

### 6. Configure External Libraries

After Immich is running and you have created user accounts, configure External Libraries in the Immich web UI to index the shared media directories.

Go to **Administration > External Libraries** and create libraries pointing to the mounted paths:

#### Shared (all users)

| Library Path | Description |
|-------------|-------------|
| `/mnt/Shared/Pictures` | Shared Pictures (same as Nextcloud /Shared Pictures) |
| `/mnt/Shared/Videos` | Shared Videos (same as Nextcloud /Shared Videos) |

#### Personal (user-specific)

| Library Path | Immich User | Nextcloud User |
|-------------|-------------|----------------|
| `/mnt/Personal/Aneesh/Pictures` | aneeshneelam | aneeshneelam |
| `/mnt/Personal/Aneesh/Videos` | aneeshneelam | aneeshneelam |
| `/mnt/Personal/Arushi/Pictures` | arushipurohit12 | arushipurohit12 |
| `/mnt/Personal/Arushi/Videos` | arushipurohit12 | arushipurohit12 |

Set a library scan interval (e.g., every 15 minutes) or trigger scans manually to keep Immich in sync with files added via Nextcloud.

> **Important:** External Libraries are read-only in Immich. Photos managed by Immich's own upload will be stored separately in its PVC. Files added via Nextcloud will appear in Immich after the next library scan, and vice versa — files visible in Immich's external libraries are the same files on disk that Nextcloud serves.

## Shared Media Architecture

Both Immich and Nextcloud mount the same node-level directories via `hostPath` volumes. The VMware shared folder `/mnt/Media` is the single source of truth.

```
Node: /mnt/Media/Personal Media/
├── Pictures/                    <- Shared Pictures
├── Videos/                      <- Shared Videos
├── Documents/                   <- Shared Documents (Nextcloud only)
└── Users/
    ├── Aneesh/
    │   ├── Pictures/            <- Personal Pictures (aneeshneelam)
    │   └── Videos/              <- Personal Videos (aneeshneelam)
    └── Arushi/
        ├── Pictures/            <- Personal Pictures (arushipurohit12)
        └── Videos/              <- Personal Videos (arushipurohit12)
```

| Directory | Nextcloud | Immich |
|-----------|-----------|--------|
| Shared Pictures | /Shared Pictures (external storage) | External Library |
| Shared Videos | /Shared Videos (external storage) | External Library |
| Shared Documents | /Shared Documents (external storage) | N/A |
| Personal Pictures | /Personal Pictures (per-user external storage) | External Library (per-user) |
| Personal Videos | /Personal Videos (per-user external storage) | External Library (per-user) |

## Resource Allocation

| Container | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|------------|-----------|----------------|--------------|
| Immich Server | 500m | 2 | 1Gi | 1Gi |
| Immich Machine Learning | 500m | 2 | 2Gi | 4Gi |

The ML container needs more memory as it loads models for face recognition and smart search. It spikes during the initial library scan but is mostly idle afterwards.

## Services

| Service | Port | NodePort |
|---------|------|----------|
| Immich Server | 2283 | 31283 |

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| PostgreSQL | pg-cluster-rw.postgresql.svc.cluster.local:5432 | postgresql |
| Valkey | valkey.valkey.svc.cluster.local:6379 | valkey |
