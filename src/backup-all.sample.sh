#!/bin/bash

# Creates a backup of wwwroots and dbs and uploads everything to a cloud storage provider
# Specific requirements: env.sh

!ERROR! # This line is deliberately here to cause an error. Please personalize the backup-all.sample.sh script to fit your needs, remove this line, and rename the script to your liking.

# Import shared configs and functions
source "$(dirname "$0")/env.sh"

# Backup SiteA wwwroot
asyncTask backupPath "/var/www/html/site_a"

# Backup SiteA db
asyncTask backupSql "site_a"

# Backup SiteB wwwroot
asyncTask backupPath "/var/www/html/site_a"

# Backup SiteB db
asyncTask backupSql "site_a"

# Wait all the pending tasks
waitPids

echo "All tasks completed!"
