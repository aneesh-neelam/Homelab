# NextCloud

NextCloud deployed via Helm chart with external PostgreSQL (CNPG) and Valkey for caching.

## Prerequisites

- PostgreSQL (CNPG operator) running in `postgresql` namespace
- Valkey running in `valkey` namespace
- kubernetes-replicator running in `kube-system` namespace
- Prometheus operator running in `monitoring` namespace
- VMware Shared Folders mounted on the node (see [Ubuntu-K8s-1](../../Ubuntu-K8s-1/))

## Deployment

### 1. Create the namespace

```bash
kubectl apply -f namespace.yaml
```

### 2. Create the database and credentials

Follow the NextCloud section in the [PostgreSQL README](../PostgreSQL/README.md#nextcloud) to create the database, role, and credentials.

### 3. Create the admin credentials

```bash
kubectl -n nextcloud create secret generic nextcloud-admin-credentials \
  --from-literal=username=admin \
  --from-literal=password=$(openssl rand -base64 12 | head -c 16)
```

Retrieve the generated password:

```bash
kubectl -n nextcloud get secret nextcloud-admin-credentials \
  -o jsonpath='{.data.password}' | base64 -d
```

### 4. Apply Prometheus RBAC

```bash
kubectl apply -f nextcloud-prometheus-rbac.yaml
```

### 5. Create the Grafana dashboard ConfigMap

```bash
kubectl -n monitoring create configmap nextcloud-grafana-dashboard \
  --from-file=nextcloud-dashboard.json=nextcloud-grafana-dashboard.json
```

Then re-apply the Grafana deployment to mount the new dashboard:

```bash
kubectl apply -f ../Monitoring/grafana.yaml
```

### 6. Deploy NextCloud

```bash
helm repo add nextcloud https://nextcloud.github.io/helm/
helm install nextcloud nextcloud/nextcloud \
  -n nextcloud \
  -f values.yaml
```

### 7. Reset admin password

After the first install, reset the admin password to match the secret:

```bash
ADMIN_PASS=$(kubectl -n nextcloud get secret nextcloud-admin-credentials -o jsonpath='{.data.password}' | base64 -d)
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  bash -c "export OC_PASS='$ADMIN_PASS' && su -s /bin/bash www-data -c 'php /var/www/html/occ user:resetpassword --password-from-env admin'"
```

### 8. Configure external storage

Enable the External Storage app and import the storage configuration:

```bash
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  bash -c "su -s /bin/bash www-data -c 'php /var/www/html/occ app:enable files_external'"

kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  bash -c "su -s /bin/bash www-data -c 'php /var/www/html/occ files_external:import /dev/stdin'" < external-storage.json
```

Verify the mounts:

```bash
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- \
  bash -c "su -s /bin/bash www-data -c 'php /var/www/html/occ files_external:list'"
```

## External Storage Mounts

### Shared (all users)

| Mount Point | Node Path |
|-------------|-----------|
| /Shared Pictures | /mnt/Media/Personal Media/Pictures |
| /Shared Videos | /mnt/Media/Personal Media/Videos |
| /Shared Documents | /mnt/Media/Personal Media/Documents |

### Personal (user-specific)

| Mount Point | Node Path | User |
|-------------|-----------|------|
| /Personal Pictures | /mnt/Media/Personal Media/Nextcloud/Aneesh/Pictures | aneeshneelam |
| /Personal Videos | /mnt/Media/Personal Media/Nextcloud/Aneesh/Videos | aneeshneelam |
| /Personal Documents | /mnt/Media/Personal Media/Nextcloud/Aneesh/Documents | aneeshneelam |
| /Personal Pictures | /mnt/Media/Personal Media/Nextcloud/Arushi/Pictures | arushipurohit12 |
| /Personal Videos | /mnt/Media/Personal Media/Nextcloud/Arushi/Videos | arushipurohit12 |
| /Personal Documents | /mnt/Media/Personal Media/Nextcloud/Arushi/Documents | arushipurohit12 |

## Services

| Service | Port | NodePort |
|---------|------|----------|
| NextCloud | 8080 | 31080 |

## External Dependencies

| Dependency | Service | Namespace |
|------------|---------|-----------|
| PostgreSQL | pg-cluster-rw.postgresql.svc.cluster.local:5432 | postgresql |
| Valkey | valkey.valkey.svc.cluster.local:6379 | valkey |
