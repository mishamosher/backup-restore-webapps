#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'restore-path.sh - restores a folder from a local backup (falling back to downloading it)

usage: restore-path.sh DESTINATION TIMESTAMP [REMOTE]

Parameters:
 DESTINATION  Required. A relative or absolute path to the folder to restore.
 TIMESTAMP    Required. A timestamp of the backup to restore.
 REMOTE       Optional. Alternative name for the backup folder (by default, it is the basename of DESTINATION).

Options:
 --no-warn  Skip warnings

example: restore-path.sh "/folder/path" "2020-07-23T19-45-41Z"
example: restore-path.sh "/folder/path" "2020-07-23T19-45-41Z" "alternative_name"
example: restore-path.sh "/folder/path" "2020-07-23T19-45-41Z" "alternative_name" --no-warn'
}

if [ ${#ARGS[*]} -lt 2 ] || [ ${#ARGS[*]} -gt 3 ]; then
  showUsage
  exit 0
fi

restorePath "${ARGS[@]}"
