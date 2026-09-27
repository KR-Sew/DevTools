#!/usr/bin/env bash
set -euo pipefail

NAME=''
MEMORY=4096
VCPUS=4
DISK_SIZE=20
BRIDGE=br1
ISO=''
POOL=fast-vm
OSINFO=linux2024

usage(){
  cat <<USAGE
Usage: $0 --name NAME --iso /path/file.iso [options]

Options:
  --memory MB       RAM in MB (default: 4096)
  --vcpus N         vCPUs (default: 4)
  --disk GB         qcow2 virtual size in GB (default: 20)
  --bridge NAME     Linux bridge (default: br1)
  --pool NAME       libvirt directory pool (default: fast-vm)
  --osinfo NAME     virt-install OS info ID (default: linux2024)
  -h, --help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME=$2; shift 2;;
    --iso) ISO=$2; shift 2;;
    --memory) MEMORY=$2; shift 2;;
    --vcpus) VCPUS=$2; shift 2;;
    --disk) DISK_SIZE=$2; shift 2;;
    --bridge) BRIDGE=$2; shift 2;;
    --pool) POOL=$2; shift 2;;
    --osinfo) OSINFO=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

[[ -n "$NAME" && -n "$ISO" ]] || { usage; exit 1; }
[[ -r "$ISO" ]] || { echo "ISO not readable: $ISO" >&2; exit 1; }
command -v virt-install >/dev/null || { echo 'virt-install is required.' >&2; exit 1; }
virsh pool-info "$POOL" >/dev/null 2>&1 || { echo "Pool not found: $POOL" >&2; exit 1; }
ip link show "$BRIDGE" >/dev/null 2>&1 || { echo "Bridge not found: $BRIDGE" >&2; exit 1; }
virsh dominfo "$NAME" >/dev/null 2>&1 && { echo "Domain already exists: $NAME" >&2; exit 1; }

POOL_PATH=$(virsh pool-dumpxml "$POOL" | sed -n 's:.*<path>\(.*\)</path>.*:\1:p' | head -1)
[[ -n "$POOL_PATH" ]] || { echo "Cannot determine target path for pool $POOL" >&2; exit 1; }
DISK="$POOL_PATH/$NAME.qcow2"
[[ ! -e "$DISK" ]] || { echo "Disk already exists: $DISK" >&2; exit 1; }

cat <<SUMMARY
Creating VM
===========
Name:       $NAME
Memory:     ${MEMORY} MB
vCPUs:      $VCPUS
Machine:    q35
Firmware:   UEFI/OVMF
CPU:        host-passthrough
Disk:       $DISK (${DISK_SIZE}G qcow2)
Bridge:     $BRIDGE (virtio)
ISO:        $ISO
OS info:    $OSINFO
SUMMARY

virt-install \
  --name "$NAME" \
  --memory "$MEMORY" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --machine q35 \
  --boot uefi \
  --disk "path=$DISK,size=$DISK_SIZE,format=qcow2,bus=virtio" \
  --cdrom "$ISO" \
  --network "bridge=$BRIDGE,model=virtio" \
  --graphics spice,listen=127.0.0.1 \
  --osinfo "detect=on,name=$OSINFO"
