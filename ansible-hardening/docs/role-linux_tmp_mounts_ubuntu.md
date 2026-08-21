# Role: linux_tmp_mounts_ubuntu

## Purpose

Hardens temporary filesystem mount points on Ubuntu/Debian systems to prevent privilege escalation and code execution from world-writable directories:
- Ensures `/tmp` is mounted with `noexec`, `nosuid`, and `nodev` options
- Ensures `/dev/shm` is mounted with the same restrictive options
- Configures options persistently in `/etc/fstab` or via systemd drop-in

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.1.2.1 Ensure `/tmp` is a separate partition
- 1.1.2.2 Ensure `nodev` option is set on `/tmp` partition
- 1.1.2.3 Ensure `nosuid` option is set on `/tmp` partition
- 1.1.2.4 Ensure `noexec` option is set on `/tmp` partition
- 1.1.8 Ensure `nodev` option is set on `/dev/shm` partition
- 1.1.9 Ensure `nosuid` option is set on `/dev/shm` partition
- 1.1.10 Ensure `noexec` option is set on `/dev/shm` partition

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_tmp_mounts_options` | `defaults,noexec,nosuid,nodev` | Mount options applied to `/tmp` and `/dev/shm` |
| `linux_tmp_mounts_size` | `""` | Optional size limit for tmpfs (e.g. `2G`: empty = no limit) |
| `linux_tmp_mounts_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml

# Default options are sufficient for CIS compliance
linux_tmp_mounts_options: "defaults,noexec,nosuid,nodev"

# Limit /tmp size to 2GB on servers with small root filesystems
linux_tmp_mounts_size: "2G"
```

## Differences from RHEL9 Counterpart

The variables and behaviour are identical. Both roles configure `/tmp` and `/dev/shm` with the same mount options. The underlying systemd and fstab configuration mechanism is the same on both platforms.
