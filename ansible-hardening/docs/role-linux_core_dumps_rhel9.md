# Role: linux_core_dumps_rhel9

## Purpose

Restricts core dump behaviour to prevent sensitive process memory from being written to disk on RHEL 9 family systems:
- Sets `* hard core 0` and `* soft core 0` in `/etc/security/limits.d/`
- Sets `fs.suid_dumpable = 0` via sysctl (disables core dumps for setuid programs)
- Sets `kernel.core_pattern = /dev/null` via sysctl (discards any core file that does get generated)
- Deploys a `systemd-coredump.conf.d` drop-in to set `Storage=none` and `ProcessSizeMax=0`

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.5.1 Ensure core dumps are restricted
- 1.5.2 Ensure address space layout randomisation (ASLR) is enabled

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_core_dumps_limit` | `0` | Hard/soft core file size limit (`0` = disabled) |
| `linux_core_suid_dumpable` | `0` | `fs.suid_dumpable`: disable setuid core dumps |
| `linux_core_pattern` | `/dev/null` | `kernel.core_pattern`: destination for core files |
| `linux_core_dumps_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Defaults are sufficient for CIS compliance: no changes needed
linux_core_dumps_limit: "0"
linux_core_suid_dumpable: "0"
linux_core_pattern: "/dev/null"
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| limits.d file | `/etc/security/limits.d/99-cis-coredump.conf` | `/etc/security/limits.d/99-cis-coredump.conf` |
| systemd drop-in | `/etc/systemd/coredump.conf.d/99-cis-coredump.conf` | `/etc/systemd/coredump.conf.d/99-cis-coredump.conf` |
| sysctl settings | `fs.suid_dumpable`, `kernel.core_pattern` | `fs.suid_dumpable`, `kernel.core_pattern` |
| Variables | Identical | Identical |

The role behaviour is identical on both platforms.
