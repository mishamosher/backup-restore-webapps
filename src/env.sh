#!/bin/bash

# Serves as a shared functionality file for different backup/restore operations
# Specific requirements: pv rclone mysqldump rsync lz4

source "$(dirname "$0")/conf.sh"

# From here onwards there is nothing to configure. Please modify with care.

# Generates a split compressed tar.lz4 of a folder
# - $1 A relative or absolute path to the folder to compress
# - $2 The destination compressed file
tarSplit() {
  local TAR_REALPATH=$(realpath "$1")
  local TAR_BASENAME="./$(basename "${TAR_REALPATH}")"
  local TAR_DIRNAME=$(dirname "${TAR_REALPATH}")
  tar --selinux --acls --xattrs --same-owner -cpf - -C "${TAR_DIRNAME}" "${TAR_BASENAME}" | pv | lz4 -z - | split --bytes="${SPLIT_SIZE}" - "$2"
}

# Generates a split compressed LZ4 of a MySQL db
# - $1 Database to backup
# - $2 The destination compressed file
mysqldumpLZ4() {
  mysqldump --defaults-file="${MySQL_DEFAULTS_FILE}" --host=localhost --protocol=tcp --user=root --hex-blob=TRUE --complete-insert=TRUE --port=3306 --default-character-set=utf8 --routines --skip-triggers --add-drop-database --databases "$1" |
    pv | lz4 -z - | split --bytes="${SPLIT_SIZE}" - "$2"
}

# Generates a split compressed LZ4 of a Docker image
# - $1 Image to backup
# - $2 The destination compressed file
dockerSaveLZ4() {
  docker save "$1" | pv | lz4 -z - | split --bytes="${SPLIT_SIZE}" - "$2"
}

# Cleans up the cloud storage folder
# - $1   Time specification to delete all files with the condition «older than». See here for supported units: https://rclone.org/filtering/#max-age-don-t-transfer-any-file-older-than-this
# - [$2] Remote path to clean (by default, the root path). Please don't use a leading '/': "/path/to/folder" (INVALID), "path/to/folder" (VALID).
cleanRclone() {
  rclone --min-age "$1" delete "${RCLONE_NAME}:${RCLONE_PATH_PREFIX}$2" --rmdirs --progress
}

# Generates a backup of a folder and uploads it to a cloud storage provider
# - $1   A relative or absolute path to the folder to backup
# - [$2] Alternative name for the backup folder (by default, it is the basename of $1)
backupPath() {
  local BACKUP_REALPATH=$(realpath "$1")
  echo "Backup of path \"${BACKUP_REALPATH}\" started!"
  local BACKUP_NAME
  if [ -z "$2" ]; then BACKUP_NAME=$(basename "${BACKUP_REALPATH}"); else BACKUP_NAME="$2"; fi
  rm -rf "${BACKUP_DIR}/dir/${BACKUP_NAME}"
  mkdir -p "${BACKUP_DIR}/dir/${BACKUP_NAME}/${TIMESTAMP}"
  tarSplit "${BACKUP_REALPATH}" "${BACKUP_DIR}/dir/${BACKUP_NAME}/${TIMESTAMP}/compressed.tar.lz4."
  rclone copy "${BACKUP_DIR}/dir/${BACKUP_NAME}" "${RCLONE_NAME}:${RCLONE_PATH_PREFIX}dir/${BACKUP_NAME}" --progress --checksum
  echo "Backup of path \"${BACKUP_REALPATH}\" finished!"
}

# Generates a backup of a MySQL database and uploads it to a cloud storage provider
# - $1   Name of the database to backup
# - [$2] Alternative name for the backup folder (by default, it is the same as $1)
backupMySQL() {
  echo "Backup of MySQL db \"$1\" started!"
  local BACKUP_NAME
  if [ -z "$2" ]; then BACKUP_NAME="$1"; else BACKUP_NAME="$2"; fi
  rm -rf "${BACKUP_DIR}/mysql/${BACKUP_NAME}"
  mkdir -p "${BACKUP_DIR}/mysql/${BACKUP_NAME}/${TIMESTAMP}"
  mysqldumpLZ4 "$1" "${BACKUP_DIR}/mysql/${BACKUP_NAME}/${TIMESTAMP}/db.sql.lz4."
  rclone copy "${BACKUP_DIR}/mysql/${BACKUP_NAME}" "${RCLONE_NAME}:${RCLONE_PATH_PREFIX}mysql/${BACKUP_NAME}" --progress --checksum
  echo "Backup of MySQL db \"$1\" finished!"
}

# Generates a backup of a Docker image and uploads it to a cloud storage provider
# - $1   Name of the image to backup
# - [$2] Alternative name for the backup folder (by default, it is the same as $1)
backupDocker() {
  echo "Backup of Docker image \"$1\" started!"
  local BACKUP_NAME
  if [ -z "$2" ]; then BACKUP_NAME="$1"; else BACKUP_NAME="$2"; fi
  rm -rf "${BACKUP_DIR}/docker/${BACKUP_NAME}"
  mkdir -p "${BACKUP_DIR}/docker/${BACKUP_NAME}/${TIMESTAMP}"
  dockerSaveLZ4 "$1" "${BACKUP_DIR}/docker/${BACKUP_NAME}/${TIMESTAMP}/image.tar.lz4."
  rclone copy "${BACKUP_DIR}/docker/${BACKUP_NAME}" "${RCLONE_NAME}:${RCLONE_PATH_PREFIX}docker/${BACKUP_NAME}" --progress --checksum
  echo "Backup of Docker image \"$1\" finished!"
}

# Checks if a glob-expanded non-recursive path contains at least one regular file
# - $1 Path to check
# @returns 1 if true, 0 if false
hasFiles() {
  local RESULT=0
  for FILE in "$1"*; do
    if [ -f "${FILE}" ]; then RESULT=1; fi
    break
  done
  echo $RESULT
}

# Restores a folder from a local backup (falling back to downloading it)
# - $1   A relative or absolute path to the folder to restore
# - $2   Timestamp of the backup version to restore
# - [$3] Alternative name for the backup folder (by default, it is the basename of $1)
restorePath() {
  local RESTORE_REALPATH=$(realpath "$1")
  echo "Restoration of path \"${RESTORE_REALPATH}\" started!"
  local RESTORE_NAME
  if [ -z "$3" ]; then RESTORE_NAME=$(basename "${RESTORE_REALPATH}"); else RESTORE_NAME="$3"; fi

  local LOCAL_BACKUP_PATH="${BACKUP_DIR}/dir/${RESTORE_NAME}/$2/compressed.tar.lz4."

  # Download the backup only if there is not a local one and a remote one exists
  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 0 ]; then
    local REMOTE_BACKUP_PATH="${RCLONE_NAME}:${RCLONE_PATH_PREFIX}dir/${RESTORE_NAME}/$2"
    if rclone lsf "${REMOTE_BACKUP_PATH}"; then
      rclone copy "${REMOTE_BACKUP_PATH}" "${BACKUP_DIR}/dir/${RESTORE_NAME}/$2" --progress --checksum
    fi
  fi

  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 1 ]; then
    rm -rf "${RESTORE_REALPATH}"
    cat "${LOCAL_BACKUP_PATH}"* | pv | lz4 -d - | tar --selinux --acls --xattrs --same-owner -xpf - -C "$(dirname "${RESTORE_REALPATH}")"
  else
    echo "There is no backup called \"${RESTORE_NAME}/$2\" (local or remote). No restoration will be performed."
  fi

  echo "Restoration of path \"${RESTORE_REALPATH}\" finished!"
}

# Restores a MySQL database from a local backup (falling back to downloading it)
# - $1   Name of the database to restore
# - $2   Timestamp of the backup version to restore
# - [$3] Alternative name for the backup folder (by default, it is the same as $1)
restoreMySQL() {
  echo "Restoration of MySQL db \"$1\" started!"
  local RESTORE_NAME
  if [ -z "$3" ]; then RESTORE_NAME="$1"; else RESTORE_NAME="$3"; fi

  local LOCAL_BACKUP_PATH="${BACKUP_DIR}/mysql/${RESTORE_NAME}/$2/db.sql.lz4."

  # Download the backup only if there is not a local one and a remote one exists
  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 0 ]; then
    local REMOTE_BACKUP_PATH="${RCLONE_NAME}:${RCLONE_PATH_PREFIX}mysql/${RESTORE_NAME}/$2"
    if rclone lsf "${REMOTE_BACKUP_PATH}"; then
      rclone copy "${REMOTE_BACKUP_PATH}" "${BACKUP_DIR}/mysql/${RESTORE_NAME}/$2" --progress --checksum
    fi
  fi

  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 1 ]; then
    cat "${LOCAL_BACKUP_PATH}"* | pv | lz4 -d - | mysql --defaults-file="${MySQL_DEFAULTS_FILE}" --host=localhost --protocol=tcp --user=root
  else
    echo "There is no backup called \"${RESTORE_NAME}/$2\" (local or remote). No restoration will be performed."
  fi

  echo "Restoration of MySQL db \"$1\" finished!"
}

# Restores a Docker image from a local backup (falling back to downloading it)
# - $1   Name of the image to restore
# - $2   Timestamp of the backup version to restore
# - [$3] Alternative name for the backup folder (by default, it is the same as $1)
restoreDocker() {
  echo "Restoration of Docker image \"$1\" started!"
  local RESTORE_NAME
  if [ -z "$3" ]; then RESTORE_NAME="$1"; else RESTORE_NAME="$3"; fi

  local LOCAL_BACKUP_PATH="${BACKUP_DIR}/docker/${RESTORE_NAME}/$2/image.tar.lz4."

  # Download the backup only if there is not a local one and a remote one exists
  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 0 ]; then
    local REMOTE_BACKUP_PATH="${RCLONE_NAME}:${RCLONE_PATH_PREFIX}docker/${RESTORE_NAME}/$2"
    if rclone lsf "${REMOTE_BACKUP_PATH}"; then
      rclone copy "${REMOTE_BACKUP_PATH}" "${BACKUP_DIR}/docker/${RESTORE_NAME}/$2" --progress --checksum
    fi
  fi

  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 1 ]; then
    cat "${LOCAL_BACKUP_PATH}"* | pv | lz4 -d - | docker load
  else
    echo "There is no backup called \"${RESTORE_NAME}/$2\" (local or remote). No restoration will be performed."
  fi

  echo "Restoration of Docker image \"$1\" finished!"
}

# Syncs two paths. The paths must point to a directory. Both paths can not be the root ("/") directory. Both paths must reside in different parent directories.
# Please use with care, as the destination path will be left identical to the origin (deleting paths absent in the origin in the process)
# - $1 A relative or absolute origin path
# - $2 A relative or absolute destination path. Will be created if doesn't exist. Please skip the basename of $1, as it is always automatically used.
syncPaths() {
  mkdir -p "$2"
  local SYNC_ORIGIN_REALPATH=$(realpath "$1")
  local SYNC_DESTINATION_REALPATH=$(realpath "$2")
  rsync -aAX --delete --force -v "${SYNC_ORIGIN_REALPATH}" "${SYNC_DESTINATION_REALPATH}/"
}

PIDS=()

# Starts an asynchronous task and saves the corresponding PID
# Example: asyncTask COMMAND PARAM1 PARAM2 PARAM3 ...
asyncTask() {
  ($1 "${@:2}") &
  PIDS+=($!)
}

# Waits to completion each PID in the PIDS array. Silently does nothing for each already-completed PID.
waitPids() {
  for PID in "${PIDS[@]}"; do wait "${PID}" >/dev/null 2>&1; done
}

warnDestructive() {
  echo "=== WARNING ===
The execution of this script can irreversibly:
- Delete historical backups in ${BACKUP_DIR}
- Delete historical backups in the cloud storage folder
- Delete the data that is going to be restored
- Delete contents from the destination sync directory

If the risk is too high, please keep an extra working backup in a separate folder.

You can pass the --no-warn option (in any position) to skip this warning.

Press the the key 'c' to continue, any other key to exit.
=== WARNING ==="
}

ARGS=()

for ((i = 1; i <= $#; i++)); do
  case "${!i}" in
  "--no-warn")
    NO_WARN=1
    ;;
  *)
    ARGS+=("${!i}")
    ;;
  esac
done

if [ -z "${NO_WARN}" ]; then
  warnDestructive
  read -n 1 -s -r KEY_PRESSED
  if [ "${KEY_PRESSED}" != "c" ]; then exit 0; fi
fi
