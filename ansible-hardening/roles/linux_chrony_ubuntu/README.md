# linux_chrony_ubuntu

## Purpose
Installs and configures Chrony as a secure NTP client with restricted server access and authentication to ensure accurate and tamper-resistant system time synchronization.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 2.1.1, Ensure time synchronization is in use

## Key Variables
```yaml
linux_chrony_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
