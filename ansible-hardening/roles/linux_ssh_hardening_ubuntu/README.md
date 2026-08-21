# linux_ssh_hardening_ubuntu

## Purpose
Applies deep SSH server hardening by enforcing strong ciphers, MACs, key exchange algorithms, authentication restrictions, and login banners to minimize SSH attack exposure.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 5.1, Configure SSH Server

## Key Variables
```yaml
linux_ssh_hardening_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
