# 01 — Base Debian 13 host

Start with a current Debian 13 installation and verify the host before changing storage or networking.

```bash
cat /etc/os-release
uname -a
sudo apt update
sudo apt full-upgrade
```

Useful baseline packages:

```bash
sudo apt install -y \
  curl wget ca-certificates gnupg jq git vim nano \
  iproute2 bridge-utils tcpdump lsof \
  lvm2 thin-provisioning-tools xfsprogs
```

`thin-provisioning-tools` is important when LVM thin pools are used; without it LVM can report that `/usr/sbin/thin_check` is missing.

Inspect hardware virtualization:

```bash
lscpu | grep -E 'Virtualization|Model name'
grep -Eoc '(vmx|svm)' /proc/cpuinfo
lsmod | grep kvm
ls -l /dev/kvm
```

The tested Intel host reported VT-x and loaded `kvm_intel` + `kvm`.
