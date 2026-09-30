# <img src="../../Assets/pics/Minio_Logo_Black.svg" width=35>MinIO S3 Object Storage — <img src="../../Assets/pics/icons8-docker-48.svg">Docker + <img src="https://img.icons8.com/external-tal-revivo-shadow-tal-revivo/48/external-nginx-accelerates-content-and-application-delivery-improves-security-logo-shadow-tal-revivo.png" width=35 alt="Nginx"> NGINX

[![MinIO](https://img.shields.io/badge/MinIO-C72E49?style=flat&logo=minio&logoColor=white)](https://min.io/)
[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![NGINX](https://img.shields.io/badge/NGINX-009639?style=flat&logo=nginx&logoColor=white)](https://nginx.org/en/)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

---
A small production-style MinIO deployment for the `odobreno.ru` dedicated Debian server.

## Layout

```text
Internet
   |
   +-- https://s3.odobreno.ru --------> NGINX --> 127.0.0.1:9000 --> MinIO S3 API
   |
   +-- https://s3-console.odobreno.ru -> NGINX --> 127.0.0.1:9001 --> MinIO Console
                                                            |
                                                            +--> /data
                                                                 |
                                                                 +--> /mnt/hgsd1/minio/data
                                                                      /dev/sdd1 (XFS)
```

MinIO ports 9000/9001 are deliberately published only on `127.0.0.1`. NGINX is the public TLS endpoint.

## Repository

```text
.
├── .env.example
├── .gitignore
├── docker-compose.yml
├── nginx/
│   └── minio.conf.example
├── policies/
│   └── odobreno-storage-rw.json
├── scripts/
│   ├── check.sh
│   └── install-mc.sh
└── README.md
```

## 1. Prepare storage

```bash
# The files can be placed in any directory, as long as the application can access them
# In my case `/mnt/` is the project volume so I put them there
sudo mkdir -p /mnt/hgsd1/minio/data
findmnt /mnt/hgsd1
df -hT /mnt/hgsd1
```

Current persistent mount:

```fstab
UUID=a88394b1-bec2-42a0-91be-8f4bca49dc5d /mnt/hgsd1 xfs defaults 0 2
```

Validate `/etc/fstab`:

```bash
sudo mount -a
findmnt /mnt/hgsd1
```

## 2. Configure secrets

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Generate a root password if needed:

```bash
openssl rand -base64 32
```

Never commit `.env`.

## 3. Start MinIO

```bash
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=100 minio
```

Local health check:

```bash
curl -i http://127.0.0.1:9000/minio/health/live
```

Expected: `HTTP/1.1 200 OK`.

Verify MinIO is not publicly bound:

```bash
sudo ss -tlnp | grep -E ':(9000|9001)\b'
```

Expected listeners:

```text
127.0.0.1:9000
127.0.0.1:9001
```

## 4. DNS

```text
s3.odobreno.ru          A  5.35.7.237
s3-console.odobreno.ru  A  5.35.7.237
```

Verify:

```bash
dig +short A s3.odobreno.ru
dig +short A s3-console.odobreno.ru
```

## 5. NGINX

Copy the example:

```bash
sudo cp nginx/minio.conf.example /etc/nginx/sites-available/minio.conf
sudo ln -s /etc/nginx/sites-available/minio.conf /etc/nginx/sites-enabled/minio.conf
```

For first certificate issuance, start with HTTP vhosts as required by your Certbot workflow, then run:

```bash
sudo certbot --nginx   -d s3.odobreno.ru   -d s3-console.odobreno.ru
```

After issuance, the config may be cleaned into the form in `nginx/minio.conf.example`.

Validate:

```bash
sudo nginx -t &&
sudo systemctl reload nginx
```

Certificate renewal test:

```bash
sudo certbot renew --dry-run
```

## 6. Public tests

```bash
curl -I http://s3.odobreno.ru
curl -i https://s3.odobreno.ru/minio/health/live

curl -I http://s3-console.odobreno.ru
curl -I https://s3-console.odobreno.ru
```

Certificate SAN check:

```bash
openssl s_client   -connect s3.odobreno.ru:443   -servername s3.odobreno.ru </dev/null 2>/dev/null |
openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

The SAN must contain both `s3.odobreno.ru` and `s3-console.odobreno.ru`.

## 7. Install MinIO Client

```bash
./scripts/install-mc.sh
```

The helper pins the community client release used during deployment and uses `curl -fL` so an HTTP error page is not accidentally installed as a binary.

## 8. Configure admin alias

Do not `source .env` when it contains arbitrary shell-special characters.

Read the active credentials from the running container:

```bash
MINIO_USER="$(docker exec minio printenv MINIO_ROOT_USER)"
MINIO_PASS="$(docker exec minio printenv MINIO_ROOT_PASSWORD)"

mc alias set odobreno   https://s3.odobreno.ru   "$MINIO_USER"   "$MINIO_PASS"

unset MINIO_USER MINIO_PASS
```

Check:

```bash
mc admin info odobreno
```

`~/.mc/config.json` contains credentials and should remain mode `600`.

## 9. Create the primary bucket

```bash
mc mb odobreno/odobreno-storage
mc ls odobreno
```

## 10. Create a restricted S3 user

```bash
S3_USER="odobreno-s3"
S3_SECRET="$(openssl rand -base64 32)"

mc admin user add odobreno "$S3_USER" "$S3_SECRET"
```

Store the generated secret securely before unsetting it.

Create and attach the included bucket-scoped policy:

```bash
mc admin policy create   odobreno   odobreno-storage-rw   policies/odobreno-storage-rw.json

mc admin policy attach   odobreno   odobreno-storage-rw   --user odobreno-s3
```

Create a restricted client alias:

```bash
mc alias set odobreno-s3   https://s3.odobreno.ru   "$S3_USER"   "$S3_SECRET"

unset S3_SECRET
```

## 11. End-to-end object test

```bash
echo "Hello from MinIO $(date)" > /tmp/minio-test.txt

mc cp /tmp/minio-test.txt odobreno-s3/odobreno-storage/
mc ls odobreno-s3/odobreno-storage/

mc cp   odobreno-s3/odobreno-storage/minio-test.txt   /tmp/minio-test-downloaded.txt

diff /tmp/minio-test.txt /tmp/minio-test-downloaded.txt &&
echo "[OK] S3 upload/download verification passed."
```

Clean up:

```bash
mc rm odobreno-s3/odobreno-storage/minio-test.txt
rm -f /tmp/minio-test.txt /tmp/minio-test-downloaded.txt
```

## 12. Permission isolation test

Create another bucket as admin:

```bash
mc mb odobreno/private-test
```

These commands using the restricted account should fail with `Access Denied`:

```bash
mc ls odobreno-s3/private-test
mc cp /etc/hostname odobreno-s3/private-test/
```

Remove the test bucket:

```bash
mc rb odobreno/private-test
```

## Operations

Status:

```bash
docker compose ps
mc admin info odobreno
```

Logs:

```bash
docker compose logs -f minio
```

Restart:

```bash
docker compose restart minio
```

Storage:

```bash
findmnt /mnt/hgsd1
df -hT /mnt/hgsd1
```

Full quick check:

```bash
./scripts/check.sh
```

## Security notes

- Keep ports `9000` and `9001` bound to localhost.
- Do not use MinIO root credentials in applications.
- Give each application its own S3 user and bucket-scoped policy.
- Keep `.env` and `~/.mc/config.json` private.
- Do not commit secrets.
- Keep buckets private unless public access is explicitly intended.
- Test Certbot renewal after NGINX changes.
- Verify `/mnt/hgsd1` is mounted after host maintenance/reboots.
- For production lifecycle management, pin and test MinIO image versions rather than blindly upgrading `latest`.

## Current deployment

| Item | Value |
|---|---|
| S3 endpoint | `https://s3.odobreno.ru` |
| Console | `https://s3-console.odobreno.ru` |
| Docker project | `/mnt/hgsc1/projects/minio` |
| Persistent data | `/mnt/hgsd1/minio/data` |
| Storage filesystem | `/dev/sdd1`, XFS |
| Primary bucket | `odobreno-storage` |
| Restricted user | `odobreno-s3` |
