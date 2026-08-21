# linux_journald_rhel9

## Purpose
Configures systemd-journald with persistent log storage, compression, and rate limiting to ensure reliable and efficient system log retention.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 4.2.1.x, Configure journald

## Key Variables
```yaml
linux_journald_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
