# Role: linux_bootloader_password_rhel9

## Purpose

Protects the GRUB2 bootloader with a PBKDF2-hashed password on RHEL 9 family systems to prevent unauthorised editing of boot parameters or booting into single-user/recovery mode:
- Fails early if `LINUX_BOOTLOADER_PASSWORD` environment variable is not set
- Generates a PBKDF2 hash using `grub2-mkpasswd-pbkdf2`
- Deploys `/etc/grub.d/01_users` with the hashed password and superuser definition
- Rebuilds GRUB config via `grub2-mkconfig` (EFI or BIOS path auto-detected)
- Enforces strict permissions (`0600 root:root`) on `/boot/grub2/grub.cfg`

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.4.1 Ensure permissions on bootloader config are configured
- 1.4.2 Ensure bootloader password is set
- 1.4.3 Ensure authentication is required for single-user mode

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_bootloader_password_enabled` | `true` | Enable GRUB password protection |
| `linux_bootloader_superuser` | `root` | GRUB superuser name |
| `linux_bootloader_password` | `env:LINUX_BOOTLOADER_PASSWORD` | Password: must be set via environment variable or vault; role fails if absent |
| `linux_bootloader_disable_nolog` | `false` | Disable `no_log` on sensitive tasks (debug only: never in production) |
| `linux_single_user_auth` | `true` | Require authentication for single-user mode (CIS 1.4.3) |
| `linux_bootloader_password_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```bash
# Set password securely before running: never commit this value
read -sr LINUX_BOOTLOADER_PASSWORD ; export LINUX_BOOTLOADER_PASSWORD

bash scripts/run-hardening.sh -u rockylinux -t rocky-vm-01 -T boot

# Unset after run
unset LINUX_BOOTLOADER_PASSWORD
```

```yaml
# group_vars/rhel_servers.yml

# Use a non-default superuser name for obscurity
linux_bootloader_superuser: "grubadmin"

# Disable on VMs where bootloader is managed by the hypervisor
linux_bootloader_password_disabled: true
```

## Important Notes

The password is **never stored in variables files or vault by default**. It is read exclusively from the `LINUX_BOOTLOADER_PASSWORD` environment variable at runtime. If the variable is empty or unset the role fails immediately with a clear error message.

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| GRUB package | `grub2-tools` | `grub2-common` |
| Hash command | `grub2-mkpasswd-pbkdf2` | `grub-mkpasswd-pbkdf2` |
| Config rebuild (BIOS) | `grub2-mkconfig -o /boot/grub2/grub.cfg` | `update-grub` |
| Config rebuild (EFI) | `grub2-mkconfig -o /boot/efi/EFI/<distro>/grub.cfg` | `update-grub` |
| Users file | `/etc/grub.d/01_users` | `/etc/grub.d/01_users` |
| Variables | Identical structure | Identical structure |
