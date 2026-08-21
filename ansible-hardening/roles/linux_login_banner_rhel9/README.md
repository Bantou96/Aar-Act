# linux_login_banner_rhel9

## Purpose
Configures legal warning banners for SSH and local console login prompts to satisfy regulatory requirements and deter unauthorized access.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS Alignment
CIS Section 1.7, Warning Banners

## Key Variables
```yaml
linux_login_banner_rhel9_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
