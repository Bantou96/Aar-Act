# linux_core_dumps_ubuntu

## Purpose
Restricts core dump creation via PAM limits and sysctl settings to prevent sensitive memory contents from being written to disk.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.5.1, Ensure core dumps are restricted

## Key Variables
```yaml
linux_core_dumps_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
