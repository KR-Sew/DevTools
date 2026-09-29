# 09 — Final validation

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

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

---

[Next 🔜`troubleshooting`](./troubleshooting.md)

---
🔙 [back to the **Repo**](../)
