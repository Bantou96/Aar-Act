# linux_journald_ubuntu

## Purpose
Configures systemd-journald with persistent log storage, compression, and rate limiting to ensure reliable and efficient system log retention.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 4.2.1.x, Configure journald

## Key Variables
```yaml
linux_journald_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
