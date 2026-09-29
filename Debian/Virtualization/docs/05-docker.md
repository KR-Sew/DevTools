# 05 — Docker

[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Database Icon by icons8.com](https://img.shields.io/badge/Database%20Icon%20by%20icon8.com-54f2f2.svg?logo=vsc&logoColor=white)](https://icons8.com)

The reference host keeps Docker data on a dedicated XFS LV:

```text
/dev/mapper/VG_SSD-lv_docker -> /var/lib/docker
```

Verify the mount before starting Docker:

```bash
findmnt /var/lib/docker
df -hT /var/lib/docker
```

## Log rotation

Use [`configs/docker/daemon.json`](../configs/docker/daemon.json):

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "20m",
    "max-file": "5"
  }
}
```

Validate and restart:

```bash
python3 -m json.tool /etc/docker/daemon.json
sudo systemctl restart docker
docker info | grep -E 'Storage Driver|Logging Driver'
```

The tested host uses `overlayfs` and `json-file`.

## Functional test

```bash
docker run -d --name log-test alpine \
  sh -c 'while true; do echo "Docker logging test $(date)"; sleep 10; done'

docker inspect log-test \
  --format 'Driver={{.HostConfig.LogConfig.Type}} Config={{json .HostConfig.LogConfig.Config}}'
docker rm -f log-test
```

---

[Next 🔜`06-lxd`](./06-lxd.md)

---
🔙 [back to the **Repo**](../)
