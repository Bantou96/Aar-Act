# linux_core_dumps_rhel9

## Purpose
Restricts core dump creation via PAM limits and sysctl settings to prevent sensitive memory contents from being written to disk.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.5.1, Ensure core dumps are restricted

## Key Variables
```yaml
linux_core_dumps_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
