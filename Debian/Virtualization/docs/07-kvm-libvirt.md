# 07 — KVM/QEMU and libvirt

Reference versions at validation time included QEMU 10.0.x and libvirt 11.3.x from Debian 13.

## Packages

```bash
sudo apt install -y \
  qemu-system-x86 qemu-utils qemu-block-extra \
  libvirt-daemon-system libvirt-clients \
  virtinst ovmf swtpm swtpm-tools
```

Add the administrator to the appropriate groups if needed:

```bash
sudo usermod -aG libvirt,kvm "$USER"
```

Log out/in after group changes.

## Validate KVM

```bash
sudo virt-host-validate qemu
virsh -c qemu:///system list --all
virsh -c qemu:///system nodeinfo
```

The secure-guest capability warning can be platform-specific; the essential KVM/device/cgroup/IOMMU checks passed on the reference host.

## Fast VM pool

```bash
sudo mkdir -p /fast-vm/images
sudo chown libvirt-qemu:libvirt-qemu /fast-vm/images
sudo chmod 0750 /fast-vm/images

virsh pool-define-as fast-vm dir --target /fast-vm/images
virsh pool-start fast-vm
virsh pool-autostart fast-vm
```

If the pool already exists, inspect it instead of redefining it:

```bash
virsh pool-info fast-vm
virsh pool-dumpxml fast-vm
```

## Do not duplicate LXD storage

Do not define `vg_vm` as an ordinary libvirt logical pool when it is already the backing VG for LXD's `vmstore`. The reference build removed that duplicate libvirt view and left ownership with LXD.

## Firmware

Inspect OVMF files:

```bash
find /usr/share/OVMF -maxdepth 1 -type f -printf '%f\n' | sort
```

Modern guests use q35 + UEFI/OVMF in this guide.
