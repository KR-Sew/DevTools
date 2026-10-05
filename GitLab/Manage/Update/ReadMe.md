# <img src="../../../Assets/pics/icons8-gitlab-48.svg" width="35" alt="GitLab Management Scripts"> GitLab CE Docker Upgrade How-To

[![GitLab](https://img.shields.io/badge/GitLab-FC6D26?style=flat&logo=gitlab&logoColor=white)](https://about.gitlab.com/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

Production-oriented notes and helper scripts for upgrading a **Docker Compose GitLab CE**
installation that uses an **external PostgreSQL 17 container** and persistent bind mounts.

This repo is based on the following layout:

```text
GitLab:      gitlab/gitlab-ce
PostgreSQL:  postgres:17

/mnt/hgsc1/projects/gitlab/config  -> /etc/gitlab
/mnt/hgsc1/projects/gitlab/logs    -> /var/log/gitlab
/mnt/hgsc1/projects/gitlab/data    -> /var/opt/gitlab
/mnt/hgsc1/dbdata/postgres         -> /var/lib/postgresql/data

Backup root:
/mnt/hgsd1/backups/postres_gitlab
```

> **Important:** Never upgrade GitLab by jumping over required upgrade stops.
> Always use the latest patch release in each required minor release and wait for
> background migrations to finish before continuing.

## Upgrade history used for this installation

The original installation started on:

```text
18.0.1-ce.0
```

The safe path used was:

```text
18.0.1
  -> 18.2.8
  -> 18.5.7
  -> 18.8.11
  -> 18.11.x
  -> 19.2.x
```

GitLab's predictable required stops are `x.2`, `x.5`, `x.8`, and `x.11`.

## Current security action

If the instance is currently **19.2.0**, do not leave it there. A GitLab critical
patch release on 2026-09-23 provided **19.4.1, 19.3.3 and 19.2.7**.

For this installation the lowest-risk immediate security update is:

```text
19.2.0-ce.0 -> 19.2.7-ce.0
```

That is only a patch-level update and does not require an intermediate minor
release.

After the security patch is installed and verified, moving from `19.2.7` to
`19.4.1` is also possible: the next required GitLab 19 stop after `19.2` is
`19.5`, so there is no required stop between 19.2 and 19.4. Prefer doing the
security patch first, then treat the feature-minor update as a separate change.

## Repository layout

```text
.
├── README.md
├── compose/
│   ├── docker-compose.yml
│   └── .env.example
├── docs/
│   ├── BACKUP-AND-ROLLBACK.md
│   └── TROUBLESHOOTING.md
└── scripts/
    ├── 01-preflight.sh
    ├── 02-backup.sh
    ├── 03-upgrade.sh
    └── 04-verify.sh
```

## 1. Configure

Copy the examples:

```bash
cd /mnt/hgsc1/projects/gitlab

cp compose/.env.example .env
cp compose/docker-compose.yml docker-compose.yml
chmod 600 .env
```

Do **not** replace a working production Compose file blindly. Merge the useful
parts into the existing file and preserve all current SMTP/database settings.

Validate it:

```bash
docker compose config --quiet
```

## 2. Preflight

```bash
sudo ./scripts/01-preflight.sh
```

This checks:

- GitLab and PostgreSQL containers;
- GitLab version;
- PostgreSQL version;
- service state;
- ordinary DB migrations;
- batched background migrations;
- GitLab health;
- disk space.

A batched migration with `status=finalized` is complete. Do not use hard-coded
numeric status values; GitLab's enum values can change.

## 3. Backup

The GitLab 18.0.x container bundled `pg_dump 16`, while this deployment already
used PostgreSQL 17. That makes a normal integrated DB backup fail with:

```text
server version: 17.x
pg_dump version: 16.x
aborting because of server version mismatch
```

Therefore this repo deliberately performs the database dump **inside the
PostgreSQL 17 container**, then asks GitLab to back up everything except the DB.

```bash
sudo ./scripts/02-backup.sh
```

The backup set contains:

- PostgreSQL 17 custom-format dump;
- `pg_restore --list` validation;
- GitLab application backup with `SKIP=db`;
- `/etc/gitlab` configuration archive;
- `gitlab-secrets.json`;
- `docker-compose.yml`;
- `.env`;
- resolved Compose configuration;
- exact GitLab/PostgreSQL image tags;
- version information;
- SHA-256 checksums.

Treat the backup directory as sensitive because `.env`, the resolved Compose
file, and `gitlab-secrets.json` contain secrets.

## 4. Upgrade one version at a time

For the current critical patch:

```bash
sudo ./scripts/03-upgrade.sh 19.2.7-ce.0
```

The script:

1. requires a pinned target version;
2. changes only the GitLab image tag;
3. validates Compose;
4. pulls the requested image;
5. recreates only GitLab with `--no-deps`;
6. leaves PostgreSQL untouched.

Follow logs if needed:

```bash
docker compose logs -f --tail=200 gitlab
```

## 5. Verify

```bash
sudo ./scripts/04-verify.sh
```

Also test manually:

```bash
curl -I https://gitlab.odobreno.ru/
ssh -T -p 2222 git@gitlab.odobreno.ru
```

Check the Admin UI:

```text
Admin -> Monitoring -> Background migrations
```

Do not move to another required upgrade stop while migrations are active,
failed, paused, or finalizing.

## PostgreSQL 17

GitLab 19 requires PostgreSQL 17 or newer. This deployment already satisfies
that requirement.

During a GitLab application upgrade, **do not upgrade or recreate PostgreSQL at
the same time**. Keep database and application changes as separate maintenance
operations.

## GitLab Runner

Before a planned GitLab upgrade, pause CI/CD work where practical. GitLab also
recommends keeping GitLab Runner aligned with the target GitLab version.

## Rollback rule

Changing the image tag back is **not a database rollback**.

Once a newer GitLab version has run migrations, a proper rollback requires the
matching pre-upgrade database backup and the exact GitLab CE version/edition
from which that backup was taken.

See [docs/BACKUP-AND-ROLLBACK.md](docs/BACKUP-AND-ROLLBACK.md).

## Useful commands

```bash
# Current image
docker inspect gitlab --format '{{.Config.Image}}'

# GitLab environment
docker exec gitlab gitlab-rake gitlab:env:info

# GitLab services
docker exec gitlab gitlab-ctl status

# Normal migrations: no "down" rows expected
docker exec gitlab gitlab-rake db:migrate:status | awk '$1 == "down"'

# GitLab health
docker exec gitlab gitlab-rake gitlab:check SANITIZE=true

# PostgreSQL readiness
docker exec gitlab_postgres pg_isready

# Logs
docker compose logs --tail=200 gitlab
```

## Official references

- https://docs.gitlab.com/update/upgrade_paths/
- https://docs.gitlab.com/update/docker/
- https://docs.gitlab.com/update/plan_your_upgrade/
- https://docs.gitlab.com/update/versions/gitlab_19_changes/
- https://docs.gitlab.com/install/docker/backup/
- https://docs.gitlab.com/update/package/downgrade/
- https://docs.gitlab.com/omnibus/settings/database/
- https://about.gitlab.com/blog/tags/patch-releases/
