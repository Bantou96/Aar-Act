# Role: linux_ip_forwarding_rhel9

## Purpose

Disables IP forwarding and ICMP redirect acceptance on RHEL 9 family systems to prevent the server from acting as a router or accepting spoofed routing information:
- Sets `net.ipv4.ip_forward = 0`
- Sets `net.ipv6.conf.all.forwarding = 0`
- Sets `net.ipv4.conf.all.accept_redirects = 0` and `net.ipv4.conf.default.accept_redirects = 0`
- Sets `net.ipv6.conf.all.accept_redirects = 0` and `net.ipv6.conf.default.accept_redirects = 0`
- Verifies the settings are applied immediately via `sysctl`

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 3.3.1 Ensure IP forwarding is disabled
- 3.3.2 Ensure packet redirect sending is disabled
- 3.3.3 Ensure bogus ICMP responses are ignored
- 3.3.4 Ensure broadcast ICMP requests are ignored
- 3.3.5 Ensure ICMP redirects are not accepted

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_ip_forwarding_enabled` | `true` | Apply the sysctl hardening |
| `linux_ip_forwarding` | `0` | `net.ipv4.ip_forward` value (`0` = disabled) |
| `linux_ipv6_forwarding` | `0` | `net.ipv6.conf.all.forwarding` value (`0` = disabled) |
| `linux_accept_redirects` | `0` | `net.*.conf.*.accept_redirects` value (`0` = disabled) |
| `linux_ip_forwarding_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Defaults are CIS-compliant: no changes needed on non-router servers
linux_ip_forwarding: "0"
linux_ipv6_forwarding: "0"
linux_accept_redirects: "0"

# Enable forwarding on a bastion/jump host that routes between VLANs
linux_ip_forwarding: "1"
linux_ip_forwarding_disabled: false  # still apply other sysctl settings
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Sysctl file | `/etc/sysctl.d/99-cis-ip-forwarding.conf` | `/etc/sysctl.d/99-cis-ip-forwarding.conf` |
| Module | `ansible.posix.sysctl` | `ansible.posix.sysctl` |
| Variables | Identical | Identical |

The role implementation is identical on both platforms.
