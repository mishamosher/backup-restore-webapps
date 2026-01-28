#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'backup-docker.sh - backups a Docker image and uploads it to a cloud storage provider

usage: backup-docker.sh SOURCE [REMOTE]

Parameters:
 SOURCE  Required. Name of the image to backup.
 REMOTE  Optional. Alternative name for the backup folder (by default, it is the same as SOURCE).

Options:
 --no-warn  Skip warnings

example: backup-docker.sh "my_image"
example: backup-docker.sh "my_image" "alternative_name"
example: backup-docker.sh "my_image" "alternative_name" --no-warn'
}

if [ ${#ARGS[*]} -eq 0 ] || [ ${#ARGS[*]} -gt 2 ]; then
  showUsage
  exit 0
fi

backupDocker "${ARGS[@]}"
