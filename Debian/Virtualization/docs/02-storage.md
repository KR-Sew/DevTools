# 02 — Storage layout

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

The reference host separates the root filesystem, Docker, fast KVM storage, backups, and LXD thin storage.

## Inspect first

Never create or format storage until you have identified existing PVs/VGs/LVs.

```bash
lsblk -f
sudo pvs
sudo vgs
sudo lvs -a -o +devices,data_percent,metadata_percent
```

Reference layout:

```text
VG_SSD/lv_root     ext4 -> /
VG_SSD/lv_docker   XFS  -> /var/lib/docker
VG_SSD/lv_fastvm   XFS  -> /fast-vm
vg_backup/lv_backup XFS -> /backup
vg_vm/thinpool     LVM thin -> LXD vmstore
```

## XFS labels

An existing XFS filesystem can be labeled while unmounted with `xfs_admin`, or using `xfs_db`/supported tooling as appropriate. Check first:

```bash
sudo xfs_admin -l /dev/vg_backup/lv_backup
```

Do not confuse the filesystem label with the LVM LV name.

## Thin pool health

```bash
sudo lvs -a vg_vm
sudo lvs -o lv_name,lv_attr,segtype vg_vm
sudo systemctl status lvm2-monitor --no-pager
```

A healthy active thin pool in the tested system appeared as:

```text
thinpool  twi-aotz--  thin-pool
```

Install the thin provisioning utilities if LVM says `thin_check` is missing:

```bash
sudo apt install -y thin-provisioning-tools
```

## Persistent mounts

Use stable UUIDs or mapper paths in `/etc/fstab`. Verify without rebooting:

```bash
sudo mount -a
findmnt /fast-vm
findmnt /var/lib/docker
findmnt /backup
```

Then validate again after a physical reboot.

---

[Next 🔜`03-networking`](./03-networking.md)

---
🔙 [back to the **Repo**](../)
