# Role: linux_sudo_hardening_rhel9

## Purpose

Hardens the sudo configuration on RHEL9/AlmaLinux/Rocky Linux to meet CIS benchmark requirements:
- Ensures sudo is installed
- Forces sudo to use a pseudo-terminal (use_pty) to prevent privilege escalation via background processes
- Enables sudo log file to record all sudo commands for auditing

## CIS Coverage

- 1.3.1 Ensure sudo is installed (L1)
- 1.3.2 Ensure sudo commands use pty (L1)
- 1.3.3 Ensure sudo log file exists (L1)

## Variables

| Variable                         | Default                | Description                                         |
|----------------------------------|------------------------|-----------------------------------------------------|
| linux_sudo_install               | true                   | Ensure the sudo package is installed                |
| linux_sudo_use_pty               | true                   | Add `Defaults use_pty` to /etc/sudoers              |
| linux_sudo_logfile_enabled       | true                   | Add `Defaults logfile=...` to /etc/sudoers          |
| linux_sudo_logfile               | "/var/log/sudo.log"    | Path for the sudo audit log                         |
| linux_sudo_hardening_disabled    | false                  | Set to true to skip entire role                     |

## Usage Example

```yaml
- role: linux_sudo_hardening_rhel9
  vars:
    linux_sudo_use_pty: true
    linux_sudo_logfile: "/var/log/sudo.log"
```

## Testing

```bash
# Verify use_pty is set
sudo grep -E '^Defaults\s+use_pty' /etc/sudoers

# Verify logfile is set
sudo grep -E '^Defaults\s+logfile' /etc/sudoers

# Verify logfile is written after a sudo command
sudo ls /tmp
tail -1 /var/log/sudo.log
```

## Notes

- All sudoers modifications are validated with `visudo -cf` before applying to prevent syntax errors
- The logfile is append-only, it captures user, command, working directory, and TTY for every sudo invocation
- The `use_pty` directive prevents attackers from using sudo in background scripts that inherit a controlling terminal from a compromised process