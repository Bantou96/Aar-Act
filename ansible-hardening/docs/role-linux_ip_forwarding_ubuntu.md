# Role: linux_ip_forwarding_ubuntu

## Purpose

Ensures IP forwarding is disabled on Ubuntu/Debian servers that are not routers or VPN gateways:
- Sets `net.ipv4.ip_forward = 0` and `net.ipv6.conf.all.forwarding = 0` via sysctl
- Applies configuration persistently via `/etc/sysctl.d/`
- Complements the kernel hardening role which also controls some network sysctl parameters

> **Container hosts.** Docker's bridge networking requires IP forwarding. Applying
> this control on a container host breaks container networking, and the failure is
> deferred to the next reboot. See [Running on a Container Host](container-hosts.md).

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 3.1.1 Ensure IP forwarding is disabled (IPv4)
- 3.1.2 Ensure IP forwarding is disabled (IPv6)

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_ip_forwarding_sysctl_file` | `/etc/sysctl.d/99-cis-ip-forwarding.conf` | Sysctl config file path |
| `linux_ip_forwarding_enable_ipv4` | `false` | Set `true` only on routers or VPN gateways (IPv4) |
| `linux_ip_forwarding_enable_ipv6` | `false` | Set `true` only on routers or VPN gateways (IPv6) |
| `linux_ip_forwarding_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# Standard server (not a router): defaults are sufficient
linux_ip_forwarding_enable_ipv4: false
linux_ip_forwarding_enable_ipv6: false

# VPN gateway or router: enable forwarding
linux_ip_forwarding_enable_ipv4: true

# Skip the role entirely on a known router
linux_ip_forwarding_disabled: true
```

## Differences from RHEL9 Counterpart

The variables and behaviour are identical between the Ubuntu and RHEL9 IP forwarding roles. Only the sysctl reload mechanism differs internally (both use the `ansible.posix.sysctl` module).
