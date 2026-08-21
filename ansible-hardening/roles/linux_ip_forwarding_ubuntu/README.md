# linux_ip_forwarding_ubuntu

## Purpose
Disables IP forwarding, ICMP redirects, and source routing via sysctl settings to prevent the host from being used as a network router or subject to redirect attacks.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 3.1, Network Parameters (Host Only), CIS Section 3.2, Network Parameters (Host and Router)

## Key Variables
```yaml
linux_ip_forwarding_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
