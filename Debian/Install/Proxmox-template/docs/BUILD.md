# <img width="35" height="35" src="https://img.icons8.com/fluency/48/proxmox.png" alt="proxmox"/> Build

[![Proxmox](https://img.shields.io/badge/proxmox-proxmox?style=flat&logo=proxmox&logoColor=%23E57000&labelColor=%232b2a33&color=gray)](https://learn.microsoft.com/en-us/windows/wsl/about)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

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
