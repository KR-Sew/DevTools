#!/usr/bin/env bash
set -u

OK='\033[0;32m'; WARN='\033[0;33m'; FAIL='\033[0;31m'; INFO='\033[0;36m'; NC='\033[0m'
ok(){ printf "${OK}[ OK ]${NC} %s\n" "$*"; }
warn(){ printf "${WARN}[WARN]${NC} %s\n" "$*"; }
fail(){ printf "${FAIL}[FAIL]${NC} %s\n" "$*"; }
info(){ printf "${INFO}[INFO]${NC} %s\n" "$*"; }

check_link(){ ip link show "$1" >/dev/null 2>&1 && ok "$1 exists" || fail "$1 is missing"; }
check_mount(){ findmnt -rn "$1" >/dev/null 2>&1 && ok "$1 is mounted ($(findmnt -rn -o SOURCE,FSTYPE "$1"))" || fail "$1 is not mounted"; }

echo
printf 'Debian virtualization host check\n'
printf '================================\n'

info "Kernel: $(uname -r)"

check_link br0
check_link br1
ip -4 addr show br0 | grep -q '10\.100\.100\.251/24' && ok 'br0 reference management IP present' || warn 'br0 does not use reference IP 10.100.100.251/24 (may be intentional)'
ip route | grep -q '^default .* dev br0' && ok 'default route uses br0' || warn 'default route does not use br0'

check_mount /fast-vm
check_mount /var/lib/docker
check_mount /backup

if command -v lvs >/dev/null; then
  sudo lvs --noheadings -o lv_name,lv_attr 2>/dev/null | grep -q 'thinpool.*twi-a' && ok 'LVM thinpool is active' || warn 'active thinpool not detected'
fi

systemctl is-active --quiet docker && ok 'Docker daemon active' || fail 'Docker daemon inactive'
if command -v docker >/dev/null; then
  docker info >/dev/null 2>&1 && ok 'Docker responds' || warn 'Docker CLI cannot query daemon'
fi

if command -v lxc >/dev/null; then
  lxc storage show vmstore >/dev/null 2>&1 && ok 'LXD vmstore available' || fail 'LXD vmstore unavailable'
  lxc network list --format csv 2>/dev/null | grep -q '^br1,' && ok 'LXD sees br1' || warn 'LXD does not report br1'
else
  fail 'lxc not in PATH'
fi

if [[ -e /dev/kvm ]]; then ok '/dev/kvm available'; else fail '/dev/kvm missing'; fi

if command -v virsh >/dev/null; then
  virsh pool-info fast-vm 2>/dev/null | grep -q 'State:.*running' && ok 'libvirt fast-vm pool active' || fail 'libvirt fast-vm pool inactive/missing'
  virsh pool-info iso 2>/dev/null | grep -q 'State:.*running' && ok 'libvirt ISO pool active' || warn 'libvirt ISO pool inactive/missing'

  if virsh dominfo deb13-kvm >/dev/null 2>&1; then
    virsh domstate deb13-kvm | grep -q running && ok 'reference VM deb13-kvm running' || warn 'reference VM deb13-kvm is not running'
    virsh dominfo deb13-kvm | grep -q 'Autostart:.*enable' && ok 'reference VM autostart enabled' || warn 'reference VM autostart disabled'
    if virsh domifaddr deb13-kvm --source agent 2>/dev/null | grep -q 'ipv4'; then
      ok 'QEMU guest agent responds'
    else
      warn 'QEMU guest agent/IP response not detected'
    fi
  else
    info 'Reference VM deb13-kvm not defined; skipping VM checks'
  fi
else
  fail 'virsh not installed'
fi

echo
