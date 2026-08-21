# linux_fail2ban_ubuntu

## Purpose
Installs and configures Fail2ban with UFW backend integration to dynamically ban IP addresses after repeated authentication failures and protect against brute-force attacks.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS (complements firewall controls), Brute-force protection for SSH and other services

## Key Variables
```yaml
linux_fail2ban_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
