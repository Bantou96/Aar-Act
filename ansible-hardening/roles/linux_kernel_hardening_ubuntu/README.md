# linux_kernel_hardening_ubuntu

## Purpose
Applies sysctl kernel hardening parameters and blacklists dangerous kernel modules to reduce the attack surface exposed by the Linux kernel.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.5, Additional Process Hardening, CIS Section 3.3, Uncommon Network Protocols

## Key Variables
```yaml
linux_kernel_hardening_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
