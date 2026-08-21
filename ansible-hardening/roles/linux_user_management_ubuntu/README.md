# linux_user_management_ubuntu

## Purpose
Enforces user account security by locking the root account, securing system accounts, locking inactive accounts, and applying a strong password aging policy.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 5.4, User Accounts and Environment, CIS Section 5.5, User Accounts and Environment

## Key Variables
```yaml
linux_user_management_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
