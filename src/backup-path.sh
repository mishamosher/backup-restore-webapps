#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'backup-path.sh - backups a folder and uploads it to a cloud storage provider

usage: backup-path.sh SOURCE [REMOTE]

Parameters:
 SOURCE  Required. A relative or absolute path to the folder to backup.
 REMOTE  Optional. Alternative name for the backup folder (by default, it is the basename of SOURCE).

Options:
 --no-warn  Skip warnings

example: backup-path.sh "/folder/path"
example: backup-path.sh "/folder/path" "alternative_name"
example: backup-path.sh "/folder/path" "alternative_name" --no-warn'
}

if [ ${#ARGS[*]} -eq 0 ] || [ ${#ARGS[*]} -gt 2 ]; then
  showUsage
  exit 0
fi

backupPath "${ARGS[@]}"
