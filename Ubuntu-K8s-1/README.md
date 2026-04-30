# Ubuntu-K8s-1

Systemd mount units for VMware shared folders on the Kubernetes node (`macstation-ubuntu-1`). These mount host-level directories into the VM so that pods can access them via `hostPath` volumes.

## Prerequisites

- VMware Fusion with shared folders enabled
- `open-vm-tools` installed on the guest VM

## Mount Units

| Unit File | Mount Point | Source |
|-----------|-------------|--------|
| `mnt-aneeshneelam.mount` | `/mnt/aneeshneelam` | User home directory |
| `mnt-External.mount` | `/mnt/External` | External storage drives |
| `mnt-Media.mount` | `/mnt/Media` | Shared media library |

All mounts use the `fuse.vmhgfs-fuse` filesystem type with `allow_other,umask=000,defaults` options, and are ordered before `snap.k8s.kubelet.service` to ensure volumes are ready when pods start.

## k3s kine snapshot

`k3s-kine-backup.{sh,service,timer}` take a daily online SQLite snapshot of the k3s kine datastore (`/var/lib/rancher/k3s/server/db/state.db`), gzip it, and write it to `/mnt/External/Backup/K8s/k3s-kine/` with 14-day retention. k3s with embedded SQLite has no built-in snapshot mechanism, so without this an unclean shutdown can require recovering the cluster from manifests.

The timer fires daily at 05:00 Asia/Kolkata (30 min before the Postgres backup CronJob).

## Deployment

Copy the mount units and enable them:

```bash
sudo cp mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount
```

Install the kine backup script and timer:

```bash
sudo install -m 0755 k3s-kine-backup.sh /usr/local/sbin/k3s-kine-backup.sh
sudo install -m 0644 k3s-kine-backup.service k3s-kine-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now k3s-kine-backup.timer
sudo systemctl start k3s-kine-backup.service  # one-off test run
```

Verify the mounts and timer:

```bash
systemctl status mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount
ls /mnt/aneeshneelam /mnt/External /mnt/Media
systemctl list-timers k3s-kine-backup.timer
ls /mnt/External/Backup/K8s/k3s-kine/
```

### Restore from a kine snapshot

```bash
sudo systemctl stop k3s
sudo mv /var/lib/rancher/k3s/server/db/state.db /var/lib/rancher/k3s/server/db/state.db.bad
sudo rm -f /var/lib/rancher/k3s/server/db/state.db-{shm,wal}
sudo gunzip -c /mnt/External/Backup/K8s/k3s-kine/kine-<TIMESTAMP>.db.gz \
  | sudo tee /var/lib/rancher/k3s/server/db/state.db >/dev/null
sudo chown root:root /var/lib/rancher/k3s/server/db/state.db
sudo chmod 600 /var/lib/rancher/k3s/server/db/state.db
sudo systemctl start k3s
```

## Post-Bootstrap Cluster Configuration

After bootstrapping the cluster, apply these tweaks:

### CoreDNS HPA

Scale the CoreDNS HPA minimum replicas to 3:

```bash
kubectl -n kube-system patch hpa ck-dns-coredns --patch '{"spec":{"minReplicas":3}}'
```

## Usage

Services that use these mounts:
- **Nextcloud** — external storage for shared and personal media (`/mnt/Media`)
- **Immich** — external libraries for photos and videos (`/mnt/Media`)
