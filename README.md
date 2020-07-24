# Bash automation scripts for webapps backup and restoration

This is a collection of bash scripts to aid in automating backup and restoration tasks.

## Some facts
 - Database: MySQL only
 - Webroot: preserves symbolic links, extended attributes, owner, permissions and SELinux contexts.
 - Cloud storage: anything compatible with [RClone](https://rclone.org/).
 - All the source files have documentation embedded.