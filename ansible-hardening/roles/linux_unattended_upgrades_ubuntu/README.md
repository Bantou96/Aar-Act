# linux_unattended_upgrades_ubuntu

## Purpose
Installs and configures unattended-upgrades to automatically apply security updates on a scheduled basis, ensuring critical patches are applied without manual intervention.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.9, Ensure updates, patches, and additional security software are installed

## Key Variables
```yaml
linux_unattended_upgrades_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
