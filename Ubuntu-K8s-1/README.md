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

## Deployment

Copy the mount units and enable them:

```bash
sudo cp mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount
```

Verify the mounts:

```bash
systemctl status mnt-aneeshneelam.mount mnt-External.mount mnt-Media.mount
ls /mnt/aneeshneelam /mnt/External /mnt/Media
```

## Usage

Services that use these mounts:
- **Nextcloud** — external storage for shared and personal media (`/mnt/Media`)
- **Immich** — external libraries for photos and videos (`/mnt/Media`)
