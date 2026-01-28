# Bash automation scripts for apps backup and restoration

This is a collection of bash scripts to aid in automating backup and restoration tasks.

## Some facts
 - Database: MySQL only
 - Folders: preserves symbolic links, extended attributes, owner, permissions and SELinux contexts.
 - Docker: any already-deployed image.
 - Cloud storage: anything compatible with [RClone](https://rclone.org/).
 - All the source files have documentation embedded.