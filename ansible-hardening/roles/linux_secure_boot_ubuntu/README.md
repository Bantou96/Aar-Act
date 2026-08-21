# linux_secure_boot_ubuntu

## Purpose
Verifies that Secure Boot is enabled and enforces restrictive permissions on the /boot directory to protect the boot chain from tampering.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.5.1, Ensure Secure Boot is enabled

## Key Variables
```yaml
linux_secure_boot_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
