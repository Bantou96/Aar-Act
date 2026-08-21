# linux_cron_hardening_rhel9

## Purpose
Hardens cron and at scheduling services by setting strict directory permissions and enforcing an allow-list model to restrict job scheduling to authorized users only.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 5.1, Configure cron

## Key Variables
```yaml
linux_cron_hardening_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
