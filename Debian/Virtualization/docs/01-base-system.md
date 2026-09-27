# 01 — Base Debian 13 host

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

Start with a current **Debian 13** installation and verify the host before changing storage or networking.

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

`thin-provisioning-tools` is important when **LVM** thin pools are used; without it **LVM** can report that `/usr/sbin/thin_check` is missing.

Inspect hardware virtualization:

```bash
lscpu | grep -E 'Virtualization|Model name'
grep -Eoc '(vmx|svm)' /proc/cpuinfo
lsmod | grep kvm
ls -l /dev/kvm
```

The tested Intel host reported VT-x and loaded `kvm_intel` + `kvm`.

---

🔙 [back to the **Repo**](../)