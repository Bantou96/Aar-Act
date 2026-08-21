# linux_firewall_ubuntu

## Purpose
Configures UFW with a default-deny inbound policy and applies explicit allow and deny rules to enforce a minimal network access control baseline.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 3.5, Firewall Configuration

## Key Variables
```yaml
linux_firewall_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
