# linux_dnf_automatic_rhel9

## Purpose
Installs and configures dnf-automatic to automatically apply security updates on a scheduled basis, ensuring critical patches are applied without manual intervention.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.9, Ensure updates, patches, and additional security software are installed

## Key Variables
```yaml
linux_dnf_automatic_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
