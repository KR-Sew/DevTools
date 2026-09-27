# Troubleshooting notes from the tested build

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

## `thin_check: No such file or directory`

Install:

```bash
sudo apt install -y thin-provisioning-tools
```

Then re-check the thin pool rather than recreating it.

## LXD says the VG is already used

Example:

```text
Error: Volume group "vg_vm" is already used by LXD
```

Stop. Inspect VG tags and both old/new LXD state before creating anything:

```bash
sudo vgs -o vg_name,vg_tags vg_vm
sudo lvs -a vg_vm
lxc storage list
```

Do not format a VG merely because the new LXD database initially shows no pool.

## Snap LXD installed but `lxc` is not found

Verify:

```bash
/snap/bin/lxc --version
```

Add `/snap/bin` to login PATH, for example `/etc/profile.d/snap-path.sh`:

```bash
export PATH="$PATH:/snap/bin"
```

## LXD 5.0 package versus 5.21 snap

Debian 13 may provide an older distro LXD package while Canonical's 5.21 LTS is available as a snap. Treat migration as a stateful operation: identify `/var/lib/lxd`, `/var/snap/lxd/common/lxd`, storage ownership, profiles and VG tags before removing or recreating anything.

## Guest on `br1` receives no DHCP

Check all layers:

```bash
ip -br link
/usr/sbin/bridge link show
sudo tcpdump -ni br1 'udp port 67 or udp port 68'
```

Also check the upstream switch/router. In the reference deployment the host configuration was correct, but the MikroTik port connected to `eno1` had not been placed in the intended bridge.

## `systemd-resolved.service not found`

Do not assume Debian has `systemd-resolved` installed. Inspect `/etc/resolv.conf` ownership/symlink and current resolver first. If DNS is already broken, fix temporary resolution before relying on `apt` to install resolver packages.

## `virt-install`: OS name required

Modern virt-install requires OS metadata. List identifiers:

```bash
virt-install --osinfo list
```

Use an exact supported OS identifier or a suitable generic value such as `linux2024` when appropriate.

## UEFI says no bootable device

Inspect both firmware and media:

```bash
virsh dumpxml VM | sed -n '/<os /,/<\/os>/p'
virsh domblklist VM --details
```

Confirm the ISO is actually attached and is UEFI bootable. The reference Debian ISO contained `EFI/debian/grub.cfg` and `boot/grub/efi.img`.

## VM keeps booting the installer after eject

`--config` modifies persistent configuration only:

```bash
virsh change-media VM sda --eject --config
```

Check both views:

```bash
virsh domblklist VM
virsh domblklist VM --inactive
```

Then fully stop the guest and start it again. `virsh shutdown` only requests shutdown; it does not wait:

```bash
virsh shutdown VM
watch -n1 virsh domstate VM
```

`virsh destroy VM` is a hard power-off, **not deletion**. `virsh undefine VM` removes the VM definition and is a very different operation.

## `bridge: command not found` although iproute2 is installed

On Debian the binary can be under `/usr/sbin`, which may not be in an unprivileged user's PATH:

```bash
/usr/sbin/bridge link show
```

## `qemu-guest-agent` says it cannot be enabled

Some Debian guest-agent units are activation-driven and intentionally lack `[Install]` metadata. Do not judge agent health from `systemctl enable` alone. Test it from the host:

```bash
virsh domifaddr VM --source agent
virsh qemu-agent-command VM '{"execute":"guest-ping"}'
```

---

🔙 [back to the **Repo**](../)
