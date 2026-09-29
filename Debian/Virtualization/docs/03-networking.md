# 03 — Host networking

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

The reference design uses two physical NICs and two Linux bridges.

```text
eno2 -> br0 -> management LAN
                 10.100.100.251/24
                 gateway 10.100.100.254

eno1 -> br1 -> guest/Lab LAN
                 no host IPv4 required
                 DHCP supplied by external router
```

See [`configs/network/interfaces.example`](../configs/network/interfaces.example).

## Core rule

Once a physical interface is enslaved to a bridge, configure the host IP on the bridge, not the physical NIC.

## Verify

```bash
   ip -br addr
   ip route
   /usr/sbin/bridge link show
```

Expected management route:

```text
   default via 10.100.100.254 dev br0
```

`br1` can legitimately show only a link-local IPv6 address. LXD/KVM guests connected to it behave like physical machines connected to that Layer-2 segment.

## External switch/router requirement

The physical port behind `eno1` must be in the correct upstream bridge/VLAN. During the reference deployment, DHCP failed until the corresponding MikroTik port was added to the correct bridge.

## Test guest DHCP traffic

```bash
   sudo tcpdump -ni br1 'udp port 67 or udp port 68'
```

---

[Next 🔜`04-dns`](./04-dns.md)

---
🔙 [back to the **Repo**](../)
