# Role: linux_sudo_hardening_ubuntu

## Purpose

Hardens the sudo configuration on Ubuntu/Debian to meet CIS benchmark requirements:
- Ensures sudo is installed
- Forces sudo to use a pseudo-terminal (use_pty) to prevent privilege escalation via background processes
- Enables sudo log file to record all sudo commands for auditing

## Supported Platforms

| Platform | Versions |
|----------|----------|
| Ubuntu   | 20.04 LTS, 22.04 LTS, 24.04 LTS |
| Debian   | 11 (Bullseye), 12 (Bookworm) |

## CIS Coverage

- 1.3.1 Ensure sudo is installed (L1)
- 1.3.2 Ensure sudo commands use pty (L1)
- 1.3.3 Ensure sudo log file exists (L1)

## Variables

| Variable                         | Default             | Description                                         |
|----------------------------------|---------------------|-----------------------------------------------------|
| `linux_sudo_install`             | `true`              | Ensure the sudo package is installed                |
| `linux_sudo_use_pty`             | `true`              | Add `Defaults use_pty` to sudoers drop-in           |
| `linux_sudo_logfile_enabled`     | `true`              | Add `Defaults logfile=...` to sudoers drop-in       |
| `linux_sudo_logfile`             | `"/var/log/sudo.log"` | Path for the sudo audit log                       |
| `linux_sudo_hardening_disabled`  | `false`             | Set to `true` to skip entire role                   |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_sudo_use_pty: true
linux_sudo_logfile_enabled: true
linux_sudo_logfile: "/var/log/sudo.log"
```

```yaml
# Run only sudo hardening
bash scripts/run-hardening.sh -u ubuntu -t ubuntu-vm-01 -T sudo
```

## Testing

```bash
# Verify the drop-in file was created
cat /etc/sudoers.d/99-cis-hardening

# Verify use_pty is set
sudo grep -E '^Defaults\s+use_pty' /etc/sudoers.d/99-cis-hardening

# Verify logfile is set
sudo grep -E '^Defaults\s+logfile' /etc/sudoers.d/99-cis-hardening

# Verify logfile is written after a sudo command
sudo ls /tmp
tail -1 /var/log/sudo.log
```

## Notes

- All sudoers modifications are written to `/etc/sudoers.d/99-cis-hardening` and validated with `visudo -cf` before applying, the vendor-managed `/etc/sudoers` file is never modified
- The logfile is append-only, it captures user, command, working directory, and TTY for every sudo invocation
- The `use_pty` directive prevents attackers from using sudo in background scripts that inherit a controlling terminal from a compromised process

## Differences from RHEL9 Counterpart

| Aspect | RHEL9 (`linux_sudo_hardening_rhel9`) | Ubuntu (`linux_sudo_hardening_ubuntu`) |
|--------|--------------------------------------|----------------------------------------|
| Sudoers target | `/etc/sudoers.d/99-cis-hardening` | `/etc/sudoers.d/99-cis-hardening` |
| Package name | `sudo` | `sudo` |
| Validation | `visudo -cf` | `visudo -cf` |
| Implementation | Identical | Identical |

The implementation is functionally identical on both platforms. Both use the drop-in pattern to avoid modifying the vendor-managed `/etc/sudoers`.
