# 08 — Create a KVM VM

The tested Debian 13 VM used:

```text
Machine:       q35
Firmware:      UEFI/OVMF
CPU:           host-passthrough
Disk:          qcow2 on fast-vm
NIC:           VirtIO on br1
Display:       SPICE bound to localhost
Guest agent:   qemu-guest-agent
```

## ISO pool

Keep installation media under a readable directory such as `/backup/iso` and optionally expose it as a libvirt directory pool named `iso`.

```bash
sudo mkdir -p /backup/iso
sudo chmod 0755 /backup/iso
```

## OS information

Modern `virt-install` requires an OS name. Inspect supported names:

```bash
virt-install --osinfo list | less
```

If exact Debian 13 metadata is unavailable, use an appropriate supported generic/fallback value rather than disabling OS information silently.

## Example

Use `scripts/create-kvm-vm.sh` or adapt this pattern:

```bash
virt-install \
  --name deb13-kvm \
  --memory 4096 \
  --vcpus 4 \
  --cpu host-passthrough \
  --machine q35 \
  --boot uefi \
  --disk path=/fast-vm/images/deb13-kvm.qcow2,size=20,format=qcow2,bus=virtio \
  --cdrom /backup/iso/deb13-netinstall.iso \
  --network bridge=br1,model=virtio \
  --graphics spice,listen=127.0.0.1 \
  --osinfo detect=on,name=linux2024
```

Use the actual OS-info identifier available on your host.

## Remote SPICE over SSH

From a workstation:

```powershell
ssh -N -L 5900:127.0.0.1:5900 user@HOST
```

Then connect Remote Viewer to:

```text
spice://127.0.0.1:5900
```

Check the actual port first:

```bash
virsh domdisplay deb13-kvm
```

## After installation

Eject the ISO from persistent configuration:

```bash
virsh change-media deb13-kvm sda --eject --config
```

Remember: `--config` changes the next-start configuration, not necessarily the currently running QEMU instance. Shut the guest down fully and start it again, or use the appropriate live operation when applicable.

`virsh shutdown` is asynchronous:

```bash
virsh shutdown deb13-kvm
watch -n1 virsh domstate deb13-kvm
```

After `shut off`:

```bash
virsh domblklist deb13-kvm --inactive
virsh start deb13-kvm
```

## Guest agent

Inside Debian:

```bash
sudo apt install -y qemu-guest-agent
sudo systemctl status qemu-guest-agent
```

On Debian 13 the service may be activation-driven and not meant to be manually enabled. Validate from the host instead:

```bash
virsh domifaddr deb13-kvm --source agent
virsh qemu-agent-command deb13-kvm '{"execute":"guest-ping"}'
```

## Autostart

```bash
virsh autostart deb13-kvm
virsh dominfo deb13-kvm | grep -E 'State|Autostart'
```
