# linux_ip_forwarding_rhel9

## Purpose
Disables IP forwarding, ICMP redirects, and source routing via sysctl settings to prevent the host from being used as a network router or subject to redirect attacks.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 3.1, Network Parameters (Host Only), CIS Section 3.2, Network Parameters (Host and Router)

## Key Variables
```yaml
linux_ip_forwarding_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
