# linux_file_permissions_ubuntu

## Purpose
Enforces secure permissions on critical system files, scans for world-writable files, and verifies NFS mount security options to reduce unauthorized access risks.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 6.1, System File Permissions

## Key Variables
```yaml
linux_file_permissions_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
