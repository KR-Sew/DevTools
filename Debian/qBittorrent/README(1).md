# qBittorrent Docker + NFS

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

qBittorrent in Docker inside an LXD VM, with downloads stored outside the VM on a ZFS dataset exported over NFS and WebUI published through host NGINX.

## 🚀 Architecture

```text
DebianNode (LXD host)
├── TSB1TB/lxdpool                    # LXD VM storage
└── WD500G/torrents                   # torrent ZFS dataset
    └── /mnt/WD500G/torrents
             │ NFSv4
             ▼
vm1 (10.10.205.100)
├── /mnt/torrents                     # NFS mount
├── Docker
│   └── qbittorrent
│       ├── /config    -> /srv/qbittorrent/config
│       └── /downloads -> /mnt/torrents
└── NGINX :443 -> 127.0.0.1:18080 -> qbittorrent:8080
```

Host/LXD bridge: `10.10.205.253/24` (`lxdbr0-vm`). LXD 5.21.7 LTS. Public WebUI: `https://torrents.lightcyber.ru`.

## 1. NFS server on DebianNode

```bash
sudo apt update
sudo apt install -y nfs-kernel-server
```

Add to `/etc/exports`:

```text
/mnt/WD500G/torrents 10.10.205.100(rw,sync,no_subtree_check,root_squash)
```

Apply and verify:

```bash
sudo exportfs -rav
sudo exportfs -v
sudo systemctl status nfs-server --no-pager
```

Do **not** add `WD500G` to `TSB1TB/lxdpool`; keep VM storage and bulk torrent data separate.

## 2. NFS client on vm1

```bash
sudo apt update
sudo apt install -y nfs-common
sudo mkdir -p /mnt/torrents
sudo mount -t nfs4 10.10.205.253:/mnt/WD500G/torrents /mnt/torrents
findmnt /mnt/torrents
```

For persistent mounting, add to `/etc/fstab`:

```text
10.10.205.253:/mnt/WD500G/torrents /mnt/torrents nfs4 rw,_netdev,nofail,x-systemd.automount 0 0
```

Then:

```bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/torrents
```

## 3. Deploy qBittorrent

```bash
git clone <your-repository-url>
cd qbittorrent-docker-nfs
cp .env.example .env
nano .env
./install.sh
```

Defaults:

```text
WebUI host:       127.0.0.1:18080
WebUI container:  8080
Torrent TCP/UDP:  6881
Config:           /srv/qbittorrent/config
Downloads:        /mnt/torrents
```

The WebUI uses host port `18080` because `8080` is already occupied by OnlyOffice on this VM.

## 4. NGINX

Copy/adapt `nginx/torrents.lightcyber.ru.conf` into the configuration included by your NGINX installation. This host uses source-installed NGINX with main config at `/usr/local/nginx/conf/nginx.conf`.

Test and reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Test locally and through HTTPS:

```bash
curl -I http://127.0.0.1:18080/
curl -Ik https://torrents.lightcyber.ru/
```

## 5. Initial login

Username: `admin`

The LinuxServer image generates a temporary password at startup:

```bash
docker logs qbittorrent 2>&1 | grep -i password
```

Set a permanent password in qBittorrent WebUI after the first login.

## 6. Storage verification

Inside `vm1`:

```bash
findmnt /mnt/torrents
df -hT /mnt/torrents
touch /mnt/torrents/storage-test
```

On `DebianNode`:

```bash
ls -l /mnt/WD500G/torrents/storage-test
rm /mnt/WD500G/torrents/storage-test
```

The storage flow is:

```text
WD500G/torrents
 -> /mnt/WD500G/torrents
 -> NFSv4
 -> vm1:/mnt/torrents
 -> Docker bind mount
 -> qbittorrent:/downloads
```

Downloaded files therefore do not consume the VM root disk.

## 7. Permissions

The container defaults to `PUID=1000` and `PGID=1000`. NFS uses numeric UID/GID values, so verify them on both systems:

```bash
id
ls -lnd /mnt/torrents
docker exec qbittorrent id
```

Prefer matching ownership/group permissions instead of permanent `chmod 777` access.

## 8. Operations

```bash
# Status
docker compose ps

# Logs
docker logs -f qbittorrent

# Restart
docker compose restart

# Update
./update.sh

# Remove container while preserving data
./uninstall.sh
```

`uninstall.sh` deliberately leaves `/srv/qbittorrent/config` and `/mnt/torrents` untouched.

## 9. Troubleshooting

Check ports:

```bash
sudo ss -lntp | grep -E ':18080|:6881'
docker ps
```

A `502 Bad Gateway` from NGINX should first be tested directly:

```bash
curl -v http://127.0.0.1:18080/
docker logs qbittorrent
```

For NFS issues:

```bash
# vm1
ping -c 3 10.10.205.253
findmnt /mnt/torrents

# DebianNode
sudo exportfs -v
sudo systemctl status nfs-server --no-pager
```

## Security

The WebUI is bound only to `127.0.0.1:18080` and is intended to be reached remotely only through HTTPS/NGINX. The NFS export is restricted to `10.10.205.100`. Torrent peer traffic is separately published on TCP/UDP `6881`.

## Backup

Back up qBittorrent configuration from:

```text
/srv/qbittorrent/config
```

Torrent data can be managed independently through ZFS, for example:

```bash
sudo zfs snapshot WD500G/torrents@manual-$(date +%Y%m%d)
```

---

🔙 [back to the **Repo**](./)