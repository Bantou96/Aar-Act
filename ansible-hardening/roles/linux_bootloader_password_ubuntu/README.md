# linux_bootloader_password_ubuntu

## Purpose
Configures a GRUB2 PBKDF2-hashed bootloader password for both BIOS and EFI systems to prevent unauthorized modification of boot parameters.

## Targeted OS
Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

## CIS Alignment
CIS Section 1.5.2, Ensure bootloader password is set

## Key Variables
```yaml
linux_bootloader_password_ubuntu_disabled: false   # set to true to skip this role
```

See `defaults/main.yml` for all tunable parameters.
