# Debian 13 Virtualization Host

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![LXC/LXD](https://custom-icon-badges.demolab.com/badge/LXC_LXD-Containers-607078?style=flat&logo=lxd-lxc_logo&logoColor=grey&logoSize=auto&labelColor=grey)](https://documentation.ubuntu.com/lxd/stable-5.21/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

A tested, reusable How-To for building a **Debian 13** host that runs **Docker**, **LXD 5.21 LTS**, and **KVM/QEMU with libvirt** side-by-side.

The reference deployment was validated through a full physical-host reboot and guest connectivity tests. Adapt interface names, IP addresses, volume groups, and paths to your environment.

## Reference architecture

```text
Debian 13 host
├── Networking
│   ├── br0 -> eno2 : management, 10.100.100.251/24, GW 10.100.100.254
│   └── br1 -> eno1 : Layer-2 guest bridge, external DHCP (10.10.200.0/24)
├── Docker
│   └── /var/lib/docker -> XFS -> VG_SSD/lv_docker
├── LXD 5.21 LTS (snap)
│   ├── vmstore -> vg_vm/thinpool (LVM thin)
│   └── default NIC -> br1
├── KVM/QEMU + libvirt
│   ├── q35 + OVMF/UEFI
│   ├── CPU host-passthrough
│   ├── VirtIO NIC -> br1
│   ├── qcow2 disks -> /fast-vm/images
│   └── qemu-guest-agent
├── /fast-vm -> XFS -> VG_SSD/lv_fastvm
└── /backup  -> XFS -> vg_backup/lv_backup
```

## Repository map

| Document | Purpose |
|---|---|
| [01-base-system](docs/01-base-system.md) | Packages and host preparation |
| [02-storage](docs/02-storage.md) | `LVM`, `XFS`, `LVM-thin` and mount layout |
| [03-networking](docs/03-networking.md) | Management and guest **Linux** bridges |
| [04-dns](docs/04-dns.md) | Resolver configuration and recovery |
| [05-docker](docs/05-docker.md) | **Docker** storage and log rotation |
| [06-lxd](docs/06-lxd.md) | `LXD` 5.21 LTS, `LVM-thin` and `br1` |
| [07-kvm-libvirt](docs/07-kvm-libvirt.md) | `KVM`/`QEMU`/`libvirt` foundation |
| [08-create-kvm-vm](docs/08-create-kvm-vm.md) | Create a modern Debian VM |
| [09-validation](docs/09-validation.md) | Post-reboot validation |
| [Troubleshooting](docs/troubleshooting.md) | Problems encountered in the tested build |

Example configuration files live under `configs/`; reusable checks and VM creation helpers live under `scripts/`.

## Recommended build order

1. Install/update **Debian 13** and baseline tools.
2. Prepare **LVM/XFS** storage and verify persistent mounts.
3. Configure `br0` and `br1`.
4. Verify routing and DNS before installing higher layers.
5. Configure **Docker** and its dedicated filesystem.
6. Install **LXD 5.21 LTS** and attach the existing **LVM** thin pool.
7. Install/validate `KVM`, `QEMU`, `libvirt`, `OVMF` and swtpm.
8. Define libvirt directory/ISO pools and create a test VM.
9. Reboot the physical host and run `scripts/check-host.sh`.

## Important design rules

- Put the management `IP` on the **bridge**, not on its enslaved physical `NIC`.
- A pure guest bridge such as `br1` does not need a host **IPv4** address.
- Let an external router/DHCP server serve guests on `br1` when using a real **Layer-2 LAN**.
- Keep **Docker** data on its own filesystem when possible.
- Do not let libvirt and **LXD** independently manage the same `vg_vm` as storage. In this design, `vg_vm/thinpool` belongs to **LXD**; **KVM** disks use `/fast-vm`.
- For modern x86 guests, use `q35` + `UEFI/OVMF` + `VirtIO` unless compatibility requirements dictate otherwise.

## Quick health check

```bash
sudo ./scripts/check-host.sh
```

## Reference values

These values describe the tested machine and are examples, not requirements:

```text
Management bridge: br0 -> eno2
Management IP:     10.100.100.251/24
Gateway:           10.100.100.254
Guest bridge:      br1 -> eno1
Guest network:     10.10.200.0/24 (external DHCP)
Docker LV:         VG_SSD/lv_docker
KVM filesystem:    VG_SSD/lv_fastvm -> /fast-vm
LXD VG/thinpool:   vg_vm/thinpool
Backup LV:         vg_backup/lv_backup -> /backup
```
---

🔙 [back to Repos](https://github.com/KR-Sew?tab=repositories)
