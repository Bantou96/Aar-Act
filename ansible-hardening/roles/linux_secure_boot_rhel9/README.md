# linux_secure_boot_rhel9

## Purpose
Verifies that Secure Boot is enabled and enforces restrictive permissions on the /boot directory to protect the boot chain from tampering.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.5.1, Ensure Secure Boot is enabled

## Key Variables
```yaml
linux_secure_boot_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
