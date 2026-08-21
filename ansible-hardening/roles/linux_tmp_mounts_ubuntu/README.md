# linux_tmp_mounts_ubuntu

## Purpose
Configures /tmp and /dev/shm with noexec, nodev, and nosuid mount options to prevent execution of malicious payloads from temporary filesystems.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.1.2, Configure /tmp

## Key Variables
```yaml
linux_tmp_mounts_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
