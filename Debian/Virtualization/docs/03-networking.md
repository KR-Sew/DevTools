# 03 — Host networking

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
