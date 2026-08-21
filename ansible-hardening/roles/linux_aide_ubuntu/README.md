# linux_aide_ubuntu

## Purpose
Installs and configures AIDE (Advanced Intrusion Detection Environment) to perform file integrity monitoring and detect unauthorized changes to critical system files.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.4, Filesystem Integrity Checking

## Key Variables
```yaml
linux_aide_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
