# linux_cron_hardening_ubuntu

## Purpose
Hardens cron and at scheduling services by setting strict directory permissions and enforcing an allow-list model to restrict job scheduling to authorized users only.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 5.1, Configure cron

## Key Variables
```yaml
linux_cron_hardening_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
