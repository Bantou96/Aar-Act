# linux_ipv6_ubuntu

## Purpose
Disables IPv6 networking via sysctl parameters, modprobe blacklisting, and update-initramfs to eliminate an unused protocol stack and reduce the network attack surface.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 3.3.1, Ensure IPv6 is disabled if not in use

## Key Variables
```yaml
linux_ipv6_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
