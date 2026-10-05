# Build

Run on a Proxmox VE node as root.

## Defaults

- CT/template ID: `9001`
- Storage: `local-lvm`
- Template storage: `local`
- Bridge: `vmbr0`
- 2 vCPU
- 1024 MB RAM
- 512 MB swap
- 8 GB root disk
- DHCP during build

Override variables inline:

```bash
TEMPLATE_ID=9100 STORAGE=zpoolraid10 BRIDGE=vmbr0 ./scripts/build-template.sh
```

The builder selects the newest Debian 13 standard amd64 LXC archive shown by `pveam`.

Do not build over an existing CT ID.
