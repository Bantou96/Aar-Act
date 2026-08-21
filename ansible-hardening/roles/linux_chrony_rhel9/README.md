# linux_chrony_rhel9

## Purpose
Installs and configures Chrony as a secure NTP client with restricted server access and authentication to ensure accurate and tamper-resistant system time synchronization.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 2.1.1, Ensure time synchronization is in use

## Key Variables
```yaml
linux_chrony_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
