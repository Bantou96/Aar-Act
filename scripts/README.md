# CyberAar Security Baseline Checker

**Script:** `scripts/cyberaar-baseline.sh`
**Version:** 4.2.0
**Checks:** 96 across 8 sections

## Overview

`cyberaar-baseline.sh` is a standalone bash script that performs a local security audit of a Linux server and produces:

- **Terminal output**: colour-coded PASS / WARN / FAIL results with a security score
- **HTML report**: self-contained file suitable for sharing with management or auditors
- **JSON report**: machine-readable output for SIEM integration or CI pipelines
- **Ansible remediation plan**: targeted `ansible-playbook` commands for every failing check

The script requires no external dependencies beyond standard Linux utilities (`bash`, `ss`, `sysctl`, `stat`, `find`, `awk`) and runs in a single pass in under two minutes on a typical server.

It covers the same control areas as the CyberAar Ansible hardening roles, so the remediation commands map directly to roles in this collection.

---

## Requirements

| Requirement | Notes |
|---|---|
| Bash 4.2+ | Available on all supported distros |
| Root / sudo | Required: reads `/etc/shadow`, runs `sysctl`, `auditctl`, etc. |
| Supported OS | RHEL 9 / AlmaLinux 9 / Rocky Linux 9: Ubuntu 20.04 / 22.04 / 24.04: Debian 11 / 12 |
| Optional tools | `mokutil` (Secure Boot check), `auditctl` (audit rules check), `ss` (port check) |

---

## Installation

### Run directly (no install)

```bash
sudo bash scripts/cyberaar-baseline.sh
```

### Install to PATH

```bash
sudo bash scripts/cyberaar-baseline.sh --install
# Installs to /usr/local/bin/cyberaar-baseline

sudo cyberaar-baseline --help
```

### Uninstall

```bash
sudo cyberaar-baseline --uninstall
```

---

## Usage

```
cyberaar-baseline [OPTIONS]

Output options:
  --html-out <file>      Write HTML report to <file>
  --json-out <file>      Write JSON report to <file>
  --output-dir <dir>     Auto-name and store HTML + JSON in <dir>

Remote / fleet options:
  --host <ip|host>       Run against a single remote host via SSH
  --host-file <file>     Run against multiple hosts (one per line)
  --inventory <file>     Parse an Ansible inventory file for hosts
  --user <user>          SSH user for remote scan (default: root)
  --ssh-key <keyfile>    SSH private key for remote scan
  --ansible-dir <dir>    Path to the Ansible repo (improves remediation output)

Install options:
  --install              Install to /usr/local/bin/cyberaar-baseline
  --uninstall            Remove from /usr/local/bin/cyberaar-baseline
  --version              Print version and exit
  --help, -h             Show help
```

### Common examples

```bash
# Local scan, terminal output only
sudo cyberaar-baseline

# Local scan with HTML report
sudo cyberaar-baseline --html-out /tmp/report.html

# Local scan with both HTML and JSON
sudo cyberaar-baseline --html-out /tmp/report.html --json-out /tmp/report.json

# Auto-named reports in a directory (timestamped)
sudo cyberaar-baseline --output-dir /var/log/cyberaar

# Remote single host
cyberaar-baseline --host 10.0.1.10 --user admin --ssh-key ~/.ssh/id_rsa \
  --html-out /tmp/report-10.0.1.10.html

# Fleet scan from a host file
cyberaar-baseline --host-file /etc/cyberaar/hosts.txt --user admin \
  --output-dir /var/log/cyberaar

# Fleet scan from Ansible inventory
cyberaar-baseline \
  --inventory ansible-hardening/inventory/hosts \
  --user admin \
  --output-dir /var/log/cyberaar

# With Ansible remediation suggestions pointing to the local repo
sudo cyberaar-baseline \
  --ansible-dir ~/cyberaar-toolkit/ansible-hardening \
  --html-out /tmp/report.html
```

---

## Output

### Terminal

Each check prints a single line with its status, check ID, name, and detail value.
For WARN / FAIL checks the remediation hint is shown on the next line.

```
━━━  1. SYSTEM & OS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅  [PASS  ] Supported OS detected                      AlmaLinux 9.3
  ⚠️  [WARN  ] Kernel version                             5.14.0-362.el9.x86_64
         ↳ Vérifiez les mises à jour noyau: 'dnf check-update kernel'
  ✅  [PASS  ] No pending security updates                0 packages
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CyberAar Security Score: 74%
  ✅ PASS: 52    ⚠️  WARN: 28    ❌ FAIL: 8     (Total: 88)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Score** = `PASS / TOTAL × 100`. Colour thresholds: ≥ 80% green, ≥ 60% yellow, < 60% red.

### Ansible remediation plan

After the score, the terminal prints a deduplicated list of `ansible-playbook` commands covering every FAIL and WARN check that has an Ansible mapping:

```
━━━  ANSIBLE REMEDIATION PLAN  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Platform: (RHEL9 / AlmaLinux / Rocky)
  Playbook: playbooks/2_configure_hardening.yml

  [01] Apply pending kernel updates          tags: updates,patching
       Role  : linux_dnf_automatic_rhel9
       ansible-playbook -i inventory/hosts playbooks/2_configure_hardening.yml --tags updates,patching

  [02] Account lockout (faillock)            tags: auth,pam
       Role  : linux_authselect_rhel9
       ansible-playbook -i inventory/hosts playbooks/2_configure_hardening.yml --tags auth,pam

  ── Fix everything in one command: ───────────────────────────
  ansible-playbook -i inventory/hosts playbooks/2_configure_hardening.yml \
    --tags updates,patching,auth,pam,ssh,...

  💡 Add --check --diff for a dry run before applying.
     Add -l <host_or_group> to target a specific server.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `--ansible-dir` is provided, the playbook path is resolved to that directory.

### HTML report

A self-contained single-file HTML report with:
- Summary banner (score, pass/warn/fail counts, hostname, timestamp)
- Filterable table (All / PASS / WARN / FAIL buttons)
- Per-row remediation hints for every non-passing check
- CyberAar branding; no external CSS or JS dependencies

### JSON report

```json
{
  "cyberaar_baseline": {
    "version": "4.2.0",
    "host": "server01.example.com",
    "os": "AlmaLinux Linux 9.3",
    "date": "2026-03-07 14:23:01",
    "score": 74,
    "summary": { "pass": 57, "warn": 31, "fail": 8, "total": 96 },
    "results": [
      {
        "id": "SYS-01",
        "category": "System",
        "status": "PASS",
        "check": "Supported OS detected",
        "detail": "AlmaLinux Linux 9.3",
        "remediation": ""
      },
      ...
    ],
    "ansible_remediation": {
      "fail_ids": ["AUTH-09", "NET-06", ...],
      "warn_ids": ["SYS-02", "AUTH-10", ...],
      "playbook": "playbooks/2_configure_hardening.yml",
      "inventory": "inventory/hosts.yml"
    }
  }
}
```

---

## Check Reference

Checks are grouped into 8 sections. Each check has a stable ID, severity level, and (where applicable) a mapping to an Ansible role and tags.

**Severity levels:**
- `FAIL`: non-compliant, direct security risk, must fix
- `WARN`: degraded posture or informational, should fix
- `PASS`: compliant

Checks marked **(manual review)** cannot be automatically remediated, the script detects a condition but human judgment is required to determine whether it is acceptable.

---

### Section 1: System & OS

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| SYS-01 | Supported OS (RHEL/Ubuntu/Debian) | WARN if unknown |: | Informational |
| SYS-02 | Kernel version | WARN | `updates,patching` | Always WARN: triggers version review |
| SYS-03 | Pending security updates | FAIL | `updates,patching` | `dnf check-update --security` or `apt-get -s upgrade` |
| SYS-04 | SELinux enforcing / AppArmor present | FAIL/WARN | `mac` | Permissive = WARN, Disabled = FAIL |
| SYS-05 | Core dumps restricted | WARN | `kernel,coredump` | Checks `limits.conf` and `fs.suid_dumpable` |
| SYS-06 | Time synchronization active | FAIL | `time,ntp` | Checks `chronyd`, `ntpd`, `systemd-timesyncd` |
| SYS-07 | GRUB config permissions | FAIL | `boot,grub` | `/boot/grub2/grub.cfg` or `/boot/grub/grub.cfg` must be 600/400 |
| SYS-08 | Secure Boot enabled | WARN | `secureboot` | Uses `mokutil --sb-state`; WARN only (firmware-level) |
| SYS-09 | `/dev/shm` mount options | WARN | `filesystem,mounts` | Requires `noexec,nosuid,nodev` |
| SYS-10 | Ctrl-Alt-Delete masked | FAIL | `system` | `ctrl-alt-del.target` must be masked |

---

### Section 2: Authentication & Access

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| AUTH-01 | Root account locked | WARN | `auth,users` | `passwd -S root` must show `L` |
| AUTH-02 | No empty password accounts | FAIL | `auth,users` | Checks `/etc/shadow` for `$2==""` |
| AUTH-03 | `PASS_MAX_DAYS` ≤ 90 | FAIL | `auth,users` | Set in `/etc/login.defs` |
| AUTH-04 | Password min length ≥ 12 | WARN | `auth,pam` | Checks `pwquality.conf` first, fallback to `login.defs` |
| AUTH-05 | No `NOPASSWD:ALL` in sudoers | FAIL | `auth,users` | Scans `/etc/sudoers` and `/etc/sudoers.d/` |
| AUTH-06 | No never-logged-in accounts | WARN | `auth,users` | System accounts excluded from check |
| AUTH-07 | `PASS_MIN_DAYS` ≥ 1 | WARN | `auth,users` | Prevents immediate password change after reset |
| AUTH-08 | `PASS_WARN_AGE` ≥ 7 | WARN | `auth,users` | Set in `/etc/login.defs` |
| AUTH-09 | Account lockout configured | FAIL | `auth,pam` | Checks `faillock.conf` (`deny ≤ 5`) or `pam_tally2` |
| AUTH-10 | Shell timeout `TMOUT` set | WARN | `auth,users` | Scans `/etc/profile`, `/etc/profile.d/`, `bashrc` |
| AUTH-11 | No extra UID 0 accounts | FAIL | `auth,users` | Only `root` should have UID 0 |
| AUTH-12 | `/etc/group` permissions 644 | FAIL | `filesystem,permissions` |: |
| AUTH-13 | `/etc/gshadow` permissions 640 or stricter | FAIL | `filesystem,permissions` |: |
| AUTH-14 | Password complexity configured | WARN | `auth,pam` | Checks `minlen ≥ 12` in `pwquality.conf` |
| AUTH-15 | sudo `use_pty` enforced | WARN | `sudo` | CIS 1.3.2: checks `Defaults use_pty` in sudoers |
| AUTH-16 | sudo logfile configured | WARN | `sudo` | CIS 1.3.3: checks `Defaults logfile=` in sudoers |

---

### Section 3: SSH Hardening

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| SSH-01 | `PermitRootLogin no` or `prohibit-password` | FAIL | `ssh` |: |
| SSH-02 | `PasswordAuthentication no` | WARN | `ssh` | Key-based auth recommended |
| SSH-03 | `MaxAuthTries` ≤ 4 | WARN | `ssh` | Default is 6 |
| SSH-04 | `AllowTcpForwarding no` | WARN | `ssh` | Disable if not required |
| SSH-05 | `X11Forwarding no` | WARN | `ssh` |: |
| SSH-06 | `LoginGraceTime` ≤ 60s | WARN | `ssh` | Default is 120s |
| SSH-07 | `PermitEmptyPasswords no` | FAIL | `ssh` | Off by default but explicitly verify |
| SSH-08 | `IgnoreRhosts yes` | FAIL | `ssh` | On by default; verify no override |
| SSH-09 | `HostbasedAuthentication no` | FAIL | `ssh` | Off by default; verify no override |
| SSH-10 | Legal banner configured | WARN | `ssh,banner` | Checks `Banner` directive and file content |
| SSH-11 | `ClientAliveInterval` ≤ 300s | WARN | `ssh` | Session idle timeout |
| SSH-12 | `UsePAM yes` | WARN | `ssh` | Required for faillock and password policy |
| SSH-13 | No weak ciphers | FAIL | `ssh,crypto` | Flags `arcfour`, `3des`, `des`, `blowfish`, `cast128` |
| SSH-14 | `sshd_config` permissions 600–644 | WARN | `ssh,filesystem` |: |
| SSH-15 | `MaxSessions` ≤ 4 | WARN | `ssh` | Default is 10 |

---

### Section 4: Filesystem & Permissions

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| FS-01 | `/etc/passwd` permissions 644 | FAIL | `filesystem,permissions` |: |
| FS-02 | `/etc/shadow` permissions 640 or stricter | FAIL | `filesystem,permissions` | 640/600/400/000 all accepted |
| FS-03 | `/etc/sudoers` permissions 440 or 400 | WARN | `filesystem,permissions` |: |
| FS-04 | No world-writable files in `/etc /usr /bin /sbin` | FAIL | `filesystem,permissions` |: |
| FS-05 | SUID binary count ≤ 20 | WARN | `filesystem,permissions` | **(manual review)** List with `find / -xdev -perm -4000 -ls` |
| FS-06 | `/tmp` mounted with `noexec` | WARN | `filesystem,mounts` |: |
| FS-07 | Sticky bit on all world-writable directories | FAIL | `filesystem,permissions` |: |
| FS-08 | `/etc/crontab` permissions 600 or 400 | WARN | `filesystem,permissions` |: |
| FS-09 | `/var/tmp` mounted with `noexec` | WARN | `filesystem,mounts` |: |
| FS-10 | No unowned files | WARN | `filesystem,permissions` | **(manual review)** Scans all filesystems with `-xdev` |
| FS-11 | `/var/log` not world-readable | WARN | `filesystem,permissions` | Last permission octet must be 0 or 1 |
| FS-12 | SSH host private keys at 600 | FAIL | `ssh` | All `/etc/ssh/ssh_host_*_key` files |

---

### Section 5: Network

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| NET-01 | Firewall active | FAIL | `firewall` | Detects `firewalld`, `ufw`, or `iptables` rules |
| NET-02 | `net.ipv4.ip_forward = 0` | WARN | `network,sysctl` |: |
| NET-03 | `net.ipv4.conf.all.accept_redirects = 0` | FAIL | `network,sysctl` |: |
| NET-04 | `net.ipv4.tcp_syncookies = 1` | FAIL | `network,sysctl` |: |
| NET-05 | No dangerous services active | FAIL | `services` | telnet, rsh, rlogin, ftp, tftp, nis, talk |
| NET-06 | `net.ipv4.conf.all.accept_source_route = 0` | FAIL | `network,sysctl` |: |
| NET-07 | `net.ipv4.conf.all.send_redirects = 0` | FAIL | `network,sysctl` |: |
| NET-08 | `net.ipv4.conf.all.log_martians = 1` | WARN | `network,sysctl` |: |
| NET-09 | `net.ipv4.conf.all.rp_filter = 1` or `2` | FAIL | `network,sysctl` |: |
| NET-10 | `net.ipv6.conf.all.accept_ra = 0` | WARN | `network,sysctl` | WARN only: may be needed in IPv6 networks |
| NET-11 | `net.ipv4.icmp_echo_ignore_broadcasts = 1` | WARN | `network,sysctl` |: |
| NET-12 | Wireless interfaces disabled | WARN | `wireless` | CIS 3.1.2: rfkill + nmcli + modprobe blacklist |
| NET-13 | IPv6 fully disabled | WARN | `network,ipv6` | CIS 3.3.1: checks `net.ipv6.conf.all.disable_ipv6=1` + `default` |

---

### Section 6: Logging & Audit

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| LOG-01 | `auditd` running | FAIL | `audit,logging` |: |
| LOG-02 | System logging active | FAIL | `audit,logging` | `rsyslog`, `syslog`, or `systemd-journald` |
| LOG-03 | `logrotate` configured | WARN |: | No Ansible role manages logrotate directly |
| LOG-04 | Audit rules present | WARN | `audit,logging` | Checks for `execve`, `chmod`, `chown`, `delete`, `login`, `sudo` rules |
| LOG-05 | `max_log_file ≥ 8` MB in `auditd.conf` | WARN | `audit,logging` |: |
| LOG-06 | `audit=1` in kernel cmdline | WARN | `audit,logging` | Checks `/proc/cmdline` |
| LOG-07 | journald persistent storage | WARN | `audit,logging,journald` | Checks for `/var/log/journal` directory |
| LOG-08 | Remote syslog configured | WARN |: | **(manual review)** Checks rsyslog for `@@` forwarding: no Ansible role covers remote syslog |
| LOG-09 | journald Storage=persistent configured | WARN | `audit,logging,journald` | CIS 4.2.1.1: checks drop-in config in `/etc/systemd/journald.conf.d/` |
| LOG-10 | journald rate limiting configured | WARN | `audit,logging,journald` | CIS 4.2.1.3: checks `RateLimitBurst` in journald config |

---

### Section 7: Integrity & Malware

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| INT-01 | AIDE installed | WARN | `integrity,aide` |: |
| INT-02 | Rootkit scanner present | WARN |: | **(manual review)** `rkhunter`/`chkrootkit` not installed by any role: run manually |
| INT-03 | No suspicious cron entries | FAIL |: | **(manual review)** Pattern: `wget`/`curl`/`bash`/`nc` → `http` or `/tmp` |
| INT-04 | Open listening ports | WARN |: | **(manual review)** Always WARN: operator must verify each port |
| INT-05 | Package GPG check enabled | FAIL | `updates,patching` | `gpgcheck=0` in any `.repo` file or `AllowUnauthenticated` in apt |
| INT-06 | fail2ban running | WARN | `fail2ban` |: |
| INT-07 | AIDE database initialized | FAIL/WARN | `integrity,aide` | FAIL if AIDE installed but no `aide.db.gz`; WARN if AIDE not installed |
| INT-08 | Cron directories not world-writable | FAIL | `filesystem,permissions` | Checks `/etc/cron.d`, `cron.daily`, `cron.weekly`, `cron.monthly`, `cron.hourly` |

---

### Section 8: Compliance & Policy

| ID | Check | Severity | Ansible Tag | Notes |
|---|---|---|---|---|
| COMP-01 | Legal banner in `/etc/issue.net` | WARN | `banner` | Must be ≥ 2 lines |
| COMP-02 | `/tmp` on dedicated partition or tmpfs | WARN | `filesystem,mounts` | Checks `/etc/fstab` and `/proc/mounts` |
| COMP-03 | `/home` on separate partition | WARN |: | **(manual review)** Cannot be changed post-install via Ansible |
| COMP-04 | `/var` on separate partition | WARN |: | **(manual review)** Cannot be changed post-install via Ansible |
| COMP-05 | Default umask 027 or stricter | WARN | `auth,users` | Scans `/etc/profile`, `/etc/profile.d/`, `login.defs` |
| COMP-06 | `kernel.randomize_va_space = 2` (ASLR) | FAIL/WARN | `kernel,sysctl` | Level 1 = WARN, disabled = FAIL |
| COMP-07 | `kernel.kptr_restrict = 2` | FAIL/WARN | `kernel,sysctl` | Level 1 = WARN, 0 = FAIL |
| COMP-08 | `kernel.dmesg_restrict = 1` | WARN | `kernel,sysctl` |: |
| COMP-09 | `kernel.yama.ptrace_scope ≥ 1` | WARN | `kernel,sysctl` |: |
| COMP-10 | USB storage module blacklisted | WARN | `kernel,sysctl` | Checks `/etc/modprobe.d/` for `blacklist usb-storage` |
| COMP-11 | cron service enabled and running | WARN | `cron` | CIS 5.1.1 |
| COMP-12 | `cron.allow` and `at.allow` allow-list enforced | WARN | `cron` | CIS 5.1.8–5.1.9: both files must exist and be non-empty |

---

## Integration with the Ansible Hardening Pipeline

The baseline script is used at steps 1 and 3 of the three-step pipeline:

```
playbooks/0_execute_full_pipeline.yml
  ├── 1_execute_baseline_before.yml  ← runs cyberaar-baseline, saves "before" report
  ├── 2_configure_hardening.yml      ← applies CyberAar hardening roles
  └── 3_execute_baseline_after.yml   ← re-runs cyberaar-baseline, saves "after" report
```

To run the full pipeline (baseline → harden → baseline) against a single host:

```bash
bash scripts/run-hardening.sh -u admin -t myserver -s all -c   # dry-run
bash scripts/run-hardening.sh -u admin -t myserver -s all       # apply
```

Reports are saved under `ansible-hardening/reports/before/<hostname>/` and `reports/after/<hostname>/`.

To use the script standalone against a host already in the Ansible inventory and get remediation commands pointing at the local repo:

```bash
cyberaar-baseline \
  --host 10.0.1.10 \
  --user admin \
  --inventory ansible-hardening/inventory/hosts \
  --ansible-dir ansible-hardening \
  --output-dir /var/log/cyberaar
```

---

## Fleet Scan

The script can scan multiple hosts in sequence over SSH. The script is copied to each remote host, executed as root, the reports are retrieved, and the remote copy is deleted.

```bash
# From a file (one host/IP per line, # comments supported)
cyberaar-baseline \
  --host-file /etc/cyberaar/hosts.txt \
  --user admin \
  --ssh-key ~/.ssh/cyberaar.key \
  --output-dir /var/log/cyberaar

# From an Ansible INI inventory
cyberaar-baseline \
  --inventory ansible-hardening/inventory/hosts \
  --user admin \
  --output-dir /var/log/cyberaar
```

Reports are named `cyberaar-<hostname>-<timestamp>.html/.json` automatically when `--output-dir` is used.

SSH options used: `StrictHostKeyChecking=accept-new`, `ConnectTimeout=10`, `BatchMode=yes`. The remote user needs passwordless sudo if not root.

---

## Checks That Require Manual Review

Some checks detect a condition that automated tooling cannot resolve, the operator must inspect the output and decide. These are clearly marked `(manual review required)` in the detail field:

| ID | What to do |
|---|---|
| FS-05 | Review SUID binaries: `find / -xdev -perm -4000 -ls`: remove the SUID bit on anything not required |
| FS-10 | Review unowned files: `find / -xdev \( -nouser -o -nogroup \) -type f -ls`: assign ownership or delete |
| INT-02 | Run `rkhunter --check` or `chkrootkit` manually and review the output |
| INT-03 | Inspect the cron entries flagged and confirm they are legitimate |
| INT-04 | Review `ss -tlnp` output: close or firewall any port that is not justified |
| LOG-08 | Decide on a remote syslog server and configure rsyslog forwarding manually |
| COMP-03 | `/home` partition layout: plan for next OS reinstall |
| COMP-04 | `/var` partition layout: plan for next OS reinstall |

---

## Remediation Reference

The table below maps every check ID to its Ansible role and tag for quick remediation.
Checks without a mapping have no automated fix in this collection.

| Check IDs | Ansible Tags | RHEL9 Role | Ubuntu Role |
|---|---|---|---|
| SYS-02, SYS-03 | `updates,patching` | `linux_dnf_automatic_rhel9` | `linux_unattended_upgrades_ubuntu` |
| SYS-04 | `mac` | `linux_selinux_rhel9` | `linux_apparmor_ubuntu` |
| SYS-05 | `kernel,coredump` | `linux_core_dumps_rhel9` | `linux_core_dumps_ubuntu` |
| SYS-06 | `time,ntp` | `linux_chrony_rhel9` | `linux_chrony_ubuntu` |
| SYS-07 | `boot,grub` | `linux_bootloader_password_rhel9` | `linux_bootloader_password_ubuntu` |
| SYS-08 | `secureboot` | `linux_secure_boot_rhel9` | `linux_secure_boot_ubuntu` |
| SYS-09, FS-06, FS-09, COMP-02 | `filesystem,mounts` | `linux_tmp_mounts_rhel9` | `linux_tmp_mounts_ubuntu` |
| SYS-10 | `system` | `linux_ctrl_alt_del_rhel9` | `linux_ctrl_alt_del_ubuntu` |
| AUTH-01, AUTH-02, AUTH-03, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-10, AUTH-11, COMP-05 | `auth,users` | `linux_user_management_rhel9` | `linux_user_management_ubuntu` |
| AUTH-04, AUTH-09, AUTH-14 | `auth,pam` | `linux_authselect_rhel9` | `linux_authselect_ubuntu` |
| AUTH-12, AUTH-13, FS-01–FS-05, FS-07, FS-08, FS-10, FS-11, INT-08 | `filesystem,permissions` | `linux_file_permissions_rhel9` | `linux_file_permissions_ubuntu` |
| SSH-01–SSH-15, FS-12 | `ssh` | `linux_ssh_hardening_rhel9` | `linux_ssh_hardening_ubuntu` |
| NET-01 | `firewall` | `linux_firewalld_rhel9` | `linux_firewall_ubuntu` |
| NET-02, NET-03 | `network,sysctl` | `linux_ip_forwarding_rhel9` | `linux_ip_forwarding_ubuntu` |
| NET-04, NET-06–NET-11, COMP-06–COMP-10 | `kernel,sysctl` | `linux_kernel_hardening_rhel9` | `linux_kernel_hardening_ubuntu` |
| NET-05 | `services` | `linux_disable_unnecessary_services_rhel9` | `linux_disable_unnecessary_services_ubuntu` |
| LOG-01, LOG-02, LOG-04–LOG-06 | `audit,logging` | `linux_auditing_rhel9` | `linux_auditing_ubuntu` |
| LOG-07, LOG-09, LOG-10 | `audit,logging,journald` | `linux_journald_rhel9` | `linux_journald_ubuntu` |
| INT-01, INT-07 | `integrity,aide` | `linux_aide_rhel9` | `linux_aide_ubuntu` |
| INT-05 | `updates,patching` | `linux_dnf_automatic_rhel9` | `linux_unattended_upgrades_ubuntu` |
| INT-06 | `fail2ban` | `linux_fail2ban_rhel9` | `linux_fail2ban_ubuntu` |
| AUTH-15, AUTH-16 | `sudo` | `linux_sudo_hardening_rhel9` | `linux_sudo_hardening_ubuntu` |
| NET-12 | `wireless` | `linux_wireless_rhel9` | `linux_wireless_ubuntu` |
| NET-13 | `network,ipv6` | `linux_ipv6_rhel9` | `linux_ipv6_ubuntu` |
| COMP-01 | `banner` | `linux_login_banner_rhel9` | `linux_login_banner_ubuntu` |
| COMP-11, COMP-12 | `cron` | `linux_cron_hardening_rhel9` | `linux_cron_hardening_ubuntu` |

---

## Contributing to the Script

`cyberaar-baseline.sh` is a **generated bundle**: do not edit it directly. The source lives in `src/` and is assembled by `build.sh`.

### Source layout

```
scripts/
├── cyberaar-baseline.sh        ← generated bundle (deploy/install this)
├── build.sh                    ← assembles src/ in order, runs bash -n
└── src/
    ├── main.sh                 ← shebang, _show_help, CLI args, install/uninstall
    ├── run.sh                  ← root check, check calls, score, renderer dispatch
    ├── lib/
    │   ├── core.sh             ← colors, parallel result arrays, add_result(), helpers
    │   ├── ansible_map.sh      ← declare -A ANSIBLE_MAP=()
    │   └── remote.sh           ← _remote_scan, fleet dispatcher
    ├── checks/
    │   ├── sys.sh              ← _checks_system()     SYS-01..10
    │   ├── auth.sh             ← _checks_auth()       AUTH-01..14
    │   ├── ssh.sh              ← _checks_ssh()        SSH-01..15
    │   ├── fs.sh               ← _checks_filesystem() FS-01..12
    │   ├── net.sh              ← _checks_network()    NET-01..11
    │   ├── log.sh              ← _checks_logging()    LOG-01..08
    │   ├── integrity.sh        ← _checks_integrity()  INT-01..08
    │   └── compliance.sh       ← _checks_compliance() COMP-01..10
    └── renderers/
        ├── terminal.sh         ← _render_summary(), _ansible_terminal_plan()
        ├── json.sh             ← _render_json(), iterates RESULT_*[] arrays
        └── html.sh             ← _render_html(), builds HTML_ROWS from RESULT_*[]
```

### How add_result() works

`add_result()` (in `src/lib/core.sh`) does two things:
1. **Prints live to terminal**: check result streams as checks run
2. **Appends to parallel arrays**: `RESULT_CATEGORY[]`, `RESULT_STATUS[]`, `RESULT_ID[]`, `RESULT_NAME_EN[]`, `RESULT_NAME_FR[]`, `RESULT_DETAIL[]`, `RESULT_REMEDIATION[]`

The renderers (`_render_json`, `_render_html`) iterate those arrays at the end of the run. To change JSON or HTML output, edit only the relevant renderer, no need to touch `add_result()`.

### Edit → rebuild workflow

```bash
# 1. Edit a source file
vim scripts/src/checks/ssh.sh

# 2. Rebuild the bundle
bash scripts/build.sh

# 3. Test locally
sudo bash scripts/cyberaar-baseline.sh \
  --html-out /tmp/test.html \
  --json-out /tmp/test.json

# 4. Verify output counts
grep -c "<tr>" /tmp/test.html        # should match total check count
python3 -c "import json; d=json.load(open('/tmp/test.json')); print(len(d['cyberaar_baseline']['results']), 'checks')"
```

Commit both the edited `src/` file(s) **and** the regenerated `cyberaar-baseline.sh`.

---

## Frequently Asked Questions

**The script takes several minutes. Why?**

The SUID count (`find / -xdev -perm -4000`) and unowned files scan (`find / -xdev -nouser -o -nogroup`) traverse the entire root filesystem. On large storage this can take 1–3 minutes. Both checks use `-xdev` to avoid crossing filesystem boundaries (NFS mounts, etc.).

**Can I run this without root?**

No. Several checks require root: reading `/etc/shadow`, running `auditctl -l`, calling `mokutil`, and reading `/proc/mounts` fully. Without root, the script exits immediately.

**SYS-02 (kernel version) is always WARN. Is that a bug?**

No, it is intentional. The check cannot know whether the running kernel is the latest available without performing a package query (which is slow and OS-specific). The WARN is a prompt to check manually. SYS-03 covers actual pending updates.

**My `/home` and `/var` are on the root partition. COMP-03 and COMP-04 are always WARN.**

Correct. Separate partitions cannot be created on a running system by Ansible. These checks are informational, note them for the next build / reinstall cycle and use an OS kickstart or preseed that includes a proper partition scheme.

**LOG-08 (remote syslog) is always WARN. Why is there no Ansible remediation?**

Remote syslog forwarding requires knowing the address and protocol of your SIEM or syslog server, a site-specific configuration that is not part of the generic hardening collection. You can configure rsyslog forwarding manually or by adding a custom role.

**How do I suppress a check I know is a false positive?**

The script does not currently support a suppression list. For site-specific exceptions, filter the JSON output by check ID in your pipeline. If a check is consistently incorrect for your environment, open a GitHub issue.
