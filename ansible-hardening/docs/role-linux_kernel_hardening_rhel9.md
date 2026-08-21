# Role: linux_kernel_hardening_rhel9

## Purpose

Hardens the Linux kernel via sysctl parameters and kernel module blacklisting on RHEL 9 family systems:
- Deploys a CIS-aligned sysctl configuration file to `/etc/sysctl.d/`
- Enables ASLR (`kernel.randomize_va_space = 2`)
- Restricts `ptrace` scope (`kernel.yama.ptrace_scope = 1`)
- Hides kernel pointers (`kernel.kptr_restrict = 2`) and dmesg (`kernel.dmesg_restrict = 1`)
- Hardens IPv4/IPv6 network stack (rp_filter, SYN cookies, redirect rejection)
- Blacklists unused/risky kernel modules (`cramfs`, `hfs`, `squashfs`, `udf`, `usb-storage`, etc.)
- Optionally unloads already-loaded blacklisted modules (requires reboot for full effect)

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.1.1.1–1.1.1.7 Ensure mounting of unused filesystems is disabled
- 1.3.1 Ensure ASLR is enabled
- 1.3.2 Ensure ptrace scope is restricted
- 3.2.1 Ensure IP forwarding is disabled
- 3.2.2 Ensure packet redirect sending is disabled
- 3.3.1 Ensure source routed packets are not accepted
- 3.3.2 Ensure ICMP redirects are not accepted
- 3.3.4 Ensure suspicious packets are logged
- 3.3.5 Ensure broadcast ICMP requests are ignored
- 3.3.6 Ensure bogus ICMP responses are ignored
- 3.3.7 Ensure Reverse Path Filtering is enabled
- 3.3.8 Ensure TCP SYN Cookies is enabled

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_kernel_sysctl_file` | `/etc/sysctl.d/99-cis-kernel-hardening.conf` | Path to the sysctl configuration file |
| `linux_kernel_sysctl_reload` | `true` | Run `sysctl --system` to apply immediately |
| `linux_kernel_apply_aslr` | `true` | Set `kernel.randomize_va_space = 2` |
| `linux_kernel_apply_ptrace` | `true` | Set `kernel.yama.ptrace_scope = 1` |
| `linux_kernel_apply_dmesg` | `true` | Set `kernel.dmesg_restrict = 1` |
| `linux_kernel_apply_perf` | `true` | Restrict perf events (`kernel.perf_event_paranoid = 2`) |
| `linux_kernel_apply_network_ipv4` | `true` | Apply IPv4 network hardening sysctl settings |
| `linux_kernel_apply_network_ipv6` | `true` | Apply IPv6 network hardening sysctl settings |
| `linux_kernel_apply_coredump` | `true` | Set `fs.suid_dumpable = 0` via sysctl |
| `linux_kernel_blacklist_filesystems` | `true` | Blacklist unused filesystems (cramfs, hfs, squashfs, udf, vfat on servers) |
| `linux_kernel_blacklist_usb_storage` | `true` | Blacklist `usb-storage` module to prevent rogue USB devices |
| `linux_kernel_blacklist_firewire` | `false` | Blacklist FireWire modules (opt-in: rare on servers) |
| `linux_kernel_blacklist_thunderbolt` | `false` | Blacklist Thunderbolt modules (opt-in) |
| `linux_kernel_blacklist_atm` | `false` | Blacklist ATM modules (opt-in: very rare) |
| `linux_kernel_modprobe_file` | `/etc/modprobe.d/99-cis-modprobe-blacklist.conf` | Path to modprobe blacklist file |
| `linux_kernel_unload_blacklisted` | `false` | Attempt to `rmmod` already-loaded blacklisted modules |
| `linux_kernel_hardening_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# On servers with no USB devices attached
linux_kernel_blacklist_usb_storage: true

# On high-security bare-metal servers with Thunderbolt ports
linux_kernel_blacklist_thunderbolt: true
linux_kernel_blacklist_firewire: true

# Skip IPv6 hardening on IPv4-only environments
linux_kernel_apply_network_ipv6: false
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| sysctl file | `/etc/sysctl.d/99-cis-kernel-hardening.conf` | `/etc/sysctl.d/99-cis-kernel-hardening.conf` |
| modprobe file | `/etc/modprobe.d/99-cis-modprobe-blacklist.conf` | `/etc/modprobe.d/99-cis-modprobe-blacklist.conf` |
| SELinux sysctl | Included in RHEL9 template | Not applicable |
| Variables | Identical structure | Identical structure |

The role implementation is identical across platforms.
