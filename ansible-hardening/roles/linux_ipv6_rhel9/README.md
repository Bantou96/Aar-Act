# linux_ipv6_rhel9

## Purpose
Disables IPv6 networking via sysctl parameters and modprobe blacklisting to eliminate an unused protocol stack and reduce the network attack surface.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 3.3.1, Ensure IPv6 is disabled if not in use

## Key Variables
```yaml
linux_ipv6_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
