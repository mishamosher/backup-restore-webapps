#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'clean-remote.sh - cleans up the cloud storage folder

usage: clean-remote.sh MIN_AGE [PATH]

Parameters:
 MIN_AGE  Required. Time specification to delete all files with the condition «older than». See here for supported units: https://rclone.org/filtering/#max-age-don-t-transfer-any-file-older-than-this
 PATH     Optional. Remote path to clean (by default, the root path). Please do not use a leading "/": "/path/to/folder" (INVALID), "path/to/folder" (VALID).

Options:
 --no-warn  Skip warnings

example: clean-remote.sh "2W"
example: clean-remote.sh "2W" "sql"'
}

if [ ${#ARGS[*]} -eq 0 ] || [ ${#ARGS[*]} -gt 2 ]; then
  showUsage
  exit 0
fi

cleanRclone "${ARGS[@]}"
