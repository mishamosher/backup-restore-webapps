#!/bin/bash

# Please set all the variables below to appropriate values/functions

!ERROR! # This line is deliberately here to cause an error. Please personalize the conf.sample.sh script to fit your needs and, remove this line, and rename the script to conf.sh.

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

# Prefix to use when transferring data to/from the rclone remote. Should start *without* a path delimiter, and end *with* a path delimiter.
# Valid: prefix/path/
# Invalid: /prefix/path
RCLONE_PATH_PREFIX=""

# Local directory used for backups (creation and restoration)
BACKUP_DIR="/mnt/backups"

# A warning about data loss is shown everytime this scripts runs. Set this variable to any non-empty value to turn off this warning. Can also be controlled in runtime (--no-warn).
NO_WARN=""

# By default a single local backup is preserved in local storage. Set this variable to any non-empty value so no local backups are kept. Can also be controlled in runtime (--no-local-copy).
NO_LOCAL_COPY=""
