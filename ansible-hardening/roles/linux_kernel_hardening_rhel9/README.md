# linux_kernel_hardening_rhel9

## Purpose
Applies kernel sysctl parameters to harden against common exploits:  
- Enable ASLR, restrict ptrace, hide kernel pointers  
- Mitigate network spoofing/redirect attacks, SYN floods  
- Disable core dumps for suid, restrict dmesg/perf

## Targeted OS
Red Hat Enterprise Linux 9, AlmaLinux 9, Rocky Linux 9

## CIS References (v2.0.0, 2024/2025 updates)
- 1.5.1 Ensure address space layout randomization is enabled (L1)
- 1.5.2 Ensure ptrace_scope is restricted (L1)
- 1.5.3 Ensure kernel.dmesg_restrict is enabled (L1)
- 3.3.x Network parameters (multiple L1/L2: accept_redirects=0, rp_filter=1, tcp_syncookies=1, etc.)

## CVEs / Risks Mitigated
- Buffer overflows / ROP → ASLR + ptrace restrict
- SYN flood → tcp_syncookies
- IP spoofing / redirects → rp_filter, no redirects
- Kernel info leak → kptr_restrict=2, dmesg_restrict=1

## Idempotence
- `ansible.posix.sysctl` checks current value → applies only if different
- `--system` reload only on change via handler
- File-based persistence in /etc/sysctl.d/

## Module Blacklisting (CIS 1.1.1.1–1.1.1.8)
- Disables rare/unused filesystem modules + usb-storage (prevents rogue USB exploits)
- Uses `install <module> /bin/false` (CIS preferred) + `blacklist` for extra safety
- Template-based → readable comments, easy to extend
- Changes require **reboot** for full enforcement (or manual `modprobe -r`)

## Variables to control scope
linux_kernel_apply_aslr: true
linux_kernel_apply_network_ipv4: true
# ... etc.

## Variables
- Override individual settings via `linux_kernel_sysctl_settings` dict
- `linux_kernel_hardening_disabled: false`
- `linux_kernel_blacklist_filesystems: true` (core CIS filesystems)
- `linux_kernel_blacklist_usb_storage: true` (critical for servers)
- `linux_kernel_blacklist_firewire: false` (enable if paranoid about legacy ports)
- `linux_kernel_unload_blacklisted: false` (attempt unload if changed, may fail if in use)

## Notes/Warnings
- Do NOT blacklist modules your hardware needs (e.g. storage controllers!)
- usb-storage blacklist → no USB drives on servers (common hardening choice)
- Test on non-prod: after apply, check `lsmod | grep <module>` and reboot
- Some Level 2 params (e.g. perf_event_paranoid=3) may impact monitoring tools
- Test in non-prod first (e.g. disable tcp_syncookies if high-traffic edge)
