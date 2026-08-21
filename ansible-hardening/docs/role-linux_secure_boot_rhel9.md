# Role: linux_secure_boot_rhel9

## Purpose

Verifies and documents Secure Boot status on RHEL 9 family systems:
- Checks whether Secure Boot is enabled (firmware-level, cannot be enforced via software)
- Optionally fails the play if Secure Boot is not active
- Enforces strict permissions on GRUB configuration files (`/boot/grub2/grub.cfg`)
- Ensures only root can read or modify boot configuration

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.4.1 Ensure permissions on bootloader config are configured
- 1.5.1 Ensure Secure Boot is enabled

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_secure_boot_enabled` | `true` | Run the Secure Boot check |
| `linux_secure_boot_enforce` | `true` | Fail the play if Secure Boot is not active |
| `linux_secure_boot_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Warn but do not fail on older hardware without UEFI Secure Boot
linux_secure_boot_enforce: false

# Skip entirely on VMs where Secure Boot is managed by the hypervisor
linux_secure_boot_disabled: true
```

## Important Notes

Secure Boot is a firmware/UEFI feature that **cannot be enabled or disabled by Ansible**. This role can only:
1. Check the current status using `mokutil --sb-state`
2. Fail the play (or warn) if it is not enabled
3. Enforce correct permissions on the GRUB config file

To enable Secure Boot, it must be configured in the server's UEFI/BIOS settings or hypervisor configuration.

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| GRUB config path | `/boot/grub2/grub.cfg` | `/boot/grub/grub.cfg` |
| Secure Boot check | `mokutil --sb-state` | `mokutil --sb-state` (same) |
| Fail variable | `linux_secure_boot_enforce: true` (fail by default) | `linux_secure_boot_warn_if_disabled: true` (warn only) |
| Variables | `linux_secure_boot_enforce` | `linux_secure_boot_warn_if_disabled`, `linux_secure_boot_grub_cfg` |
