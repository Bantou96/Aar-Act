# cyberaar-baseline.sh

The standalone audit script. One file, no dependencies beyond bash and the
coreutils already on the machine, which is what lets you `curl` it onto an
air-gapped box and run it there.

[`aartool inspect`](AARTOOL.md) wraps this and is the easier front door: it
adds a sane default output directory, `--jump` for bastions, and hands the
reports back to the user who invoked `sudo`. The script itself is unchanged and
stays independently usable.

---

## Baseline Audit Script (`cyberaar-baseline.sh`)

The standalone audit script runs **109 security checks** across 9 sections and produces:

- **Terminal output**: colour-coded PASS / WARN / FAIL with a security score
- **HTML report**: self-contained file for sharing with management or auditors
- **JSON report**: machine-readable, suitable for SIEM or CI pipeline ingestion
- **Ansible remediation plan**: targeted `ansible-playbook` commands for every failing check, mapped to the correct role and tag

No Ansible required, pure bash, no dependencies beyond standard Linux tools.

### Install to PATH (optional)

```bash
sudo bash scripts/cyberaar-baseline.sh --install
# Installs to /usr/local/bin/cyberaar-baseline
```

### Run a local audit

```bash
# Without installing
sudo bash scripts/cyberaar-baseline.sh \
  --html-out /tmp/report.html \
  --json-out /tmp/report.json

# After installing to PATH
sudo cyberaar-baseline --output-dir /var/log/cyberaar

# Remote single host
cyberaar-baseline --host 10.0.1.10 --user admin --output-dir /var/log/cyberaar

# Fleet scan from Ansible inventory
cyberaar-baseline --inventory ansible-hardening/inventory/hosts \
  --user admin --output-dir /var/log/cyberaar
```

### What it checks

109 checks across 9 sections, each mapped to a CIS benchmark control:

| Section | Prefix | Checks | Coverage highlights |
|---|---|---|---|
| 1. System & OS | `SYS` | 11 | OS support, kernel updates, pending reboot, SELinux/AppArmor, time sync, GRUB perms, Secure Boot, `/dev/shm`, Ctrl-Alt-Del |
| 2. Authentication | `AUTH` | 16 | Root lock, empty passwords, password age/complexity, faillock lockout, shell timeout, UID 0 audit, group/gshadow perms, sudo use_pty, sudo logfile |
| 3. SSH Hardening | `SSH` | 15 | sshd_config directives including ciphers, session timeout, banner, PermitEmpty, HostbasedAuth, sshd_config perms |
| 4. Filesystem | `FS` | 12 | World-writable files, SUID count, noexec mounts, sticky bit, crontab perms, unowned files, SSH key perms |
| 5. Network | `NET` | 13 | Firewall, IP forwarding, ICMP redirects, SYN cookies, source routing, martian logging, rp_filter, IPv6 RA, wireless disabled |
| 6. Logging & Audit | `LOG` | 10 | auditd, rsyslog, logrotate, audit rules, log size, `audit=1` at boot, journald persistence, remote syslog |
| 7. Integrity | `INT` | 8 | AIDE, rootkit scanner, suspicious cron, open ports, package GPG check, fail2ban, AIDE DB, cron dir perms |
| 8. Compliance | `COMP` | 12 | Legal banner, /tmp partition, /home+/var partitions, umask, ASLR, kptr_restrict, dmesg_restrict, ptrace, USB blacklist, cron service, cron.allow/at.allow |
| 9. Kernel attack surface | `KRN` | 12 | User namespaces, unprivileged eBPF, io_uring, userfaultfd, module lockdown, kexec, TTY ldisc autoload, lockdown mode, BPF JIT hardening, SysRq, exotic filesystem and protocol modules |

`aartool explain --list` prints all 109 with their titles, and
`aartool explain <ID>` explains any one of them.

Checks that require human judgment are flagged `(manual review required)` in the output, the script highlights them, the operator decides.

> Full reference: [`scripts/README.md`](scripts/README.md)

---

---

## Report Output

After running Steps 1 and 3, HTML and JSON reports are saved locally:

```
ansible-hardening/reports/
├── before/
│   └── <hostname>/
│       ├── report.html     # Human-readable audit report (pre-hardening)
│       └── report.json     # Machine-parseable report (pre-hardening)
└── after/
    └── <hostname>/
        ├── report.html     # Human-readable audit report (post-hardening)
        └── report.json     # Machine-parseable report (post-hardening)
```

Open `before/` and `after/` HTML reports side by side to visualise the security score improvement per control category. The JSON reports can be ingested into a SIEM, Elasticsearch, or a custom dashboard.

---
