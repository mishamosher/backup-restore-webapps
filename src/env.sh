#!/bin/bash

# Serves as a shared functionality file for different backup/restore operations
# Specific requirements: pv rclone mysqldump rsync

# Please set all the variables below to appropriate values/functions

!ERROR! # This line is deliberately here to cause an error. Please personalize the env.sample.sh script to fit your needs, remove this line, and rename the script to env.sh.

# A timestamp for all the backups that will be created. Defaults to current UTC date&time in the 2020-07-23T16-29-07Z format.
TIMESTAMP=$(date -u "+%FT%H-%M-%SZ")

# A temporary file (auto-deleted on script completion or interruption) that contains the MySQL password for DB backups.
MySQL_DEFAULTS_FILE=$(mktemp)
printf "[client]\npassword=\"PASSWORD\"\n" >"${MySQL_DEFAULTS_FILE}"
trap 'rm -f "${MySQL_DEFAULTS_FILE}"' EXIT SIGHUP SIGINT SIGQUIT SIGTERM

# Maximum size for backup files. See here for supported units: https://www.gnu.org/software/coreutils/split
SPLIT_SIZE="1000M"

# Name of the rclone pre-configured remote where to upload the backups
RCLONE_NAME="rclone-remote"

# Local directory used for backups (creation and restoration)
BACKUP_DIR="/mnt/backups"

# From here onwards there is nothing to configure. Please modify with care.

# Generates a splitted compressed tar.gz of a folder
# - $1 A relative or absolute path to the folder to compress
# - $2 The destination compressed file
tarSplit() {
  local TAR_REALPATH=$(realpath "$1")
  local TAR_BASENAME="./$(basename "${TAR_REALPATH}")"
  local TAR_DIRNAME=$(dirname "${TAR_REALPATH}")
  tar --selinux --acls --xattrs --same-owner -cpzf - -C "${TAR_DIRNAME}" "${TAR_BASENAME}" | pv | split --bytes="${SPLIT_SIZE}" - "$2"
}

# Generates a splitted compressed gz of a MySQL db
# - $1 Database to backup
# - $2 The destination compressed file
mysqldumpGzip() {
  mysqldump --defaults-file="${MySQL_DEFAULTS_FILE}" --host=localhost --protocol=tcp --user=root --hex-blob=TRUE --complete-insert=TRUE --port=3306 --default-character-set=utf8 --routines --skip-triggers --add-drop-database --databases "$1" |
    pv | gzip -c - | split --bytes="${SPLIT_SIZE}" - "$2"
}

# Cleans up the cloud storage folder
# - $1   Time specification to delete all files with the condition «older than». See here for supported units: https://rclone.org/filtering/#max-age-don-t-transfer-any-file-older-than-this
# - [$2] Remote path to clean (by default, the root path). Please don't use a leading '/': "/path/to/folder" (INVALID), "path/to/folder" (VALID).
cleanRclone() {
  rclone --min-age "$1" delete "${RCLONE_NAME}:$2" --rmdirs --progress
}

# Generates a backup of a folder and uploads it to a cloud storage provider
# - $1   A relative or absolute path to the folder to backup
# - [$2] Alternative name for the backup folder (by default, it is the basename of $1)
backupPath() {
  local BACKUP_REALPATH=$(realpath "$1")
  echo "Backup of path \"${BACKUP_REALPATH}\" started!"
  local BACKUP_NAME
  if [ -z "$2" ]; then BACKUP_NAME=$(basename "${BACKUP_REALPATH}"); else BACKUP_NAME="$2"; fi
  rm -rf "${BACKUP_DIR}/www/${BACKUP_NAME}"
  mkdir -p "${BACKUP_DIR}/www/${BACKUP_NAME}/${TIMESTAMP}"
  tarSplit "${BACKUP_REALPATH}" "${BACKUP_DIR}/www/${BACKUP_NAME}/${TIMESTAMP}/compressed.tar.gz."
  rclone copy "${BACKUP_DIR}/www/${BACKUP_NAME}" "${RCLONE_NAME}:www/${BACKUP_NAME}" --progress --checksum
  echo "Backup of path \"${BACKUP_REALPATH}\" finished!"
}

# Generates a backup of a MySQL database and uploads it to a cloud storage provider
# - $1   Name of the database to backup
# - [$2] Alternative name for the backup folder (by default, it is the same as $1)
backupSql() {
  echo "Backup of db \"$1\" started!"
  local BACKUP_NAME
  if [ -z "$2" ]; then BACKUP_NAME="$1"; else BACKUP_NAME="$2"; fi
  rm -rf "${BACKUP_DIR}/sql/${BACKUP_NAME}"
  mkdir -p "${BACKUP_DIR}/sql/${BACKUP_NAME}/${TIMESTAMP}"
  mysqldumpGzip "$1" "${BACKUP_DIR}/sql/${BACKUP_NAME}/${TIMESTAMP}/db.sql.gz."
  rclone copy "${BACKUP_DIR}/sql/${BACKUP_NAME}" "${RCLONE_NAME}:sql/${BACKUP_NAME}" --progress --checksum
  echo "Backup of db \"$1\" finished!"
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

  local LOCAL_BACKUP_PATH="${BACKUP_DIR}/www/${RESTORE_NAME}/$2/compressed.tar.gz."

  # Download the backup only if there is not a local one and a remote one exists
  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 0 ]; then
    local REMOTE_BACKUP_PATH="${RCLONE_NAME}:www/${RESTORE_NAME}/$2"
    if rclone lsf "${REMOTE_BACKUP_PATH}"; then
      rclone copy "${REMOTE_BACKUP_PATH}" "${BACKUP_DIR}/www/${RESTORE_NAME}/$2" --progress --checksum
    fi
  fi

  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 1 ]; then
    rm -rf "${RESTORE_REALPATH}"
    cat "${LOCAL_BACKUP_PATH}"* | pv | tar --selinux --acls --xattrs --same-owner -xpzf - -C "$(dirname "${RESTORE_REALPATH}")"
  else
    echo "There is no backup called \"${RESTORE_NAME}/$2\" (local or remote). No restoration will be performed."
  fi

  echo "Restoration of path \"${RESTORE_REALPATH}\" finished!"
}

# Restores a MySQL database from a local backup (falling back to downloading it)
# - $1   Name of the database to restore
# - $2   Timestamp of the backup version to restore
# - [$3] Alternative name for the backup folder (by default, it is the same as $1)
restoreSql() {
  echo "Restoration of db \"$1\" started!"
  local RESTORE_NAME
  if [ -z "$3" ]; then RESTORE_NAME="$1"; else RESTORE_NAME="$3"; fi

  local LOCAL_BACKUP_PATH="${BACKUP_DIR}/sql/${RESTORE_NAME}/$2/db.sql.gz."

  # Download the backup only if there is not a local one and a remote one exists
  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 0 ]; then
    local REMOTE_BACKUP_PATH="${RCLONE_NAME}:sql/${RESTORE_NAME}/$2"
    if rclone lsf "${REMOTE_BACKUP_PATH}"; then
      rclone copy "${REMOTE_BACKUP_PATH}" "${BACKUP_DIR}/sql/${RESTORE_NAME}/$2" --progress --checksum
    fi
  fi

  if [ "$(hasFiles "${LOCAL_BACKUP_PATH}")" -eq 1 ]; then
    rm -rf "${RESTORE_REALPATH}"
    cat "${LOCAL_BACKUP_PATH}"* | pv | gunzip -c - | mysql --defaults-file="${MySQL_DEFAULTS_FILE}" --host=localhost --protocol=tcp --user=root
  else
    echo "There is no backup called \"${RESTORE_NAME}/$2\" (local or remote). No restoration will be performed."
  fi

  echo "Restoration of db \"$1\" finished!"
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
- Delete the folder/db that is going to be restored
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
