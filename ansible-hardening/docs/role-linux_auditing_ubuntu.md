# Role: linux_auditing_ubuntu

## Purpose

Deploys and hardens auditd on Ubuntu/Debian systems:
- Installs `auditd` and `audispd-plugins`
- Deploys a CIS-aligned `auditd.conf` (log size, rotation, space actions)
- Applies comprehensive CIS audit rules (identity files, privileged commands, mounts, AppArmor, kernel modules, etc.)
- Makes audit rules immutable (`-e 2`), requires reboot to change rules
- Optionally enables boot-time auditing (`audit=1` in GRUB cmdline)
- Optionally forwards audit events to rsyslog and a remote log server (TCP/TLS)

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 6.3.1 Ensure auditd is installed
- 6.3.2 Ensure auditd service is enabled and running
- 6.3.3 Configure auditd.conf (log size, action on space shortage)
- 6.3.4 Configure audit rules (identity, privileged execs, network, AppArmor events)

## Variables

### auditd.conf

| Variable | Default | Description |
|---|---|---|
| `linux_auditd_max_log_file` | `8` | Max log file size (MB) |
| `linux_auditd_max_log_file_action` | `keep_logs` | Action when max size reached |
| `linux_auditd_space_left_action` | `email` | Action when disk space is low |
| `linux_auditd_admin_space_left_action` | `single` | Action when critically low on space |
| `linux_auditd_disk_full_action` | `suspend` | Action when disk is full |
| `linux_auditd_flush` | `incremental_async` | Flush mode for audit records |
| `linux_auditd_conf_file` | `/etc/audit/auditd.conf` | auditd config file path |
| `linux_auditd_rules_file` | `/etc/audit/rules.d/99-cis-audit.rules` | Audit rules file path |

### GRUB boot auditing

| Variable | Default | Description |
|---|---|---|
| `linux_auditd_enable_boot_auditing` | `true` | Add `audit=1` to GRUB cmdline |

### Audit rule toggles

| Variable | Default | Description |
|---|---|---|
| `linux_audit_rules_identity` | `true` | Watch `/etc/passwd`, `/etc/shadow`, `/etc/group`, etc. |
| `linux_audit_rules_privileged` | `true` | Watch privileged commands (su, sudo, passwd, mount) |
| `linux_audit_rules_perm_mod` | `true` | Track `chmod`, `chown`, `setxattr` syscalls |
| `linux_audit_rules_mounts` | `true` | Track `mount` / `umount` syscalls |
| `linux_audit_rules_actions` | `true` | Track admin actions and sudoers changes |
| `linux_audit_rules_delete` | `false` | Track `unlink`, `rename` (can be noisy) |
| `linux_audit_rules_apparmor` | `true` | Track AppArmor policy changes |
| `linux_audit_rules_network` | `false` | Track network configuration changes |
| `linux_audit_rules_exec` | `false` | Track all `execve` calls (very noisy) |
| `linux_audit_rules_time` | `true` | Track system time changes |
| `linux_audit_rules_file_integrity_high` | `false` | High-verbosity file integrity (L2, very noisy) |
| `linux_audit_rules_kernel_modules` | `false` | Track `insmod`, `rmmod` (L2) |
| `linux_audit_rules_ptrace` | `false` | Track ptrace calls |

### rsyslog forwarding

| Variable | Default | Description |
|---|---|---|
| `linux_auditd_forward_to_syslog` | `true` | Activate the auditd syslog plugin |
| `linux_rsyslog_forward_enabled` | `true` | Enable remote rsyslog forwarding |
| `linux_rsyslog_remote_host` | `""` | Remote log server hostname or IP |
| `linux_rsyslog_remote_port` | `514` | Remote log server port |
| `linux_rsyslog_remote_protocol` | `tcp` | Transport protocol (`tcp` or `udp`) |
| `linux_rsyslog_remote_use_tls` | `true` | Enable TLS for rsyslog forwarding |
| `linux_rsyslog_queue_disk` | `true` | Use disk queue for rsyslog (survives restarts) |
| `linux_rsyslog_queue_file` | `/var/spool/rsyslog/queue` | Disk queue directory path |
| `linux_auditing_forwarding_disabled` | `false` | Disable all forwarding (syslog plugin + rsyslog) |
| `linux_auditing_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml

# Forward logs to your SIEM
linux_rsyslog_remote_host: "siem.corp.example.sn"
linux_rsyslog_remote_port: "6514"
linux_rsyslog_remote_use_tls: true

# Reduce noise on busy servers
linux_audit_rules_delete: false
linux_audit_rules_exec: false

# Enable L2 kernel module auditing on sensitive hosts
linux_audit_rules_kernel_modules: true
```

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| MAC audit rule | `linux_audit_rules_apparmor: true` | `linux_audit_rules_selinux: true` |
| GRUB update command | `update-grub` | `grub2-mkconfig` |
| Plugin path | `/etc/audit/plugins.d/syslog.conf` | `/etc/audisp/plugins.d/syslog.conf` |
| auditd service start | `service auditd start` fallback on Ubuntu | `systemctl start auditd` |
