# Role: linux_fail2ban_rhel9

## Purpose

Installs and configures `fail2ban` to dynamically ban IP addresses after repeated authentication failures on RHEL 9 family systems:
- Installs `fail2ban` with `firewalld` backend (native on RHEL 9)
- Deploys a CIS-aligned `jail.local` configuration
- Enables the `sshd` jail with strict ban time and retry limits
- Optionally enables a firewalld-synergy jail (bans IPs already rejected by firewalld)
- Optionally sends email notifications on bans

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 4.3.1 Ensure fail2ban is installed (supplemental, not directly in CIS benchmark)
- Directly mitigates brute-force attacks against SSH (supports CIS 5.1.x SSH hardening controls)

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_fail2ban_enabled` | `true` | Enable fail2ban service |
| `linux_fail2ban_backend` | `firewalld` | Ban backend: `firewalld` / `iptables` / `nftables` |
| `linux_fail2ban_bantime` | `3600` | Default ban duration in seconds (1 hour) |
| `linux_fail2ban_findtime` | `600` | Counting window in seconds (10 minutes) |
| `linux_fail2ban_maxretry` | `5` | Failures before ban (global default) |
| `linux_fail2ban_ignoreip` | `[127.0.0.1/8, ::1]` | IPs/CIDRs never banned: add management subnets here |
| `linux_fail2ban_jail_sshd_enabled` | `true` | Enable the sshd jail |
| `linux_fail2ban_jail_sshd_port` | `22` | SSH port monitored by the jail |
| `linux_fail2ban_jail_sshd_maxretry` | `4` | SSH-specific retry limit (stricter than global) |
| `linux_fail2ban_jail_sshd_bantime` | `86400` | SSH ban duration in seconds (24 hours) |
| `linux_fail2ban_jail_sshd_findtime` | `600` | SSH counting window in seconds |
| `linux_fail2ban_jail_firewalld_enabled` | `false` | Ban IPs firewalld already rejected (opt-in) |
| `linux_fail2ban_jail_firewalld_maxretry` | `3` | Retry limit for firewalld synergy jail |
| `linux_fail2ban_jail_firewalld_bantime` | `86400` | Ban duration for firewalld synergy jail |
| `linux_fail2ban_email_notify` | `false` | Send email on ban events |
| `linux_fail2ban_email_dest` | `root@localhost` | Email recipient for ban notifications |
| `linux_fail2ban_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_fail2ban_ignoreip:
  - "127.0.0.1/8"
  - "::1"
  - "192.168.10.0/24"   # Management VLAN, never ban

linux_fail2ban_jail_sshd_maxretry: "3"
linux_fail2ban_jail_sshd_bantime: "86400"

# Enable email alerts to SOC
linux_fail2ban_email_notify: true
linux_fail2ban_email_dest: "soc@example.sn"
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Default backend | `firewalld` | `systemd` (uses journald for log parsing) |
| Firewall integration | `firewalld` rich rules | `ufw` (via `ufw-action` or `iptables`) |
| Package source | EPEL or base repo | `apt` universe |
| Variables | Identical structure | Identical structure, `backend` default differs |
