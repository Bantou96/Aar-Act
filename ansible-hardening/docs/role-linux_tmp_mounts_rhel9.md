# Role: linux_tmp_mounts_rhel9

## Purpose

Hardens temporary filesystem mount points on RHEL 9 family systems to prevent privilege escalation and code execution from world-writable directories:
- Ensures `/tmp`, `/var/tmp`, and `/dev/shm` are mounted with `noexec`, `nosuid`, and `nodev` options
- Uses `ansible.posix.mount` to persist options in `/etc/fstab`
- Remounts filesystems immediately after fstab update (no reboot required)
- Verifies applied options with `findmnt`

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.1.2.1 Ensure `/tmp` is a separate partition
- 1.1.2.2 Ensure `nodev` option is set on `/tmp` partition
- 1.1.2.3 Ensure `nosuid` option is set on `/tmp` partition
- 1.1.2.4 Ensure `noexec` option is set on `/tmp` partition
- 1.1.5.1 Ensure `nodev` option is set on `/var/tmp` partition
- 1.1.5.2 Ensure `nosuid` option is set on `/var/tmp` partition
- 1.1.5.3 Ensure `noexec` option is set on `/var/tmp` partition
- 1.1.8.1 Ensure `nodev` option is set on `/dev/shm` partition
- 1.1.8.2 Ensure `nosuid` option is set on `/dev/shm` partition
- 1.1.8.3 Ensure `noexec` option is set on `/dev/shm` partition

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_tmp_mounts_enabled` | `true` | Enable tmp mount hardening (set `false` to skip mount tasks only) |
| `linux_tmp_mount_options` | `[defaults, noexec, nosuid, nodev]` | Mount flags applied to all tmp paths |
| `linux_tmp_mount_paths` | `[/tmp, /var/tmp, /dev/shm]` | Filesystems to harden |
| `linux_home_nodev_enabled` | `true` | Set `nodev` on `/home` partition (CIS 1.1.14) |
| `linux_sticky_bit_enabled` | `true` | Ensure sticky bit on all world-writable directories (CIS 1.1.21) |
| `linux_tmp_mounts_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Defaults are CIS-compliant: no changes needed
linux_tmp_mount_options:
  - defaults
  - noexec
  - nosuid
  - nodev

# Add size limit on servers with small root partitions
linux_tmp_mount_options:
  - defaults
  - noexec
  - nosuid
  - nodev
  - size=2G
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| `/tmp` method | `ansible.posix.mount` (fstab-based) | Systemd `tmp.mount` drop-in override |
| `/dev/shm` method | `ansible.posix.mount` (fstab-based) | `lineinfile` in `/etc/fstab` |
| `/var/tmp` | Included in RHEL9 (`linux_tmp_mount_paths`) | Not in default Ubuntu list |
| Variables | `linux_tmp_mount_options` (list) | `linux_tmp_mounts_options` (comma-separated string) |
| Size limit | Via `size=2G` in options list | `linux_tmp_mounts_size: "2G"` variable |
