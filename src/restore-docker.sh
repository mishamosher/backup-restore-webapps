#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'restore-docker.sh - restores a Docker image from a local backup (falling back to downloading it)

usage: restore-docker.sh DESTINATION TIMESTAMP [REMOTE]

Parameters:
 DESTINATION  Required. Name of the image to restore.
 TIMESTAMP    Required. A timestamp of the backup to restore.
 REMOTE       Optional. Alternative name for the backup folder (by default, it is the same as DESTINATION).

Options:
 --no-warn  Skip warnings

example: restore-docker.sh "my_image" "2020-07-23T19-45-41Z"
example: restore-docker.sh "my_image" "2020-07-23T19-45-41Z" "alternative_name"
example: restore-docker.sh "my_image" "2020-07-23T19-45-41Z" "alternative_name" --no-warn'
}

if [ ${#ARGS[*]} -lt 2 ] || [ ${#ARGS[*]} -gt 3 ]; then
  showUsage
  exit 0
fi

restoreDocker "${ARGS[@]}"
