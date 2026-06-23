# Ubuntu-K8s-2

Host-level configuration for `macstation-ubuntu-2`, the second Ubuntu K8s node in the homelab.

## DNS / Tailscale

Tailscale MagicDNS manages `/etc/resolv.conf` on this machine but provides no upstream resolvers when the Tailscale admin console sends no global nameservers. Without a `FallbackDNS` configured in systemd-resolved, host DNS breaks whenever `tailscaled` restarts and the coordination server does not push resolvers.

The fix has two parts:
1. Ensure `/etc/resolv.conf` is a symlink to systemd-resolved's stub so Tailscale uses its `resolved` DNS manager.
2. Set `FallbackDNS` so external DNS works even if the admin console pushes no resolvers.

### Deployment

Install the FallbackDNS drop-in:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo cp 99-fallback.conf /etc/systemd/resolved.conf.d/
```

Ensure the `resolv.conf` symlink is in place (should already be correct on this machine, but verify after re-provisioning):

```bash
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

Restart both services:

```bash
sudo systemctl restart systemd-resolved
sudo systemctl restart tailscaled
```

Verify:

```bash
ls -la /etc/resolv.conf                                     # symlink to stub-resolv.conf
resolvectl status | grep -E "resolv.conf mode|Fallback"     # mode: stub, FallbackDNS present
getent hosts ports.ubuntu.com                               # external DNS works
getent hosts macstation-ubuntu-1.tail3b06f0.ts.net          # MagicDNS works
```
