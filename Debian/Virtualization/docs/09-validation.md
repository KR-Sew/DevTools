# 09 — Final validation

The reference deployment was considered complete only after a physical-host reboot.

Run:

```bash
sudo reboot
```

After reconnecting:

```bash
# Networking
ip -br addr
ip route

# Storage
findmnt /fast-vm
findmnt /var/lib/docker
findmnt /backup
sudo lvs -a

# Docker
systemctl is-active docker
docker info | grep -E 'Storage Driver|Logging Driver'

# LXD
lxc storage list
lxc network list
lxc list

# KVM/libvirt
virsh pool-list --all
virsh list --all
virsh domifaddr deb13-kvm --source agent
```

The tested system returned:

- `br0` up with `10.100.100.251/24` and default route via `10.100.100.254`.
- `br1` up without a host IPv4 address.
- `/fast-vm`, `/var/lib/docker`, and `/backup` mounted from their intended XFS LVs.
- LXD `vmstore` created on `vg_vm`.
- Docker active with `overlayfs` and `json-file` logging.
- libvirt `fast-vm` and `iso` pools active and autostarted.
- `deb13-kvm` automatically running.
- QEMU guest agent reporting `10.10.200.101/24` on the guest VirtIO NIC.

For repeated checks, run:

```bash
sudo ./scripts/check-host.sh
```
