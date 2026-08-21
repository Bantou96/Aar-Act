# linux_login_banner_ubuntu

## Purpose
Configures legal warning banners for SSH, local console login prompts, and MOTD to satisfy regulatory requirements and deter unauthorized access.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.7, Warning Banners

## Key Variables
```yaml
linux_login_banner_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
