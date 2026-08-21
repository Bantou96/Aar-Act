# Role: linux_chrony_rhel9

## Purpose

Installs and hardens Chrony (the default NTP implementation on RHEL 9) for accurate and authenticated time synchronisation:
- Installs `chrony` package
- Deploys a CIS-aligned `chrony.conf` with trusted NTP sources
- Optionally enables NTS (Network Time Security) for authenticated time sync
- Restricts NTP query access to trusted networks only
- Enables and starts `chronyd`; disables `systemd-timesyncd` if present
- Verifies synchronisation with `chronyc tracking` after service start

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 2.1.1 Ensure a single time synchronization daemon is in use
- 2.1.2 Ensure chrony is configured with authorized timeserver
- 2.1.3 Ensure chrony is not run as the root user

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_chrony_mode` | `client` | Operating mode: `client` / `server` / `both` |
| `linux_chrony_servers` | `[pool.ntp.org iburst]` | List of NTP server/pool directives |
| `linux_chrony_use_nts` | `true` | Append `nts` keyword to each server line for authenticated time |
| `linux_chrony_allow` | `[127.0.0.1]` | Networks allowed to query this server (restrict directive) |
| `linux_chrony_driftfile` | `/var/lib/chrony/drift` | Path to the drift compensation file |
| `linux_chrony_logdir` | `/var/log/chrony` | Directory for Chrony log files |
| `linux_chrony_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_chrony_servers:
  - "time.google.com iburst"
  - "time.cloudflare.com iburst"

linux_chrony_use_nts: true

# On internal servers without internet access: use internal NTP
linux_chrony_servers:
  - "ntp1.internal.example.sn iburst"
  - "ntp2.internal.example.sn iburst"
linux_chrony_use_nts: false
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Package | `chrony` | `chrony` |
| Config file | `/etc/chrony.conf` | `/etc/chrony/chrony.conf` |
| Service name | `chronyd` | `chrony` |
| Competing service disabled | `systemd-timesyncd` (if present) | `systemd-timesyncd` (explicitly stopped) |
| Variables | Identical structure | Identical structure |
