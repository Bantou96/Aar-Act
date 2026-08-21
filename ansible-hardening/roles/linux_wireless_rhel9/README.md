# linux_wireless_rhel9

## Purpose
Disables wireless interfaces via nmcli and rfkill and blacklists wireless kernel modules to eliminate wireless network access on servers that do not require it.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 3.1.2, Ensure wireless interfaces are disabled

## Key Variables
```yaml
linux_wireless_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
