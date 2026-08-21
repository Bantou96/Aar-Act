# Role: linux_firewalld_rhel9

## Purpose

Configures `firewalld` to minimise the attack surface on RHEL 9 family systems:
- Installs and enables `firewalld`
- Sets the default zone (default: `drop`: blocks all unsolicited inbound traffic)
- Allows only explicitly defined services and ports
- Restricts SSH to trusted source CIDRs via rich rules (highly recommended)
- Applies SSH connection rate limiting
- Enables logging of dropped packets for monitoring
- Removes unexpected services from the default zone (cleanup)

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 4.2.1 Ensure firewalld is installed and enabled
- 4.2.2 Ensure default zone is set
- 4.2.3 Ensure unnecessary services and ports are not allowed
- 4.3.1 Ensure firewalld default zone is set to drop or similar

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_firewalld_enabled` | `true` | Enable firewalld rule management |
| `linux_firewalld_default_zone` | `drop` | Default zone: `drop` / `public` / `internal` |
| `linux_firewalld_allowed_services` | `[ssh]` | Services permanently allowed in the default zone |
| `linux_firewalld_allowed_ports` | `[]` | Additional ports to allow (e.g. `443/tcp`) |
| `linux_firewalld_ssh_sources` | `[]` | Restrict SSH to these source CIDRs: empty = allow from anywhere |
| `linux_firewalld_ssh_rate_limit` | `3/m` | SSH rate limit via firewalld rich rule |
| `linux_firewalld_log_denied` | `all` | Log dropped packets: `all` / `unicast` / `off` |
| `linux_firewalld_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_firewalld_default_zone: "drop"

# Restrict SSH to management VLAN only
linux_firewalld_ssh_sources:
  - "192.168.10.0/24"
  - "10.0.0.50"

# Allow HTTPS in addition to SSH
linux_firewalld_allowed_services:
  - "ssh"
  - "https"

# Also allow a custom application port
linux_firewalld_allowed_ports:
  - "8443/tcp"
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Role name | `linux_firewalld_rhel9` | `linux_firewall_ubuntu` |
| Firewall daemon | `firewalld` | `ufw` (Uncomplicated Firewall) |
| Ansible module | `ansible.posix.firewalld` | `community.general.ufw` |
| Zone concept | Yes (drop / public / internal) | Not applicable |
| Rich rules | Yes (source restriction, rate limiting) | `ufw` rules with `from` restriction |
| Log denied | `firewalld: log_denied` | `ufw logging on` |
| Variables | `linux_firewalld_*` | `linux_ufw_*` |

See [`role-linux_firewall_ubuntu.md`](role-linux_firewall_ubuntu.md) for the Ubuntu/Debian equivalent.
