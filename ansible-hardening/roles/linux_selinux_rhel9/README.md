# linux_selinux_rhel9

## Purpose
Configures SELinux in enforcing mode, sets targeted policy booleans, and runs restorecon to provide mandatory access control (MAC) protection for system processes.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.6, Mandatory Access Control

## Key Variables
```yaml
linux_selinux_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
