# 06 — LXD 5.21 LTS

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

The reference build moved from Debian's older LXD package to Canonical's LXD 5.21 LTS snap.

## Install snapd and LXD

```bash
sudo apt install -y snapd
sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null || true
sudo snap install lxd --channel=5.21/stable
/snap/bin/lxc --version
```

If `/snap/bin` is not in PATH, add `/etc/profile.d/snap-path.sh`:

```bash
export PATH="$PATH:/snap/bin"
```

Then:

```bash
source /etc/profile.d/snap-path.sh
hash -r
lxc --version
```

## Existing LVM thin pool

Reference storage:

```text
VG:       vg_vm
Thinpool: thinpool
LXD pool: vmstore
```

Check before attaching it:

```bash
sudo vgs -o vg_name,vg_tags vg_vm
sudo lvs -a vg_vm
```

The tested VG carried the LXD tag `lxd_pool`. Do **not** format or recreate a VG that already contains LXD-managed storage.

A resulting storage definition looked like:

```yaml
name: vmstore
driver: lvm
config:
  lvm.thinpool_name: thinpool
  lvm.vg_name: vg_vm
  source: vg_vm
```

## Default profile

```yaml
config: {}
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: br1
    type: nic
  root:
    path: /
    pool: vmstore
    type: disk
```

Inspect with:

```bash
lxc profile show default
lxc storage show vmstore
```

## Functional test

```bash
lxc launch images:debian/13 deb13-test
lxc list
lxc exec deb13-test -- ip -br a
lxc exec deb13-test -- ip route
lxc exec deb13-test -- ping -c3 1.1.1.1
lxc exec deb13-test -- getent ahostsv4 deb.debian.org
lxc exec deb13-test -- apt update
```

The reference container received `10.10.200.100/24` from the external DHCP server via `br1`.

Snapshot/restore test:

```bash
lxc snapshot deb13-test clean-install
lxc exec deb13-test -- bash -c 'echo test > /root/snapshot-test.txt'
lxc restore deb13-test clean-install
lxc exec deb13-test -- test ! -e /root/snapshot-test.txt
```

Clean up:

```bash
lxc delete deb13-test --force
```

Cached image volumes may remain; that is normal.

---

🔙 [back to the **Repo**](../)
