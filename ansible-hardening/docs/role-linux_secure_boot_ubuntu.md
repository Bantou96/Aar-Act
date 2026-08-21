# Role: linux_secure_boot_ubuntu

## Purpose

Verifies and documents Secure Boot status on Ubuntu/Debian systems:
- Checks whether Secure Boot is enabled (firmware-level, cannot be enforced via software)
- Issues a warning if Secure Boot is not active
- Enforces strict permissions on GRUB configuration files (`/boot/grub/grub.cfg`)
- Ensures only root can read or modify boot configuration

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.5.1 Ensure Secure Boot is enabled
- 1.5.3 Ensure permissions on bootloader config are configured

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_secure_boot_warn_if_disabled` | `true` | Emit a warning (not a failure) if Secure Boot is not enabled |
| `linux_secure_boot_grub_dir` | `/boot/grub` | GRUB directory path |
| `linux_secure_boot_grub_cfg` | `/boot/grub/grub.cfg` | GRUB config file path |
| `linux_secure_boot_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml

# Warn but do not fail if Secure Boot is off (e.g. older hardware)
linux_secure_boot_warn_if_disabled: true

# For EFI systems with a non-standard GRUB path
linux_secure_boot_grub_cfg: "/boot/efi/EFI/ubuntu/grub.cfg"

# Skip entirely on VMs where Secure Boot is not applicable
linux_secure_boot_disabled: true
```

## Important Notes

Secure Boot is a firmware/UEFI feature that **cannot be enabled or disabled by Ansible**. This role can only:
1. Check its current status and warn if it is off
2. Ensure the GRUB configuration file has correct permissions (mode 0400, root:root)

To enable Secure Boot, it must be configured in the server's UEFI/BIOS settings. For virtual machines, Secure Boot must be enabled in the hypervisor configuration.

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| GRUB config path | `/boot/grub/grub.cfg` | `/boot/grub2/grub.cfg` |
| Secure Boot check | `mokutil --sb-state` | `mokutil --sb-state` (same) |
| Variables | Identical | Identical |
