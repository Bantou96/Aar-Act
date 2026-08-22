# cyberaar-toolkit

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](CONTRIBUTING.md)
[![Issues](https://img.shields.io/github/issues/cyberaar/cyberaar-toolkit)](https://github.com/cyberaar/cyberaar-toolkit/issues)
[![Release](https://img.shields.io/github/v/release/cyberaar/cyberaar-toolkit)](https://github.com/cyberaar/cyberaar-toolkit/releases)
[![Galaxy](https://img.shields.io/badge/galaxy-cyberaar.hardening-blue?logo=ansible)](https://galaxy.ansible.com/ui/repo/published/cyberaar/hardening/)
[![Molecule CI](https://github.com/cyberaar/cyberaar-toolkit/actions/workflows/molecule.yml/badge.svg)](https://github.com/cyberaar/cyberaar-toolkit/actions/workflows/molecule.yml)
[![Baseline Build](https://github.com/cyberaar/cyberaar-toolkit/actions/workflows/baseline-build.yml/badge.svg)](https://github.com/cyberaar/cyberaar-toolkit/actions/workflows/baseline-build.yml)
[![EE Image](https://img.shields.io/badge/ghcr.io-cyberaar%2Fee--hardening-blue?logo=docker)](https://github.com/cyberaar/cyberaar-toolkit/pkgs/container/ee-hardening)

**cyberaar-toolkit** is a volunteer-driven, open collaboration to gather and share
**best practices** for securing critical infrastructure against cyber threats.

Born out of the response to attacks on public-sector systems, the project brings
together practitioners at home, across the diaspora and anywhere else, to build a
**living, production-ready toolkit** available in French & English.

> *Sécurisons ensemble les infrastructures numériques critiques.*

---

## Table of Contents

- [What's Inside](#whats-inside)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Deliverable 0: Docker Execution Environment](#deliverable-0-docker-execution-environment-no-install)
- [Deliverable 0b: Security Dashboard](#deliverable-0b-security-dashboard)
- [Deliverable 1: Baseline Audit Script](#deliverable-1-baseline-audit-script-cyberaar-baselinesh)
- [Deliverable 2: Ansible Hardening Collection](#deliverable-2-ansible-hardening-collection)
  - [The Three-Step Pipeline](#the-three-step-pipeline)
  - [Step 1: Pre-Hardening Baseline](#step-1-pre-hardening-baseline)
  - [Step 2: System Hardening](#step-2-system-hardening)
  - [Step 3: Post-Hardening Baseline](#step-3-post-hardening-baseline)
- [Running the Pipeline](#running-the-pipeline)
- [Hardening Roles Reference](#hardening-roles-reference)
- [Tag Reference](#tag-reference)
- [Inventory & Variable Configuration](#inventory--variable-configuration)
- [Sensitive Variables](#sensitive-variables)
- [Report Output](#report-output)
- [Practices & Knowledge Base](#practices--knowledge-base) *(→ [cyberaar/Aar-Act](https://github.com/cyberaar/Aar-Act))*
- [Goal & Target Sectors](#goal--target-sectors)
- [How to Contribute](#how-to-contribute)
- [License](#license)
- [Contributors](#contributors)

---

## What's Inside

| Deliverable | Description | Version |
|-------------|-------------|---------|
| `scripts/aartool` | One front door: `inspect`, `plan`, `apply`, `surface` (kernel attack surface), `doctor` (preflight), `report` (dashboard), `diff` (drift) | v0.4.0 |
| `scripts/cyberaar-baseline.sh` | Standalone bash script: audits a Linux server across 96 security checks, produces HTML + JSON reports with Ansible remediation plan | v4.2.0 |
| `ansible-hardening/` | Ansible collection (`cyberaar.hardening`): 51 CIS-aligned hardening roles for RHEL 9 family and Ubuntu/Debian | v2.0.0 |
| `execution-environment/` | Docker image: self-contained EE with Ansible + collection + playbooks, no local install required | `ghcr.io/cyberaar/ee-hardening` |
| `dashboard/index.html` | Single-file web dashboard: visualise baseline JSON reports across multiple hosts, before/after comparison, PDF export | zero dependencies |

Each is independent: run the baseline script standalone, use the Ansible collection directly, or pull the Docker
image for a zero-install experience. `aartool` wraps the first two behind one set of options for people who would
rather not learn two.

---

## Repository Structure

```
cyberaar-toolkit/
├── dashboard/
│   └── index.html                    # Single-file security dashboard (zero dependencies)
├── execution-environment/
│   ├── Containerfile                 # Docker image definition (build from repo root)
│   └── README.md                     # EE usage guide
├── scripts/
│   ├── cyberaar-baseline.sh          # Standalone audit script (v4.2.0), generated bundle
│   ├── build.sh                      # Rebuilds cyberaar-baseline.sh from src/
│   ├── run-hardening.sh              # Pipeline runner (wraps ansible-playbook)
│   ├── README.md                     # Baseline checker full reference
│   └── src/                          # Source layout (edit here, not in the bundle)
│       ├── main.sh                   # Shebang, CLI args, install/uninstall
│       ├── run.sh                    # Execution entry point
│       ├── lib/                      # core.sh, ansible_map.sh, remote.sh
│       ├── checks/                   # 8 files, one per check section
│       └── renderers/                # terminal.sh, json.sh, html.sh
├── ansible-hardening/
│   ├── galaxy.yml                    # Collection metadata (cyberaar.hardening v2.0.0)
│   ├── requirements.yml              # ansible.posix + community.general
│   ├── inventory/
│   │   ├── hosts                     # INI inventory (rhel_servers / ubuntu_servers / dmz_servers)
│   │   └── group_vars/
│   │       ├── all.yml               # Global defaults
│   │       ├── linux_servers.yml     # Shared Linux defaults
│   │       ├── rhel_servers.yml      # RHEL-specific vars + IP prefix
│   │       ├── ubuntu_servers.yml    # Ubuntu-specific vars + IP prefix
│   │       └── dmz_servers.yml       # Stricter thresholds for DMZ hosts
│   ├── playbooks/
│   │   ├── 0_execute_full_pipeline.yml      # Pipeline orchestrator (imports all 3 steps)
│   │   ├── 1_execute_baseline_before.yml    # Pre-hardening audit
│   │   ├── 2_configure_hardening.yml        # Hardening roles (RHEL9 + Ubuntu)
│   │   └── 3_execute_baseline_after.yml     # Post-hardening audit
│   └── roles/                        # 51 hardening roles (parallel RHEL9 + Ubuntu)
└── .github/                          # Issue templates, PR template
```

---

## Prerequisites

### Control node (where you run Ansible)

```bash
# Python 3.8+ and Ansible 2.14+
pip install ansible

# Required Ansible collections (run once)
ansible-galaxy collection install -r ansible-hardening/requirements.yml
# Installs: ansible.posix >=1.5.4  |  community.general >=8.0.0
```

### Your inventory

`ansible-hardening/inventory/hosts` is **gitignored**, because it names real
machines. A fresh clone does not have one. Start from the template:

```bash
cp ansible-hardening/inventory/hosts.example ansible-hardening/inventory/hosts
```

Then edit it: the example lists two placeholder hosts and the group layout. The
format is INI on purpose, being the easiest thing to read over a colleague's
shoulder and to correct at three in the morning.

Note that `dmz_servers` is deliberately not part of `linux_servers`, so a
fleet-wide run does not reach a DMZ host by accident.

### Managed nodes (the servers being hardened)

- **RHEL 9 family**: RHEL 9, AlmaLinux 9, Rocky Linux 9
- **Ubuntu/Debian**: Ubuntu 20.04, 22.04, 24.04, Debian 11, 12
- Python 3 installed
- SSH access with a sudo-capable admin user
- No agent required, push-based via SSH

---

## Deliverable 0: Docker Execution Environment (no install)

If you don't want to install Ansible locally, pull the pre-built Docker image:

```bash
docker pull ghcr.io/cyberaar/ee-hardening:latest
```

**Dry-run hardening against a remote host (no changes):**

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/ansible-hardening/inventory:/inventory:ro \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver" \
    -u admin -b --check \
    /usr/share/cyberaar/playbooks/2_configure_hardening.yml
```

**Full pipeline (baseline → harden → baseline):**

```bash
docker run --rm -it \
  -v ~/.ssh:/root/.ssh:ro \
  -v $(pwd)/ansible-hardening/inventory:/inventory:ro \
  -v $(pwd)/reports:/reports \
  ghcr.io/cyberaar/ee-hardening:latest \
  ansible-playbook \
    -i /inventory/hosts \
    --extra-vars "target=myserver baseline_output_dir=/reports" \
    -u admin -b \
    /usr/share/cyberaar/playbooks/0_execute_full_pipeline.yml
```

> Full reference: [`execution-environment/README.md`](execution-environment/README.md)

---

## Deliverable 0b: Security Dashboard

`dashboard/index.html` is a single-file, zero-dependency web dashboard for visualising baseline reports across your entire fleet. No install, no server, no internet connection required.

### Features

| Feature | Description |
|---|---|
| Fleet overview | Score ring per host (green ≥ 80%, amber ≥ 60%, red < 60%), PASS / WARN / FAIL counts, sorted worst-first |
| Before/After delta | Load a pre- and post-hardening report for the same host: score delta pill appears automatically |
| Host detail panel | Click any host card: slide-in panel with full check table |
| Status filter | Filter checks by FAIL / WARN / PASS inside the detail panel |
| Ansible remediation | Copy-ready `ansible-playbook` command pre-filled with hostname and inventory path |
| PDF export | Browser print → PDF (header and panel hidden automatically) |
| Fully offline | No CDN, no npm, no build step: works in air-gapped environments |

---

### Step 1: Generate JSON reports

```bash
# Run directly on the local machine
sudo bash scripts/cyberaar-baseline.sh \
  --json-out /tmp/before-$(hostname).json

# Or via Ansible (pre-hardening)
ansible-playbook \
  -i ansible-hardening/inventory/hosts \
  --extra-vars "target=myserver" -u admin -b \
  ansible-hardening/playbooks/1_execute_baseline_before.yml
# → report saved to ansible-hardening/reports/before/myserver/report.json
```

---

### Step 2: Open the dashboard

**Linux / macOS:**
```bash
xdg-open dashboard/index.html         # Linux
open dashboard/index.html             # macOS
```

**WSL2 (Windows Subsystem for Linux):**
```bash
# Option A: open via Windows Explorer
explorer.exe dashboard/index.html

# Option B: get the Windows path and paste into browser
wslpath -w $(pwd)/dashboard/index.html
# Output: \\wsl$\Ubuntu\...\dashboard\index.html
# Paste that path into Chrome / Edge address bar
```

**Any platform, serve locally:**
```bash
python3 -m http.server 8080 --directory dashboard/
# Then open http://localhost:8080 in your browser
```

---

### Step 3: Load reports

1. Click **Load Reports** (top right) or drag & drop `.json` files onto the drop zone
2. The dashboard groups reports by `host` field, load reports from multiple hosts at once
3. For before/after comparison: load two reports for the same host, the dashboard detects them automatically by date and shows the score delta

**Where to find reports after an Ansible pipeline run:**
```
ansible-hardening/reports/before/<hostname>/report.json   ← pre-hardening
ansible-hardening/reports/after/<hostname>/report.json    ← post-hardening
```

---

### Step 4: Explore

- **Fleet view**: all hosts on one screen, worst score first
- **Click a host card**: opens the detail panel with all 96 checks
- **Filter** by FAIL / WARN / PASS to focus on what matters
- **Ansible remediation** block shows the exact command to remediate FAIL/WARN items
- **Export PDF**: click the button top right, then use your browser's print dialog

> Full reference: [`dashboard/README.md`](dashboard/README.md)

---

## Deliverable 0c: `aartool`, one front door

The toolkit grew two entry points with two conventions for one workflow.
`cyberaar-baseline.sh` takes `--host` and `--user`; `run-hardening.sh` takes `-t`
and `-u`, and uses `-T` for tags, one shift key away from `-t` for the target, on
a tool that rewrites `sshd_config`, PAM and firewall rules.

`aartool` wraps both. Neither is replaced, and both stay usable on their own.

```bash
# Audit the machine you are on
sudo scripts/aartool inspect

# Audit one remote host
scripts/aartool inspect --host 10.0.1.10 --user admin

# See what hardening would change. Nothing is changed.
scripts/aartool plan --target ubuntu-vm-01 --user ubuntu

# One category only, still a preview
scripts/aartool plan --target ubuntu-vm-01 --user ubuntu --only ssh

# Apply. Asks you to type the target name back.
scripts/aartool apply --target ubuntu-vm-01 --user ubuntu
```

### `aartool surface` — the window before the patch

Red Hat and Debian ship the patch. Nothing helps you in the window *before* the
patch exists, or on the machine you cannot reboot until the change window in
three weeks. `surface` is for that window.

```bash
aartool surface              # what would the next kernel LPE still reach here?
aartool surface --strict     # include mitigations that break real workloads
aartool surface --fix        # print the sysctl drop-in that closes the gaps
sudo aartool surface --apply # write it to /etc/sysctl.d and load it
```

These settings close **classes** of local privilege escalation rather than
individual CVEs. Unprivileged user namespaces are the doorway a large share of
published Linux LPEs walk through: they hand an unprivileged process
`CAP_SYS_ADMIN` inside its own namespace, which is what turns a bug in nftables,
io_uring or OverlayFS into root. Turning them off fixes none of those bugs. It
removes the doorway they all use.

Every mitigation states **what it costs**, and there are two tiers:

| tier | meaning |
|---|---|
| `safe` | no mainstream workload is known to depend on it |
| `strict` | will break something real for somebody, and the cost is printed |

Only the safe tier runs by default. A tool that silently breaks your containers
gets uninstalled, and then it protects nothing.

Nothing here is compiled and nothing is rebooted. Everything applied lands in one
drop-in file you can delete to revert. The same settings are audited as the
`KRN-01`..`KRN-12` family in every baseline report, so the assessment and the
remediation are two views of one thing — and a test asserts they cannot drift
apart.

### `aartool report` — the dashboard, one command away

The toolkit already ships a single-file dashboard with no server and no internet
requirement. The friction was everything around it: run an audit, find the JSON,
find the dashboard, open a browser, drag files in.

```bash
aartool report /tmp/audit/*.json --out fleet.html   # self-contained, sendable
aartool report /tmp/audit/*.json --open             # just look at it
aartool report --serve 8080                         # headless server
```

`--out` is the one worth knowing about. It produces **one HTML file with the
results already inside**, which opens offline on any machine with no other
files. Attach it to an email; the person receiving it needs nothing installed
and has never heard of this toolkit.

`--serve` binds to `127.0.0.1` only and says so, because this renders audit
results for an entire estate and has no authentication. Reach it with
`ssh -L 8080:127.0.0.1:8080 user@host`.

The dashboard itself is never modified. A copy is made and a small bootstrap
appended that feeds the dashboard's own data structure, and the injected JSON has
`<` and `>` escaped to their `\u` form: a hostname is attacker-influenced on a
machine you were asked to audit, and `</script>` in one would otherwise end the
block and turn the rest of a file you email to a client into markup. There is a
test that attempts exactly that.

### `aartool diff` — drift, and the exit code that makes it useful

```bash
aartool diff last-week.json today.json
aartool diff last.json today.json --quiet || mail -s "drift on $(hostname)" soc@example.com
```

| exit | meaning |
|---|---|
| `0` | nothing regressed |
| `1` | at least one check regressed |
| `2` | the reports could not be compared |

The exit code is the whole feature. A weekly audit that mails you 109 results
teaches you to filter the mail. One that stays silent unless something
**regressed** is a thing you actually read, and `--quiet` prints nothing at all
when nothing has changed.

Regressions and improvements are deliberately not symmetric. PASS to FAIL is an
alert; FAIL to PASS is a note at the bottom. Treating them the same is how a
report becomes wallpaper.

It refuses to compare two different hosts. A diff between two machines looks
exactly like drift and is not.

### `aartool doctor`

```bash
aartool doctor                      # everything plan and apply depend on
aartool doctor --target web-01      # also test SSH and sudo on that host
```

Exits non-zero if anything is missing, so it works as a CI gate. It exists
because `ansible-playbook` failing halfway through with "couldn't resolve module
ansible.posix.sysctl" tells an operator nothing about `ansible-galaxy`, and a
half-applied hardening run is expensive.

### Two things aartool does differently from what it wraps, both on purpose:

**The dry run is a command, not a flag.** `run-hardening.sh` applies by default
and takes `-c` to preview, so one missing character separates a report from a
rewritten SSH config. Here `plan` shows and `apply` does.

**`--target` is required.** `run-hardening.sh` defaults to the group
`linux_servers`, which is every machine in the inventory, so a bare invocation
hardens the whole estate. `aartool` refuses to guess, checks the target exists in
the inventory before calling Ansible, and `apply` asks you to type the name back
rather than press `y`. The dangerous mistake here is not "did I mean to run
this", it is "did I mean this group or that one host".

Built from `scripts/aartool-src/` by `scripts/build-aartool.sh`, the same way the
baseline is built from `scripts/src/`. Edit the sources, not the bundle; CI fails
the build if the two drift.

---

## Deliverable 1: Baseline Audit Script (`cyberaar-baseline.sh`)

The standalone audit script runs **96 security checks** across 8 sections and produces:

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

96 checks across 8 sections, each mapped to a CIS benchmark control:

| Section | Checks | Coverage highlights |
|---|---|---|
| 1. System & OS | 10 | OS support, kernel updates, SELinux/AppArmor, time sync, GRUB perms, Secure Boot, `/dev/shm`, Ctrl-Alt-Del |
| 2. Authentication | 16 | Root lock, empty passwords, password age/complexity, faillock lockout, shell timeout, UID 0 audit, group/gshadow perms, sudo use_pty, sudo logfile |
| 3. SSH Hardening | 15 | 15 sshd_config directives including ciphers, session timeout, banner, PermitEmpty, HostbasedAuth, sshd_config perms |
| 4. Filesystem | 12 | World-writable files, SUID count, noexec mounts, sticky bit, crontab perms, unowned files, SSH key perms |
| 5. Network | 12 | Firewall, IP forwarding, ICMP redirects, SYN cookies, source routing, martian logging, rp_filter, IPv6 RA, wireless disabled |
| 6. Logging & Audit | 8 | auditd, rsyslog, logrotate, audit rules, log size, `audit=1` at boot, journald persistence, remote syslog |
| 7. Integrity | 8 | AIDE, rootkit scanner, suspicious cron, open ports, package GPG check, fail2ban, AIDE DB, cron dir perms |
| 8. Compliance | 12 | Legal banner, /tmp partition, /home+/var partitions, umask, ASLR, kptr_restrict, dmesg_restrict, ptrace, USB blacklist, cron service, cron.allow/at.allow |

Checks that require human judgment are flagged `(manual review required)` in the output, the script highlights them, the operator decides.

> Full reference: [`scripts/README.md`](scripts/README.md)

---

## Deliverable 2: Ansible Hardening Collection

The Ansible collection (`cyberaar.hardening`) contains **51 hardening roles** organised in parallel pairs, each control area has a `_rhel9` variant and an `_ubuntu` variant (plus some Ubuntu-only roles like `fail2ban`). OS detection is automatic: the playbook applies the correct role set based on `ansible_os_family`.

### The Three-Step Pipeline

```
playbooks/0_execute_full_pipeline.yml
│
├── Step 1, 1_execute_baseline_before.yml    [tags: baseline, before]
│     ├── Copies cyberaar-baseline.sh to each remote host
│     ├── Runs the audit script
│     ├── Fetches HTML + JSON reports back to the control node
│     └── Reports saved to:
│           ansible-hardening/reports/before/<hostname>/
│
├── Step 2, 2_configure_hardening.yml        [tags: hardening]
│     ├── Verifies OS is supported (RedHat or Debian family)
│     ├── Detects OS family and applies the matching role set
│     ├── 51 roles applied in CIS dependency order:
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

## Practices & Knowledge Base

Community-maintained security guides and templates have moved to their own repository:

**[cyberaar/Aar-Act](https://github.com/cyberaar/Aar-Act)**: practices (English), translations (French), and worked examples.

---

## Goal & Target Sectors

Build a **free, community-maintained security toolkit** that provides practical, context-adapted tools and guides for:

- Government & public administration
- Energy & utilities
- Finance & banking
- Telecom & critical systems
- Healthcare & transport

---

## How to Contribute

No long commitments required, add one improvement when you have 10 minutes.

1. **Browse** existing sections or suggest new ones via [Issues](https://github.com/cyberaar/cyberaar-toolkit/issues)
2. **Fork** this repo or create a branch
3. **Add or edit**: hardening roles in `ansible-hardening/roles/`, or guides in [cyberaar/Aar-Act](https://github.com/cyberaar/Aar-Act)
4. **Submit** a Pull Request, reference the CIS benchmark section when adding hardening controls
5. Get **credit** in the Contributors list

New hardening roles should follow the `linux_<category>_<rhel9|ubuntu>` naming convention and include parallel RHEL9 and Ubuntu implementations.

**Contributing to the baseline script:** `cyberaar-baseline.sh` is a generated bundle, do not edit it directly. Edit the source files under `scripts/src/`, then rebuild:

```bash
bash scripts/build.sh
bash -n scripts/cyberaar-baseline.sh   # verify syntax
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

---

## License

**GNU General Public License v3.0**

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See the [LICENSE](LICENSE) file for the full text.

© 2025–2026 CyberAar Team

---

## Contributors

- [@Bantou96](https://github.com/Bantou96), Founder
- [@moustaphisene](https://github.com/moustaphisene), Contributor (CIS gap coverage: sudo, cron, wireless hardening roles)
- [Claude](https://claude.ai) (Anthropic), AI pair programmer

---

*#Cybersecurity #Hardening #AarAct #CyberAar*
