# Role: linux_auditing_rhel9

## Purpose

Deploys and hardens `auditd` for comprehensive system event logging on RHEL 9 family systems:
- Installs `audit` and `audit-libs` packages
- Deploys a CIS-aligned `auditd.conf` (log rotation, space management actions)
- Deploys a 14-category audit rules file covering identity, privileges, mounts, SELinux, kernel modules, and more
- Enables and starts `auditd` and `rsyslog`
- Optionally enables boot-time auditing via GRUB cmdline (`audit=1`)
- Optionally forwards audit events to a remote syslog server (TCP/TLS/RELP)

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 6.2.1 Ensure audit log storage size is configured
- 6.2.2 Ensure audit logs are not automatically deleted
- 6.2.3 Ensure system is disabled when audit logs are full
- 6.3.1 Ensure auditd is installed and enabled
- 6.3.2 Ensure auditd service is enabled and active
- 6.3.3.1 Ensure changes to system administration scope (sudoers) are collected
- 6.3.3.2 Ensure actions as another user are always logged
- 6.3.3.3 Ensure events that modify the sudo log file are collected
- 6.3.3.4 Ensure events that modify date and time information are collected
- 6.3.3.5 Ensure events that modify the system's network environment are collected
- 6.3.3.6 Ensure use of privileged commands are collected
- 6.3.3.7 Ensure unsuccessful file access attempts are collected
- 6.3.3.8 Ensure file deletion events by users are collected
- 6.3.3.9 Ensure kernel module loading and unloading is collected
- 6.3.4.1 Ensure audit log files are mode 0640 or less permissive

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_auditd_max_log_file` | `8` | Log file size in MB before rotation |
| `linux_auditd_max_log_file_action` | `keep_logs` | Action when log size exceeded (`keep_logs` / `rotate` / `ROTATE_IMMEDIATE`) |
| `linux_auditd_space_left_action` | `email` | Action when disk space is low (`email` / `syslog` / `halt`) |
| `linux_auditd_admin_space_left_action` | `single` | Action when critically low (`single` = drop to single-user mode) |
| `linux_auditd_disk_full_action` | `suspend` | Action when disk is full (`suspend` / `halt`) |
| `linux_auditd_flush` | `incremental_async` | Audit event flush mode |
| `linux_auditd_enable_boot_auditing` | `true` | Add `audit=1` to GRUB cmdline for pre-boot coverage |
| `linux_auditd_conf_file` | `/etc/audit/auditd.conf` | Path to main auditd configuration file |
| `linux_auditd_rules_file` | `/etc/audit/rules.d/99-cis-audit.rules` | Path to CIS audit rules file |
| `linux_audit_rules_identity` | `true` | Watch `/etc/passwd`, `/etc/shadow`, `/etc/group`, etc. |
| `linux_audit_rules_privileged` | `true` | Watch `su`, `sudo`, `mount`, `passwd`, etc. |
| `linux_audit_rules_perm_mod` | `true` | Watch `chmod`, `chown`, `fchmod*`, `fchown*`, etc. |
| `linux_audit_rules_mounts` | `true` | Watch `mount`, `umount2` syscalls |
| `linux_audit_rules_actions` | `true` | Watch sudoers, cron, at, systemd timers |
| `linux_audit_rules_delete` | `false` | Watch `unlink`, `rename`, `rmdir` (high volume: opt-in) |
| `linux_audit_rules_selinux` | `true` | Watch `chcon`, `setenforce`, `semanage`, `restorecon` |
| `linux_audit_rules_network` | `false` | Watch socket calls, bind, connect (very noisy: opt-in) |
| `linux_audit_rules_exec` | `false` | Watch all `execve` calls (broad: opt-in) |
| `linux_audit_rules_time` | `true` | Watch `adjtimex`, `settimeofday`, `clock_settime` |
| `linux_audit_rules_file_integrity_high` | `false` | Watch `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` (many events: opt-in) |
| `linux_audit_rules_kernel_modules` | `false` | Watch `init_module`, `finit_module`, `delete_module` (opt-in) |
| `linux_audit_rules_ptrace` | `false` | Watch `ptrace` syscalls (opt-in) |
| `linux_auditd_forward_to_syslog` | `true` | Enable auditd → rsyslog plugin |
| `linux_rsyslog_forward_enabled` | `true` | Forward rsyslog events to a remote server |
| `linux_rsyslog_remote_host` | `""` | Remote syslog server IP or hostname (empty = disabled) |
| `linux_rsyslog_remote_port` | `514` | Remote syslog server port |
| `linux_rsyslog_remote_protocol` | `tcp` | Transport protocol (`tcp` / `udp` / `relp`) |
| `linux_rsyslog_remote_use_tls` | `true` | Encrypt forwarding with TLS |
| `linux_auditing_forwarding_disabled` | `false` | Skip the entire forwarding section |
| `linux_auditing_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Forward to central syslog server
linux_rsyslog_remote_host: "192.168.10.50"
linux_rsyslog_remote_protocol: "tcp"
linux_rsyslog_remote_use_tls: true

# Reduce noise on busy application servers
linux_audit_rules_delete: false
linux_audit_rules_network: false
linux_audit_rules_exec: false

# Enable kernel module auditing on high-security systems
linux_audit_rules_kernel_modules: true
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Packages | `audit`, `audit-libs` | `auditd`, `audispd-plugins` |
| Syslog plugin path | `/etc/audit/plugins.d/syslog.conf` | `/etc/audit/plugins.d/syslog.conf` |
| GRUB rebuild | `grub2-mkconfig -o /boot/grub2/grub.cfg` | `update-grub` |
| SELinux audit rules | Included (`linux_audit_rules_selinux`) | Not applicable |
| Variables | Identical structure | Identical structure |
