# linux_aide_rhel9

## Purpose
Installs and configures AIDE (Advanced Intrusion Detection Environment) to perform file integrity monitoring and detect unauthorized changes to critical system files.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.4, Filesystem Integrity Checking

## Key Variables
```yaml
linux_aide_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
