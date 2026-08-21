# linux_authselect_ubuntu

## Purpose
Configures PAM with pwquality password complexity requirements and pam_faillock account lockout to enforce strong authentication policies.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 5.3, Configure PAM, CIS Section 5.4, User Accounts and Environment

## Key Variables
```yaml
linux_authselect_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
