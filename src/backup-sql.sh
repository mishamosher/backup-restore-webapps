#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'backup-sql.sh - backups a MySQL database and uploads it to a cloud storage provider

usage: backup-sql.sh SOURCE [REMOTE]

Parameters:
 SOURCE  Required. Name of the database to backup.
 REMOTE  Optional. Alternative name for the backup folder (by default, it is the same as SOURCE).

Options:
 --no-warn  Skip warnings

example: backup-sql.sh "my_db"
example: backup-sql.sh "my_db" "alternative_name"
example: backup-sql.sh "my_db" "alternative_name" --no-warn'
}

if [ ${#ARGS[*]} -eq 0 ] || [ ${#ARGS[*]} -gt 2 ]; then
  showUsage
  exit 0
fi

backupSql "${ARGS[@]}"
