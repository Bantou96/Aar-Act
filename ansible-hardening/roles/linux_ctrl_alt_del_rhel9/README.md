# linux_ctrl_alt_del_rhel9

## Purpose
Disables the Ctrl+Alt+Del keyboard shortcut to prevent accidental or malicious system reboots from the console.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.6.1, Ensure system-wide crypto policy is not legacy

## Key Variables
```yaml
linux_ctrl_alt_del_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
