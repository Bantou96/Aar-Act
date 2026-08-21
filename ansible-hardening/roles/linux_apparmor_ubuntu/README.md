# linux_apparmor_ubuntu

## Purpose
Ensures AppArmor is enabled and running in enforce mode, and enforces all available profiles to provide mandatory access control (MAC) for system processes.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.6, Mandatory Access Control

## Key Variables
```yaml
linux_apparmor_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
