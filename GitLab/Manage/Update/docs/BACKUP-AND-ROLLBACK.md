# Backup and rollback

## Why the DB is backed up separately

This installation uses an external PostgreSQL 17 container. Earlier GitLab
18.0.x images contained PostgreSQL 16 client utilities. Running the integrated
GitLab backup against PostgreSQL 17 produced:

```text
pg_dump: aborting because of server version mismatch
server version: 17.x
pg_dump version: 16.x
```

The GitLab backup task continued and produced a tar archive, but that archive
must **not** be considered a complete backup because its database dump failed.

The repo therefore uses:

```bash
docker exec gitlab_postgres pg_dump ...
docker exec gitlab gitlab-backup create SKIP=db
```

## Restore principle

A downgrade is not accomplished by only selecting an older Docker image.

Database migrations may have changed the schema. Restore the database backup
that corresponds to the exact GitLab CE version to which you are returning.

For a serious production rollback:

1. Stop writes / pause CI.
2. Stop GitLab application services as required by GitLab's restore procedure.
3. Recreate the exact older GitLab CE image.
4. Restore its matching pre-upgrade PostgreSQL dump.
5. Restore matching configuration/secrets if required.
6. Start GitLab.
7. Run health checks.
8. Verify web, SSH clone/push and representative repositories.

Always consult the current official rollback documentation before executing a
production restore.
