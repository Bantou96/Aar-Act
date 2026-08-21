# linux_ssh_hardening_rhel9

## Purpose
Applies deep SSH server hardening by enforcing strong ciphers, MACs, key exchange algorithms, authentication restrictions, and login banners to minimize SSH attack exposure.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 5.1, Configure SSH Server

## Key Variables
```yaml
linux_ssh_hardening_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
