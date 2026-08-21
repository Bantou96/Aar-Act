# Role: linux_kernel_hardening_ubuntu

## Purpose

Hardens the Linux kernel on Ubuntu/Debian systems via sysctl parameters and kernel module blacklisting:
- Enables ASLR, restricts ptrace, hides kernel pointers and dmesg output
- Mitigates network-level attacks: disables IP forwarding, source routing, ICMP redirects, enables SYN cookies
- Hardens IPv6 parameters (router advertisements, redirects)
- Restricts core dump exposure via sysctl
- Blacklists unused and risky kernel modules (cramfs, hfs, udf, USB storage, FireWire, etc.)

> **Container hosts.** This role also sets the IP forwarding sysctl. On a host
> running containers set `linux_kernel_disable_ip_forward: false`, otherwise it
> undoes the exception made in the dedicated role. See
> [Running on a Container Host](container-hosts.md).

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.1.1 Disable unused filesystem modules
- 1.5 Kernel parameters (ASLR, ptrace, dmesg_restrict, kptr_restrict)
- 3.1 IP forwarding and network parameters
- 3.2 Network parameters (host only)
- 3.3 Network parameters (host and router)

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_kernel_sysctl_file` | `/etc/sysctl.d/99-cis-kernel-hardening.conf` | Sysctl config file path |
| `linux_kernel_apply_aslr` | `true` | Enable ASLR (`kernel.randomize_va_space = 2`) |
| `linux_kernel_apply_ptrace` | `true` | Restrict ptrace scope (`kernel.yama.ptrace_scope = 1`) |
| `linux_kernel_apply_dmesg` | `true` | Restrict dmesg access (`kernel.dmesg_restrict = 1`) |
| `linux_kernel_apply_perf` | `true` | Restrict perf events (`kernel.perf_event_paranoid = 3`) |
| `linux_kernel_apply_network_ipv4` | `true` | Apply IPv4 hardening parameters |
| `linux_kernel_apply_network_ipv6` | `true` | Apply IPv6 hardening parameters |
| `linux_kernel_apply_coredump` | `true` | Restrict SUID core dumps via sysctl |
| `linux_kernel_disable_ip_forward` | `true` | Disable IP forwarding (set false on routers/VPN gateways) |
| `linux_kernel_blacklist_filesystems` | `true` | Blacklist cramfs, freevxfs, hfs, hfsplus, jffs2, squashfs, udf |
| `linux_kernel_blacklist_usb_storage` | `true` | Blacklist USB mass storage driver |
| `linux_kernel_blacklist_firewire` | `false` | Blacklist FireWire stack (enable if no FireWire hardware) |
| `linux_kernel_blacklist_thunderbolt` | `false` | Blacklist Thunderbolt (enable if not used) |
| `linux_kernel_blacklist_atm` | `false` | Blacklist ATM networking |
| `linux_kernel_modprobe_file` | `/etc/modprobe.d/99-cis-modprobe-blacklist.conf` | Modprobe blacklist file path |
| `linux_kernel_unload_blacklisted` | `false` | Attempt to unload modules after blacklisting (reboot still required) |
| `linux_kernel_hardening_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_kernel_blacklist_usb_storage: true
linux_kernel_blacklist_firewire: true
linux_kernel_apply_network_ipv6: true

# Disable for a specific host (e.g. a router that needs IP forwarding)
linux_kernel_hardening_disabled: true
```

## Differences from RHEL9 Counterpart

The Ubuntu and RHEL9 role share identical variables and behaviour. The only difference is the sysctl configuration is applied via `/etc/sysctl.d/` on both, but Ubuntu/Debian uses `sysctl --system` to reload, while RHEL9 may use `sysctl -p`. Both use `modprobe.d` for blacklisting.
