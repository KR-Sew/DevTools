#!/bin/bash

# === Configuration ===
BACKUP_DIR="/srv/gitlab/backups"
GITLAB_CONFIG="/srv/gitlab/config"
GITLAB_LOGS="/srv/gitlab/logs"
GITLAB_DATA="/srv/gitlab/data"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="gitlab_backup_$TIMESTAMP.tar.gz"
PG_CONTAINER_NAME="gitlab-postgres"
PG_USER="gitlab"
PG_DB="gitlabhq_production"
PG_DUMP_FILE="/tmp/pg_backup_$TIMESTAMP.sql"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# === Step 1: PostgreSQL Dump ===
echo "Creating PostgreSQL dump..."
docker exec "$PG_CONTAINER_NAME" pg_dump -U "$PG_USER" "$PG_DB" > "$BACKUP_DIR/pg_backup_$TIMESTAMP.sql"
if [ $? -ne 0 ]; then
  echo "❌ Failed to create PostgreSQL dump."
  exit 1
fi

# === Step 2: Archive GitLab data and PostgreSQL dump ===
echo "Archiving GitLab data and config..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" \
  -C "$GITLAB_CONFIG" . \
  -C "$GITLAB_LOGS" . \
  -C "$GITLAB_DATA" . \
  -C "$BACKUP_DIR" "pg_backup_$TIMESTAMP.sql"

# Clean up raw SQL file after archiving
rm "$BACKUP_DIR/pg_backup_$TIMESTAMP.sql"

# === Step 3: Done ===
echo "✅ Backup completed: $BACKUP_DIR/$ARCHIVE_NAME"
