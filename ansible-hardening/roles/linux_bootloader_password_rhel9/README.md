# linux_bootloader_password_rhel9

## Purpose
Sets a password on GRUB2 bootloader to prevent unauthorized editing of boot parameters  
or booting into single-user/recovery mode without authentication.

## Targeted OS
RHEL 9 / AlmaLinux 9 / Rocky Linux 9

## CIS References (v2.0.0)
- 1.4.2 Ensure bootloader password is set (L1)
- 1.4.1 Ensure permissions on bootloader config
- Protects against evil maid / offline attacks

## Idempotence Features
- Generates PBKDF2 hash once
- Only creates /etc/grub.d/01_users if missing or password changed
- Rebuilds grub.cfg only when needed

## Security – Password Handling
- **Never hardcode** the password in defaults or git
- Read the password into the environment rather than typing it on the command line,
  where shell history would keep it: `read -sr LINUX_BOOTLOADER_PASSWORD ; export LINUX_BOOTLOADER_PASSWORD`
- Or use **Ansible Vault** (preferred for teams/CI)
- All password-related tasks use `no_log: true` by default (controlled by `linux_bootloader_disable_nolog`)
- If you must debug: set `linux_bootloader_disable_nolog: true` temporarily (logs will show hash)

## Variables Highlights
```yaml
linux_bootloader_password_enabled: true
linux_bootloader_superuser: "root"
