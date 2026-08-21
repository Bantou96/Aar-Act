# Role: linux_bootloader_password_ubuntu

## Purpose

Protects the GRUB2 bootloader with a password on Ubuntu/Debian systems:
- Sets a GRUB superuser with a hashed (PBKDF2) password
- Prevents unauthorised boot parameter modification and single-user mode access
- Supports both BIOS (`/boot/grub/grub.cfg`) and EFI (`/boot/efi/EFI/ubuntu/grub.cfg`) layouts

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.5.2 Ensure bootloader password is set
- 1.5.3 Ensure authentication is required for single user mode

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_bootloader_superuser` | `root` | GRUB superuser username |
| `linux_bootloader_password` | `lookup('env', 'LINUX_BOOTLOADER_PASSWORD')` | GRUB password: **read from environment variable, never hardcode** |
| `linux_bootloader_disable_nolog` | `false` | Set `true` in test environments to allow password in logs |
| `linux_bootloader_grub_cfg_path` | `/boot/grub/grub.cfg` | Path to GRUB config (BIOS default: override for EFI) |
| `linux_bootloader_password_disabled` | `false` | Set `true` to skip this role entirely |

## Sensitive Variable Handling

The bootloader password must **never** be stored in inventory or committed to version control. Set it in your shell before running the pipeline:

```bash
# Set before running
read -sr LINUX_BOOTLOADER_PASSWORD
export LINUX_BOOTLOADER_PASSWORD

# Run hardening
bash scripts/run-hardening.sh -u ubuntu -t ubuntu-vm-01 -s 2

# Unset immediately after
unset LINUX_BOOTLOADER_PASSWORD
```

If `LINUX_BOOTLOADER_PASSWORD` is not set, `run-hardening.sh` warns and the role is skipped automatically.

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_bootloader_superuser: "grubadmin"

# For EFI systems
linux_bootloader_grub_cfg_path: "/boot/efi/EFI/ubuntu/grub.cfg"

# Disable on VMs where bootloader protection is not relevant
linux_bootloader_password_disabled: true
```

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| GRUB update command | `update-grub` | `grub2-mkconfig -o /boot/grub2/grub.cfg` |
| Config path (BIOS) | `/boot/grub/grub.cfg` | `/boot/grub2/grub.cfg` |
| Config path (EFI) | `/boot/efi/EFI/ubuntu/grub.cfg` | `/boot/efi/EFI/redhat/grub.cfg` |
| Password hash command | `grub-mkpasswd-pbkdf2` | `grub2-mkpasswd-pbkdf2` |
| Variables | Identical | Identical |
