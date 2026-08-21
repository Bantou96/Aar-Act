# linux_disable_unnecessary_services_ubuntu

## Purpose
Masks and disables legacy and unnecessary system daemons to reduce the attack surface by eliminating unneeded network services and local sockets.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 2.x, Special Purpose Services

## Key Variables
```yaml
linux_disable_unnecessary_services_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
