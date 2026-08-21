# linux_sudo_hardening_rhel9

## Purpose
Hardens sudo configuration by enabling use_pty, configuring a dedicated sudo logfile, and validating sudoers files with visudo to prevent privilege escalation abuse.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.3.2–1.3.3, Configure sudo

## Key Variables
```yaml
linux_sudo_hardening_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
