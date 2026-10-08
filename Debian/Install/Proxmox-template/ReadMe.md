# <img width="35" height="35" src="https://img.icons8.com/fluency/48/proxmox.png" alt="proxmox"/> Proxmox Debian 13 NGINX Reverse Proxy Template

[![Proxmox](https://img.shields.io/badge/proxmox-proxmox?style=flat&logo=proxmox&logoColor=%23E57000&labelColor=%232b2a33&color=gray)](https://learn.microsoft.com/en-us/windows/wsl/about)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

Reusable **Debian 13 unprivileged LXC template** for Proxmox VE, intended for production reverse-proxy deployments.

## Included

- **Debian 13**
- **NGINX** from Debian packages
- **Certbot** + `python3-certbot-nginx`
- `nftables`
- **Fail2ban**
- `fzf`, `gawk`, `jq`, `bat`, `tree`, `htop` and troubleshooting utilities
- Production-oriented NGINX snippets
- `proxy-check` health utility
- First-boot identity initialization
- Template sanitization
- **Proxmox** `pct` build workflow

## Design

The template intentionally contains **no certificates, site-specific secrets, production hostnames, or backend addresses**.

Recommended flow:

```text
Debian 13 CT
    ↓
Provision packages/configuration
    ↓
Validate
    ↓
Sanitize
    ↓
Convert to Proxmox template
    ↓
Clone
    ↓
First boot creates unique machine/SSH identity
    ↓
Configure site + obtain certificate
```

## Quick start

Edit the variables at the beginning of:

```bash
scripts/build-template.sh
```

Then run it on a Proxmox node as root:

```bash
chmod +x scripts/*.sh
sudo ./scripts/build-template.sh
```

After the template is created:

```bash
pct clone 9001 201 --hostname proxy01 --full 1
pct set 201 --cores 2 --memory 1024 --swap 512
pct set 201 --net0 name=eth0,bridge=vmbr0,ip=10.10.10.20/24,gw=10.10.10.1,type=veth,firewall=1
pct start 201
```

See `docs/DEPLOY.md` before exposing a clone to the Internet.

## Important firewall note

The bundled nftables policy is installed as an **example**, but is not enabled automatically by the build. This is deliberate: Proxmox Firewall should normally be your outer policy, while an in-container nftables policy can be enabled after you verify SSH/admin access and your network design.

## Certificates

Issue certificates only **after cloning**:

```bash
certbot --nginx -d proxy.example.com
```

Never place production `/etc/letsencrypt` contents in the template.
