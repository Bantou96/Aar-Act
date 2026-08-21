# linux_sudo_hardening_ubuntu

## Purpose
Hardens sudo configuration by enabling use_pty, configuring a dedicated sudo logfile, and validating sudoers files with visudo to prevent privilege escalation abuse.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.3.2–1.3.3, Configure sudo

## Key Variables
```yaml
linux_sudo_hardening_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
