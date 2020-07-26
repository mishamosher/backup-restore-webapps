#!/bin/bash

# Specific requirements: env.sh

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

showUsage() {
  echo 'sync-paths.sh - syncs two paths

usage: sync-paths.sh ORIGIN DESTINATION

remarks:
 - The paths must point to a directory.
 - The destination path can not be the root ("/") directory.
 - Both paths must reside in different parent directories.
 - Please use with care, as the destination path will be left identical to the origin (deleting paths absent in the origin in the process).

Parameters:
 ORIGIN       Required. A relative or absolute origin path.
 DESTINATION  Required. A relative or absolute destination path. Will be created if does not exist. Please skip the basename of ORIGIN, as it is always automatically used.

Options:
 --no-warn  Skip warnings

example: sync-paths.sh "/folder/path" "/folder-sync"
 - Creates a "/folder-sync/path" directory containing an identical copy of "/folder/path"'
}

if [ ${#ARGS[*]} -ne 2 ]; then
  showUsage
  exit 0
fi

syncPaths "${ARGS[@]}"
