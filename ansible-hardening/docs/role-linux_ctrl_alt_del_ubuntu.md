# Role: linux_ctrl_alt_del_ubuntu

## Purpose

Prevents accidental or malicious system reboot via the Ctrl+Alt+Del key combination on Ubuntu/Debian systems:
- Masks `ctrl-alt-del.target` via systemd so it cannot be activated even if re-enabled elsewhere
- Reloads the systemd daemon to apply the mask immediately

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.6.1 Ensure system-wide crypto policy is not over-ridden (indirect, system integrity)
- Aligns with ANSSI hardening recommendations for interactive console hardening

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_ctrl_alt_del_disabled` | `false` | Set `true` to skip this role entirely |

This role has no configurable behaviour beyond the enable/disable toggle, the action (masking `ctrl-alt-del.target`) is always the same.

## Usage Example

```yaml
# Skip on a workstation where Ctrl+Alt+Del is desired behaviour
linux_ctrl_alt_del_disabled: true
```

## Implementation Note

This role uses `ansible.builtin.systemd: masked: true` (idempotent, check-mode aware) rather than a raw `systemctl mask` command. This means:
- Re-running the role reports `ok` (not `changed`) when the target is already masked
- Works correctly in `--check` mode

## Differences from RHEL9 Counterpart

The variables and implementation are identical. Both roles use `ansible.builtin.systemd: masked: true` on `ctrl-alt-del.target`.
