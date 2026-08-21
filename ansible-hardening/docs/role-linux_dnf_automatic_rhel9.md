# Role: linux_dnf_automatic_rhel9

## Purpose

Configures `dnf-automatic` for unattended security updates on RHEL 9 family systems:
- Installs the `dnf-automatic` package
- Deploys a CIS-aligned `/etc/dnf/automatic.conf`
- Enables and starts the `dnf-automatic-install.timer` systemd timer
- Applies only security patches by default (safe for production servers)
- Optionally sends email notifications on upgrades or errors

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.9.1 Ensure package manager repositories are configured
- 1.9.2 Ensure updates, patches, and additional security software are installed

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_dnf_automatic_enabled` | `true` | Enable the dnf-automatic timer |
| `linux_dnf_automatic_apply_updates` | `security` | Update scope: `security` / `default` (all) |
| `linux_dnf_automatic_email_notify` | `true` | Send email notifications after updates |
| `linux_dnf_automatic_email_to` | `root@localhost` | Email recipient for update notifications |
| `linux_dnf_automatic_email_from` | `dnf-automatic@<fqdn>` | Sender address for notification emails |
| `linux_dnf_automatic_random_sleep` | `300` | Random delay in seconds before applying (avoids thundering herd) |
| `linux_dnf_automatic_schedule` | `daily` | Timer frequency (`daily` / `weekly`) |
| `linux_dnf_automatic_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Security updates only: safe for production
linux_dnf_automatic_apply_updates: "security"
linux_dnf_automatic_email_notify: true
linux_dnf_automatic_email_to: "soc@example.sn"

# On non-critical dev servers: apply all updates
linux_dnf_automatic_apply_updates: "default"
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Role name | `linux_dnf_automatic_rhel9` | `linux_unattended_upgrades_ubuntu` |
| Package | `dnf-automatic` | `unattended-upgrades`, `apt-listchanges` |
| Config file | `/etc/dnf/automatic.conf` | `/etc/apt/apt.conf.d/50unattended-upgrades` |
| Timer unit | `dnf-automatic-install.timer` | APT periodic cron (not a systemd timer) |
| Reboot support | Not configured (dnf-automatic does not reboot) | `linux_unattended_upgrades_reboot: true` available |
| Auto-remove | Not applicable | `linux_unattended_upgrades_autoremove: true` |

See [`role-linux_unattended_upgrades_ubuntu.md`](role-linux_unattended_upgrades_ubuntu.md) for the Ubuntu/Debian equivalent.
