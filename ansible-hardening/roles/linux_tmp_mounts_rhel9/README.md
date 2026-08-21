# linux_tmp_mounts_rhel9

## Purpose
Configures /tmp and /dev/shm with noexec, nodev, and nosuid mount options to prevent execution of malicious payloads from temporary filesystems.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.1.2, Configure /tmp

## Key Variables
```yaml
linux_tmp_mounts_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
