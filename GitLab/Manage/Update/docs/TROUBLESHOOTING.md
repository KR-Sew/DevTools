# <img src="../../../../Assets/pics/icons8-gitlab-48.svg" width="35" alt="GitLab Update troubleshooting"> Troubleshooting

[![GitLab](https://img.shields.io/badge/GitLab-FC6D26?style=flat&logo=gitlab&logoColor=white)](https://about.gitlab.com/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![Bash](https://img.shields.io/badge/GNU%20Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## Backup script exits with code 141

`141 = 128 + SIGPIPE(13)`.

With:

```bash
set -Eeuo pipefail
```

pipelines such as these can fail when the downstream process exits early:

```bash
producer | head -1
producer | awk '/match/ { print; exit }'
```

The upstream producer can receive SIGPIPE and the pipeline becomes a failure.

The scripts in this repo avoid early-exit pipelines for important operations.
GitLab version detection uses:

```bash
docker exec gitlab gitlab-rails runner 'puts Gitlab::VERSION'
```

rather than parsing `gitlab:env:info` and exiting `awk` early.

## Background migrations show numeric status 6

Do not assume a numeric enum value means failure.

Query by symbolic states. For the upgrade gate, both `finished` and `finalized`
are complete:

```ruby
model.where.not(status: [:finished, :finalized])
```

## GitLab backup reports pg_dump version mismatch

Do not trust that archive as a complete backup.

Use the PostgreSQL 17 client in the PostgreSQL container to create a separate
custom-format dump and run GitLab backup with `SKIP=db`.

## Web and SSH work but upgrade validation fails

Run each check separately and inspect its actual exit status:

```bash
docker exec gitlab gitlab-rake gitlab:check SANITIZE=true
echo $?

docker exec gitlab gitlab-rake db:migrate:status

docker exec gitlab gitlab-rails runner 'puts Gitlab::VERSION'
```

A shell helper script failure is not automatically a GitLab application
failure.
