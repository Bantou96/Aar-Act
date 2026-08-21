# Role: linux_fail2ban_ubuntu

## Purpose

Installs and configures Fail2ban on Ubuntu/Debian systems to provide dynamic brute-force protection:
- Installs `fail2ban`
- Configures an SSH jail that monitors `/var/log/auth.log` for failed login attempts
- Bans offending IPs via `iptables` / `nftables` after configurable thresholds
- Optionally sends email alerts on bans
- Works alongside UFW (configured by `linux_firewall_ubuntu`)

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

Not directly mapped to a CIS section, provides defence-in-depth against SSH brute-force attacks that complement CIS controls 5.1.x (SSH hardening) and 3.5.x (firewall).

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_fail2ban_ssh_enabled` | `true` | Enable the SSH jail |
| `linux_fail2ban_ssh_port` | `ssh` | SSH port (or numeric port) to watch |
| `linux_fail2ban_ssh_filter` | `sshd` | Fail2ban filter to use |
| `linux_fail2ban_ssh_logpath` | `/var/log/auth.log` | Log file to monitor |
| `linux_fail2ban_ssh_maxretry` | `5` | Failed attempts before banning |
| `linux_fail2ban_ssh_bantime` | `3600` | Ban duration in seconds (1 hour) |
| `linux_fail2ban_ssh_findtime` | `600` | Sliding window in seconds for counting failures |
| `linux_fail2ban_backend` | `systemd` | Log backend (`systemd` or `auto`) |
| `linux_fail2ban_destemail` | `root@localhost` | Email recipient for ban notifications |
| `linux_fail2ban_sendername` | `CyberAar-Fail2ban` | Sender name for notification emails |
| `linux_fail2ban_action` | `%(action_)s` | Action to take on ban (ban only, ban+email, ban+email+whois) |
| `linux_fail2ban_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_fail2ban_ssh_maxretry: 3
linux_fail2ban_ssh_bantime: 86400     # 24 hours
linux_fail2ban_ssh_findtime: 3600     # Within 1 hour

# Send email notifications to the SOC
linux_fail2ban_destemail: "soc@example.sn"
linux_fail2ban_action: "%(action_mwl)s"   # ban + email + whois + log lines

# Non-standard SSH port
linux_fail2ban_ssh_port: "2222"
```

## Ubuntu-Only Role

This role has **no RHEL9 counterpart** in the current collection. On RHEL9, brute-force protection is provided by `pam_faillock` (configured by `linux_authselect_rhel9`) combined with `firewalld` rich rules.

Fail2ban is particularly useful on Ubuntu/Debian because UFW does not natively support dynamic IP banning based on log events.

## Interaction with UFW

Fail2ban and UFW can coexist. By default, Fail2ban uses `iptables` directly. To integrate properly with UFW, set the banaction in your override:

```yaml
# Use UFW as the banaction backend
linux_fail2ban_action: "ufw"
```

This requires the `ufw` action file to be present (available in `fail2ban` >= 0.9.x on Ubuntu 20.04+).
