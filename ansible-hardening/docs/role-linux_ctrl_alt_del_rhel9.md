# Role: linux_ctrl_alt_del_rhel9

## Purpose

Prevents accidental or malicious system reboot via the Ctrl+Alt+Del key combination on RHEL 9 family systems:
- Masks `ctrl-alt-del.target` via `ansible.builtin.systemd` (idempotent, check-mode aware)
- Reloads the systemd daemon after masking
- Prevents both keyboard-triggered and D-Bus-triggered reboots

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.6.1 Ensure system-wide crypto policy is not set to legacy
- 4.6.1 Ensure ctrl-alt-del is disabled (RHEL 9 CIS Benchmark)

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_ctrl_alt_del_enabled` | `true` | Apply the masking (set `false` only for testing) |
| `linux_ctrl_alt_del_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Default settings are sufficient: no changes needed
linux_ctrl_alt_del_enabled: true
```

## Verification

```bash
systemctl is-enabled ctrl-alt-del.target   # → masked
systemctl status ctrl-alt-del.target        # → masked; vendor preset: disabled
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Mechanism | `ansible.builtin.systemd: masked: true` | `ansible.builtin.systemd: masked: true` |
| Target | `ctrl-alt-del.target` | `ctrl-alt-del.target` |
| Variables | Identical | Identical |

The role implementation is identical on both platforms.
