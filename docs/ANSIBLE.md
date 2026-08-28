# The Ansible hardening collection

`cyberaar.hardening`: 52 CIS-aligned roles for the RHEL 9 family and
Ubuntu/Debian, in parallel `_rhel9` and `_ubuntu` pairs. OS detection is
automatic, so one playbook run applies the correct set per host.

Most people should drive these through [`aartool`](AARTOOL.md), which wraps the
playbook with a required target, a dry run that is a separate command, and a
typed confirmation before anything is applied:

```bash
aartool plan  --target web-01 --user ubuntu --only ssh    # preview
aartool apply --target web-01 --user ubuntu --only ssh
```

This document is for using the collection directly.

---

## How the collection is organised

52 roles in parallel pairs: each control area has a `_rhel9` variant and an
`_ubuntu` variant, plus a few Ubuntu-only roles such as `fail2ban`. OS detection
is automatic, so the playbook applies the correct set per host based on
`ansible_os_family`.

### The three-step pipeline

```
playbooks/0_execute_full_pipeline.yml
│
├── Step 1, 1_execute_baseline_before.yml    [tags: baseline, before]
│     ├── Copies aartool-baseline.sh to each remote host
│     ├── Runs the audit script
│     ├── Fetches HTML + JSON reports back to the control node
│     └── Reports saved to:
│           ansible-hardening/reports/before/<hostname>/
│
├── Step 2, 2_configure_hardening.yml        [tags: hardening]
│     ├── Verifies OS is supported (RedHat or Debian family)
│     ├── Detects OS family and applies the matching role set
│     ├── 52 roles applied in CIS dependency order:
│     │     kernel → MAC → auth → users → SSH → firewall →
│     │     network → ipv6 → wireless → crypto → audit →
│     │     journald → integrity → time → boot → banner →
│     │     services → updates → coredump → system →
│     │     mounts → secureboot → permissions → sudo →
│     │     cron → fail2ban
│     └── Each role is independently skippable via <role>_disabled=true
│
└── Step 3, 3_execute_baseline_after.yml     [tags: baseline, after]
      ├── Re-runs the audit script on each remote host
      ├── Fetches updated HTML + JSON reports
      ├── Reports saved to:
      │     ansible-hardening/reports/after/<hostname>/
      └── Compare before/ vs after/ to measure hardening impact
```

**Report comparison**: After a full pipeline run, open `reports/before/<host>/report.html` and `reports/after/<host>/report.html` side by side to see the security score improvement per control category.

---

### Step 1: Pre-Hardening Baseline

Captures the security posture of each host **before** any changes are made. This is your baseline measurement.

```bash
# Run Step 1 only
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> -s 1

# Or directly with ansible-playbook
ansible-playbook \
  -u <admin_user> -b \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=linux_servers" \
  --tags baseline \
  ansible-hardening/playbooks/1_execute_baseline_before.yml
```

Reports are saved locally to `ansible-hardening/reports/before/<hostname>/`.

---

### Step 2: System Hardening

Applies all applicable CIS-aligned hardening roles to each host. OS detection is automatic, you do not need separate runs for RHEL and Ubuntu hosts.

```bash
# Dry-run (check mode: no changes applied, always start here)
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> -s 2 -c

# Apply full hardening
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> -s 2

# Apply a specific category only (e.g. SSH)
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> -T ssh

# Skip a role without modifying the playbook
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> \
  -- --extra-vars "linux_bootloader_password_rhel9_disabled=true"
```

---

### Step 3: Post-Hardening Baseline

Re-runs the audit on each host to measure the impact of the hardening. The JSON output can also be ingested into a SIEM or dashboard.

```bash
# Run Step 3 only
bash scripts/run-hardening.sh -u <admin_user> -t <host_or_group> -s 3

# Or directly
ansible-playbook \
  -u <admin_user> -b \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=linux_servers" \
  --tags baseline \
  ansible-hardening/playbooks/3_execute_baseline_after.yml
```

Reports are saved to `ansible-hardening/reports/after/<hostname>/`.

---

## Running the Pipeline

### The `run-hardening.sh` wrapper (recommended)

The script auto-discovers `ansible-hardening/` by walking up the directory tree, run it from anywhere in the repo.

```
Usage: bash scripts/run-hardening.sh [options]

Options:
  -u USER    SSH admin user              (default: ansible)
  -t TARGET  Ansible host or group       (default: linux_servers)
  -s STEP    Step: 1 | 2 | 3 | all      (default: 2)
  -T TAGS    Override tags for step 2    (default: hardening)
  -K         Prompt for sudo password
  -c         Check mode (--check --diff, no changes applied)
  -h         Show help
```

**Common workflows:**

```bash
# 1. Connectivity check
ansible -i ansible-hardening/inventory/hosts linux_servers -m ping

# 2. Dry-run step 2 on a single Ubuntu host
bash scripts/run-hardening.sh -u ubuntu -t ubuntu-vm-01 -s 2 -c

# 3. Full 3-step pipeline dry-run (baseline → harden → baseline)
bash scripts/run-hardening.sh -u ubuntu -t ubuntu-vm-01 -s all -c

# 4. Apply full pipeline to a Rocky Linux host
bash scripts/run-hardening.sh -u rockylinux -t rocky-vm-01 -s all

# 5. Harden only SSH across all Linux servers
bash scripts/run-hardening.sh -u ansible -t linux_servers -T ssh

# 6. Full pipeline with sudo password prompt
bash scripts/run-hardening.sh -u ansible -t linux_servers -s all -K
```

Logs are automatically saved to `~/logs/<timestamp>-hardening-<target>.log`.

### Direct `ansible-playbook` usage

```bash
# Dry-run step 2 on a single host
ANSIBLE_LOG_PATH=~/logs/$(date +%Y-%m-%d)-hardening.log \
ansible-playbook --diff --check \
  -u <admin_user> -b \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=ubuntu-vm-01" \
  --tags hardening \
  ansible-hardening/playbooks/2_configure_hardening.yml

# Apply hardening to an entire group
ANSIBLE_LOG_PATH=~/logs/$(date +%Y-%m-%d)-hardening.log \
ansible-playbook --diff \
  -u <admin_user> -b \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=rhel_servers" \
  --tags hardening \
  ansible-hardening/playbooks/2_configure_hardening.yml

# Full 3-step pipeline via 0_execute_full_pipeline.yml
ansible-playbook --diff \
  -u <admin_user> -b \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=linux_servers" \
  ansible-hardening/playbooks/0_execute_full_pipeline.yml
```

---

## Hardening Roles Reference

Each control area has **two parallel roles**: one for RHEL 9 family and one for Ubuntu/Debian. Both are applied in a single play; the correct one activates automatically via `ansible_os_family`.

| Control Area | RHEL 9 Role | Ubuntu/Debian Role | CIS Section |
|---|---|---|---|
| Kernel hardening & sysctl | `linux_kernel_hardening_rhel9` | `linux_kernel_hardening_ubuntu` | 3.x, 4.x |
| Mandatory Access Control | `linux_selinux_rhel9` | `linux_apparmor_ubuntu` | 1.6 |
| Authentication & PAM | `linux_authselect_rhel9` | `linux_authselect_ubuntu` | 5.3 |
| User management | `linux_user_management_rhel9` | `linux_user_management_ubuntu` | 5.4, 5.5 |
| SSH hardening | `linux_ssh_hardening_rhel9` | `linux_ssh_hardening_ubuntu` | 5.2 |
| Firewall | `linux_firewalld_rhel9` | `linux_firewall_ubuntu` | 3.5 |
| IP forwarding / network params | `linux_ip_forwarding_rhel9` | `linux_ip_forwarding_ubuntu` | 3.1, 3.2 |
| Crypto policies / TLS | `linux_crypto_policies_rhel9` | `linux_crypto_policies_ubuntu` | 1.10 |
| Auditing & rsyslog | `linux_auditing_rhel9` | `linux_auditing_ubuntu` | 4.1, 4.2 |
| File integrity (AIDE) | `linux_aide_rhel9` | `linux_aide_ubuntu` | 1.4 |
| Time sync (chrony) | `linux_chrony_rhel9` | `linux_chrony_ubuntu` | 2.1.1 |
| Bootloader password | `linux_bootloader_password_rhel9` | `linux_bootloader_password_ubuntu` | 1.5.2 |
| Login banners | `linux_login_banner_rhel9` | `linux_login_banner_ubuntu` | 1.8 |
| Disable unnecessary services | `linux_disable_unnecessary_services_rhel9` | `linux_disable_unnecessary_services_ubuntu` | 2.1 |
| Automatic updates | `linux_dnf_automatic_rhel9` | `linux_unattended_upgrades_ubuntu` | 1.9 |
| Core dump restriction | `linux_core_dumps_rhel9` | `linux_core_dumps_ubuntu` | 1.6.4 |
| Ctrl-Alt-Del disable | `linux_ctrl_alt_del_rhel9` | `linux_ctrl_alt_del_ubuntu` | 1.6.1 |
| /tmp & /dev/shm mounts | `linux_tmp_mounts_rhel9` | `linux_tmp_mounts_ubuntu` | 1.1.x |
| Secure Boot | `linux_secure_boot_rhel9` | `linux_secure_boot_ubuntu` | 1.5.1 |
| File permissions | `linux_file_permissions_rhel9` | `linux_file_permissions_ubuntu` | 6.1 |
| Fail2ban | `linux_fail2ban_rhel9` | `linux_fail2ban_ubuntu` |: |
| Wireless interfaces | `linux_wireless_rhel9` | `linux_wireless_ubuntu` | 3.1.2 |
| Sudo hardening | `linux_sudo_hardening_rhel9` | `linux_sudo_hardening_ubuntu` | 1.3.2–1.3.3 |
| Cron hardening | `linux_cron_hardening_rhel9` | `linux_cron_hardening_ubuntu` | 5.1 |
| IPv6 disable | `linux_ipv6_rhel9` | `linux_ipv6_ubuntu` | 3.3.1 |
| journald hardening | `linux_journald_rhel9` | `linux_journald_ubuntu` | 4.2.1.x |

**RHEL 9 technology stack**: `firewalld`, `SELinux`, `dnf-automatic`, `authselect`, `grub2`

**Ubuntu/Debian technology stack**: `ufw`, `AppArmor`, `unattended-upgrades`, `PAM`, `grub`

### Role internal structure

Each role uses a two-file task pattern:

```
roles/<role_name>/
├── defaults/main.yml   # All tunable variables with safe defaults
├── handlers/main.yml   # Service restart / reload handlers
└── tasks/
    ├── main.yml        # Gating only: checks <role_name>_disabled, then imports tasks.yml
    └── tasks.yml       # Actual task implementation
```

To **disable any role** without modifying the playbook:

```bash
# Via run-hardening.sh extra-vars
ansible-playbook ... --extra-vars "linux_bootloader_password_rhel9_disabled=true"

# Or set in group_vars/host_vars
linux_aide_ubuntu_disabled: true
```

---

## Tag Reference

Use tags to run only a subset of the pipeline. All tags work with both `--tags` and `--skip-tags`.

| Tag | Roles activated |
|-----|----------------|
| `hardening` | All hardening roles |
| `kernel`, `sysctl` | `linux_kernel_hardening_*`, `linux_ip_forwarding_*` |
| `mac` | `linux_selinux_rhel9`, `linux_apparmor_ubuntu` |
| `auth`, `pam` | `linux_authselect_*` |
| `users` | `linux_user_management_*` |
| `ssh` | `linux_ssh_hardening_*` |
| `firewall` | `linux_firewalld_rhel9`, `linux_firewall_ubuntu` |
| `network` | `linux_ip_forwarding_*`, firewall roles |
| `ipv6` | `linux_ipv6_rhel9`, `linux_ipv6_ubuntu` |
| `crypto`, `tls` | `linux_crypto_policies_*` |
| `audit`, `logging` | `linux_auditing_*` |
| `journald` | `linux_journald_rhel9`, `linux_journald_ubuntu` |
| `integrity`, `aide` | `linux_aide_*` |
| `time`, `ntp` | `linux_chrony_*` |
| `boot`, `grub` | `linux_bootloader_password_*` |
| `secureboot` | `linux_secure_boot_*` |
| `banner` | `linux_login_banner_*` |
| `services` | `linux_disable_unnecessary_services_*` |
| `updates`, `patching` | `linux_dnf_automatic_rhel9`, `linux_unattended_upgrades_ubuntu` |
| `coredump` | `linux_core_dumps_*` |
| `system` | `linux_ctrl_alt_del_*` |
| `mounts`, `filesystem` | `linux_tmp_mounts_*`, `linux_file_permissions_*` |
| `permissions` | `linux_file_permissions_*` |
| `fail2ban` | `linux_fail2ban_rhel9`, `linux_fail2ban_ubuntu` |
| `wireless` | `linux_wireless_rhel9`, `linux_wireless_ubuntu` |
| `sudo` | `linux_sudo_hardening_rhel9`, `linux_sudo_hardening_ubuntu` |
| `cron` | `linux_cron_hardening_rhel9`, `linux_cron_hardening_ubuntu` |
| `baseline` | Baseline audit steps (Steps 1 & 3) |
| `before` | Step 1 only |
| `after` | Step 3 only |

---

## Inventory & Variable Configuration

### Inventory file: `inventory/hosts` (INI format)

```ini
[rhel_servers]
rocky-vm-01    index="139"

[ubuntu_servers]
ubuntu-vm-01   index="132"

[dmz_servers]
# Hosts here receive stricter thresholds via group_vars/dmz_servers.yml

[linux_servers:children]
rhel_servers
ubuntu_servers
# dmz_servers intentionally excluded: managed separately
```

Each host's `ansible_host` IP is derived from the `index` variable combined with a network prefix defined in `group_vars/rhel_servers.yml` or `group_vars/ubuntu_servers.yml`.

The naming convention for hosts follows: `<role>.<site>-<env>-<os>-<idx>.corp.example.com`
- `site`: short code identifying the site or data centre (e.g. `dc1`, `par`, `fra`)
- `env`: `pr` = prod, `st` = staging, `dv` = dev
- `os`: `rh` = RHEL, `ku` = Ubuntu

### Variable precedence (low → high)

```
group_vars/linux_servers.yml        ← shared defaults
  └── group_vars/rhel_servers.yml   ← RHEL-specific overrides
  └── group_vars/ubuntu_servers.yml ← Ubuntu-specific overrides
        └── group_vars/dmz_servers.yml ← DMZ stricter overrides
              └── host_vars/<hostname>.yml ← per-host overrides
                    └── --extra-vars at runtime ← highest precedence
```

Every role's `defaults/main.yml` exposes all tunable parameters. Review them before running to understand what will be applied in your environment.

---

## Sensitive Variables

The bootloader password must **never** be committed or stored in inventory. Set it in your shell immediately before running the pipeline, then unset it:

```bash
# Set before running
read -sr LINUX_BOOTLOADER_PASSWORD
export LINUX_BOOTLOADER_PASSWORD

# Run the pipeline
bash scripts/run-hardening.sh -u <admin_user> -t <target> -s all

# Unset immediately after
unset LINUX_BOOTLOADER_PASSWORD
```

If `LINUX_BOOTLOADER_PASSWORD` is not set, `run-hardening.sh` will warn and the `linux_bootloader_password_*` roles will be skipped automatically.

---
