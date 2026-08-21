# linux_wireless_ubuntu

## Purpose
Disables wireless interfaces via rfkill and nmcli, blacklists wireless kernel modules, and rebuilds initramfs to eliminate wireless network access on servers that do not require it.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 3.1.2, Ensure wireless interfaces are disabled

## Key Variables
```yaml
linux_wireless_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
