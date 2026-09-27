# 05 — Docker

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
