# linux_ctrl_alt_del_ubuntu

## Purpose
Disables the Ctrl+Alt+Del keyboard shortcut to prevent accidental or malicious system reboots from the console.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.6.1, Ensure system-wide crypto policy is not legacy

## Key Variables
```yaml
linux_ctrl_alt_del_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
