# <img width="35" height="35" src="https://img.icons8.com/fluency/48/proxmox.png" alt="proxmox"/> Hardening Notes

[![Proxmox](https://img.shields.io/badge/proxmox-proxmox?style=flat&logo=proxmox&logoColor=%23E57000&labelColor=%232b2a33&color=gray)](https://learn.microsoft.com/en-us/windows/wsl/about)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

## Recommended

- Keep the LXC unprivileged.
- Do not enable nesting unless a concrete requirement appears.
- Keep Proxmox VE and Debian patched.
- Restrict SSH to management networks.
- Prefer SSH keys and disable password login after validating key access.
- Keep Proxmox Firewall as an outer control.
- Optionally use nftables inside the CT as defense in depth.
- Expose only 80/443 publicly.
- Do not expose backend services through the reverse-proxy CT.
- Do not store certificate/private-key material in Git.
- Back up `/etc/nginx`, `/etc/letsencrypt`, and any local operational configuration securely.
- Test `nginx -t` before every reload.
- Monitor certificate renewal and disk space.
- Review Fail2ban bans; it complements rather than replaces firewall/rate-limit policy.

## TLS

Certbot-managed defaults are preferred over copying static TLS parameters into the template. Enable HSTS only after confirming the hostname and any intended subdomains are permanently HTTPS-capable.

## Headers

The included security headers are conservative because applications differ. Content-Security-Policy should be designed per application rather than globally forced by the proxy template.
