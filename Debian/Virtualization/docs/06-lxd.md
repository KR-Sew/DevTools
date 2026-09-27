# 06 — LXD 5.21 LTS

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
