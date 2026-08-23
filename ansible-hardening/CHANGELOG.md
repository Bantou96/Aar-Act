# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0]: 2026-08-23

The release that gives the toolkit a front door. Everything here was either
built or corrected while running the tool against a real 15-node estate, not
against its own tests.

### Added

- **`aartool`**, one command in front of everything. `inspect`, `advise`,
  `explain`, `plan`, `apply`, `surface`, `doctor`, `report`, `diff`, `install`.
  Neither `cyberaar-baseline.sh` nor `run-hardening.sh` is replaced and both
  stay independently usable. Two deliberate differences from what it wraps: the
  dry run is a command (`plan`) rather than a flag, and `--target` is required,
  because `run-hardening.sh` defaults to the group that is the entire inventory.
- **`aartool advise`**: turns a report into waves ordered by reachability, not
  severity. What an attacker reaches with no account, then what turns an account
  into root, then what would have stopped you noticing. Findings whose fix has a
  real operational cost are lifted into a separate "decide before you apply"
  list rather than hidden.
- **`aartool explain <ID>`**: what a check reads, the concrete path from finding
  to compromised machine, what closing it breaks, how to fix it by hand and with
  Ansible. 36 written entries; answers for all 109 IDs by falling back to the
  remediation map.
- **`aartool surface`**: the kernel attack surface as a first-class subject.
  Unprivileged user namespaces, eBPF, io_uring, userfaultfd, kexec, module
  loading, TTY line-discipline autoload, lockdown, BPF JIT hardening, SysRq.
  Two tiers, and only `safe` applies by default.
- **13 new checks**, 96 to **109**: the `KRN-01`..`KRN-12` kernel attack-surface
  family and `SYS-11`, which detects a kernel installed but not running.
- **`aartool report --out`**: one self-contained HTML file with the results
  embedded, openable offline on a machine that has never heard of this toolkit.
- **`aartool diff`**: exit `0` nothing regressed, `1` regressed, `2` not
  comparable. Refuses to compare two different hosts.
- **`--jump USER@HOST[:PORT]`** for auditing through a bastion, which is the
  shape of most estates.
- **9 kernel attack-surface toggles** in `linux_kernel_hardening_rhel9` and
  `_ubuntu`, so every `KRN` finding has a remediation path. Six default on, the
  three that break real workloads default off with the reason written beside
  them.
- **`docs/`**: `AARTOOL.md`, `ANSIBLE.md`, `BASELINE.md`, `DASHBOARD.md`,
  `CONTAINER.md`.
- **Guard tests**, each written after the defect it describes was found in
  shipped code: remediation-map validity, documentation against the CLI's own
  help, knowledge-base accuracy, distribution mapping, report escaping, version
  consistency, and a Docker-based end-to-end proof of the remote path.

### Changed

- **The repository is now `cyberaar/aartool`** (was `cyberaar-toolkit`). GitHub
  redirects the old URL permanently. The collection remains
  `cyberaar.hardening`: the repository is the product, the collection is a
  library it ships.
- **The container image is `ghcr.io/cyberaar/aartool`** and now contains
  `aartool` itself, which the `ee-hardening` image never did. The old name is
  still pushed so existing pulls keep working.
- `aartool inspect` writes reports to `./reports` by default and hands them back
  to the user who invoked `sudo`. Previously it wrote nothing without `-o`, so
  the documented two-command first run failed for every new user.
- The root README is the workflow and nothing else; the reference material moved
  to `docs/`.
- Distribution detection consults `ID_LIKE` before `ID`, so derivatives inherit
  the right role family instead of being told to switch operating system.

### Fixed

- **The JSON report claimed `"version": "4.0.0"` regardless of the script's real
  version**, which had been `4.2.0`. Hardcoded in the renderer. Anything keying
  off that field, a SIEM ingest or an auditor asking which build produced the
  evidence, was told something untrue. Now interpolated, and guarded.
- **The remote audit could not work on a hardened host and reported success
  anyway.** OpenSSH 9 `scp` speaks SFTP, and removing the `sftp` subsystem is a
  normal hardening step, so the copy failed on exactly the machines most likely
  to be running a security tool. Replaced with an `ssh`-piped `cat`, every step
  now checked, and connections multiplexed so a fleet scan does not look like a
  brute-force attempt to `fail2ban`.
- **`--ssh-opt '-J user@bastion'` never worked with `--ssh-key`.** `ssh` does not
  pass the outer connection's options to the jump hop, so hop one authenticated
  with whatever the defaults were. `--jump` builds the `ProxyCommand` correctly.
- `--ssh-key` now implies `IdentitiesOnly=yes`, so a fleet scan from a
  workstation with several keys loaded does not get that workstation banned.
- Four knowledge-base entries described the wrong check. Existence was guarded;
  topical accuracy was not. Both are now.
- The HTML report shipped invalid CSS from a `${RING_COLOR}ALPHA` typo, so the
  score ring had no glow and nothing was linting the file.
- Every audit printed a remediation command referencing `inventory/hosts.yml`,
  which has never existed.

### Security

- `agent`-side changes only. No credential handling changed in this release.

## [2.0.0]: 2026-03-12

### Added

- **`dashboard/index.html`**: single-file, zero-dependency web dashboard for visualising `cyberaar-baseline` JSON reports:
  - Fleet overview: score ring per host (green ≥ 80%, amber ≥ 60%, red < 60%), PASS/WARN/FAIL counts, sorted worst-first
  - Before/after comparison: automatic when two reports for the same host are loaded, score delta pill + side-by-side score boxes
  - Host detail slide-in panel: full 96-check table with FAIL/WARN/PASS filter
  - Copy-ready `ansible-playbook` remediation command per host
  - PDF export via browser print (header and panel hidden automatically)
  - CyberAar PNG logo embedded as base64, consistent branding with HTML baseline report
  - Works fully offline, no CDN, no npm, no build step; compatible with air-gapped environments
- **`execution-environment/Containerfile`**: Docker/Podman execution environment published to `ghcr.io/cyberaar/ee-hardening`:
  - Built on `python:3.11-slim`; includes `ansible-core`, `cyberaar.hardening`, `ansible.posix`, `community.general`
  - Playbooks embedded at `/usr/share/cyberaar/playbooks/`; `cyberaar-baseline` at `/usr/local/bin/`
  - `COLLECTION_VERSION` build arg pins exact collection release; `latest` + `vX.Y.Z` tags pushed on every GitHub release
  - Zero local Ansible install required, one `docker run` to harden a server
- **`.github/workflows/ee-build.yml`**: CI/CD for EE image; authenticates via `GITHUB_TOKEN` (no extra secrets needed)

### Changed

- **Repo structure flattened**: `automation/ansible-hardening/` → `ansible-hardening/`; `automation/scripts/` → `scripts/`; `automation/` directory removed. All workflow, README, and script path references updated.
- **`2_configure_hardening.yml`**: added explicit `ansible.builtin.setup` task with `become: false` and `tags: always` in `pre_tasks`. Fixes `ansible_os_family is undefined` error when running with `--tags <non-hardening>` (e.g. `--tags ssh`), caused by play-level `tags: [hardening]` causing `gather_facts` to be skipped while `pre_tasks` tagged `always` still execute.
- **`.gitignore`**: replaced Jekyll boilerplate with relevant entries: `.ansible/`, `*.tar.gz`, `mnt/`
- **Issue templates**: replaced content-oriented templates with technical ones: `bug-report.md` (Ansible role / baseline script bugs), `feature-request.md` (new hardening controls / baseline checks); `best-practice-suggestion.md` removed (moved to `cyberaar/Aar-Act`)
- **PR template**: reoriented to technical contributions: CIS reference field, Molecule test-plan checklist

### Fixed

- Committed Galaxy build artifact (`cyberaar-hardening-1.9.0.tar.gz`) removed from git history
- Orphaned `automation/example.md` removed
- `reports/` `.gitkeep` files removed (directory already covered by `.gitignore`)

## [1.9.1]: 2026-03-12

### Added

- **`cyberaar-baseline.sh` v4.2.0**: 3 new checks (96 total):
  - **NET-13** (CIS 3.3.1): IPv6 fully disabled, checks `net.ipv6.conf.all.disable_ipv6=1` + `default`; maps to `linux_ipv6_*`
  - **LOG-09** (CIS 4.2.1.1): journald `Storage=persistent` configured in drop-in conf; maps to `linux_journald_*`
  - **LOG-10** (CIS 4.2.1.3): journald `RateLimitBurst` configured; maps to `linux_journald_*`
  - Ansible map updated: `LOG-07` now maps to `linux_journald_*` (was `linux_auditing_*`)
- **`.github/workflows/baseline-build.yml`**: CI job that verifies `build.sh` succeeds, checks bundle is in sync with `src/`, validates bash syntax, and asserts ≥ 90 unique check IDs

### Changed

- `cyberaar-baseline.sh` / `src/main.sh`: version bumped 4.0.0 → 4.2.0 (4.1.0 was a documentation-only bump that was never reflected in the source)

## [1.9.0]: 2026-03-12

### Added

- **`linux_ipv6_rhel9` + `linux_ipv6_ubuntu`**: Disable IPv6 at kernel level (CIS 3.3.1): sysctl `net.ipv6.conf.{all,default,lo}.disable_ipv6=1` persisted to `/etc/sysctl.d/99-cis-ipv6.conf`; modprobe `options ipv6 disable=1` persisted to `/etc/modprobe.d/99-cis-ipv6.conf`; Ubuntu variant runs `update-initramfs -u -k all` to persist across kernel updates
- **`linux_journald_rhel9` + `linux_journald_ubuntu`**: systemd-journald hardening (CIS 4.2.1.x): drop-in `/etc/systemd/journald.conf.d/99-cis-journald.conf` sets persistent storage, compression, syslog forwarding, rate limiting, and disk retention limits; `/var/log/journal` created for persistent mode
- **NFS mount scan** in `linux_file_permissions_rhel9` / `linux_file_permissions_ubuntu`: new `linux_file_permissions_check_nfs_mounts` variable (default `true`) scans `/etc/fstab` for NFS entries and emits a debug warning if found (CIS 1.1.x, verify nodev/nosuid on NFS)
- **Molecule scenarios**: `ipv6` and `journald`: dual-platform (Rocky Linux 9 + Ubuntu 22.04), full converge/verify/idempotency
- **CI matrix** expanded from 29 → 31 Molecule scenarios

### Fixed

- **BUG** `linux_fail2ban_rhel9` was present in `roles/` since v1.7.0 but was **never added** to `playbooks/2_configure_hardening.yml` under the RedHat block, silently skipped on all RHEL9 runs. Role is now correctly included in the playbook.

### Changed

- `galaxy.yml`: version → 1.9.0; description updated to 51 roles (25 RHEL9 + 26 Ubuntu/Debian); tags: added `ipv6`, `journald`
- `playbooks/2_configure_hardening.yml`: added `linux_ipv6_*` (tag: `network, ipv6`) after ip_forwarding; added `linux_journald_*` (tag: `audit, logging, journald`) after auditing

## [1.8.0]: 2026-03-11

### Added

- **29 Molecule test scenarios**: full integration test coverage for all 47 roles across RHEL 9 (Rocky Linux 9) and Ubuntu 22.04 Docker containers; all 29 scenarios run in CI on every PR targeting `automation/ansible-hardening/`
- **`ansible-lint` CI job**: `.github/workflows/molecule.yml` now gates every PR with `ansible-lint roles/ playbooks/` (profile: `basic`) before running Molecule; enforces collection-wide code quality
- **`.ansible-lint` configuration**: `automation/ansible-hardening/.ansible-lint`: `profile: basic`, `var-naming[no-role-prefix]` explicitly skipped (shared variable names intentionally unprefixed so one `group_vars` entry controls both OS variants), `molecule/` excluded

### Fixed

- **BUG** `linux_bootloader_password_rhel9` / `ubuntu`: `grub2-mkpasswd-pbkdf2` received the password only once via stdin; the command requires it twice (password + confirmation). Fixed: `stdin: "{{ linux_bootloader_password }}\n{{ linux_bootloader_password }}\n"`
- **BUG** `linux_bootloader_password_rhel9` / `ubuntu`: `regex_search` pattern did not match the actual command output format. Fixed: `regex_search('grub\\.pbkdf2\\.sha512\\.\\S+')`
- **BUG** `linux_bootloader_password_rhel9`: handler `Rebuild GRUB config` was defined as a `block`: Ansible does not support blocks in handlers. Removed the invalid block; GRUB rebuild is handled inline by the existing `grub2-mkconfig` tasks
- **BUG** `linux_bootloader_password_ubuntu` / `linux_secure_boot_ubuntu`: `update-grub` fails in Docker containers (overlay filesystem). Added `failed_when: false` to the handler and to the `/boot` chmod task
- **BUG** `linux_crypto_policies_rhel9`: sshd reload loop lacked `failed_when: false`; fails in containers where sshd is not running. Fixed
- **BUG** `linux_core_dumps_ubuntu`: `systemctl daemon-reload` called via `ansible.builtin.command` (command-instead-of-module). Replaced with `ansible.builtin.systemd: daemon_reload: true`
- **BUG** `linux_tmp_mounts_ubuntu`: handler used `command: systemctl restart tmp.mount`; replaced with `ansible.builtin.systemd: name: tmp.mount / state: restarted / daemon_reload: true`
- **BUG** `playbooks/1_execute_baseline_before.yml` / `3_execute_baseline_after.yml`: fetch tasks used `ignore_errors: true`. Replaced with `failed_when: false`

### Changed

- `galaxy.yml`: version → 1.8.0
- YAML formatting standardised across all 47 role files (`yaml[new-line-at-end-of-file]`, `yaml[line-length]` violations resolved; 668 lint findings reduced to 0)

---

## [1.7.1]: 2026-03-09

### Fixed

- **BUG** `cyberaar-baseline.sh`: `get_ssh()` helper used `tail -1`: SSH uses first-match-wins so the last occurrence of a directive was returned, producing incorrect results across all 15 SSH checks. Fixed to `head -1`
- **BUG** `cyberaar-baseline.sh`: NET-12 wireless check only recognised `Soft blocked: yes` from rfkill; systems with a hardware kill switch (`Hard blocked: yes`) incorrectly reported WARN. Both states now accepted
- **BUG** `cyberaar-baseline.sh`: remote script path unquoted in SSH exec and cleanup commands in `lib/remote.sh`: defensive quoting added
- **BUG** `linux_apparmor_ubuntu`: "Set specific profiles to enforce mode" task used `changed_when: true`, reporting changed on every run even when profiles were already enforced. Now checks `aa-enforce` stdout for `Setting` to report changed only when a profile is actually transitioned
- **DOCS** `role-linux_authselect_rhel9`: added missing pwquality keys (`maxrepeat`, `maxclassrepeat`, `dictcheck`) and faillock keys (`even_deny_root`, `root_unlock_time`) to Variables tables
- **DOCS** `role-linux_bootloader_password_rhel9`: added missing `linux_single_user_auth` variable (CIS 1.4.3)
- **DOCS** `role-linux_tmp_mounts_rhel9`: added missing `linux_tmp_mounts_enabled`, `linux_home_nodev_enabled` (CIS 1.1.14), `linux_sticky_bit_enabled` (CIS 1.1.21)
- **DOCS** `role-linux_user_management_rhel9`: added 7 missing CIS 6.2.x audit variables and extended CIS Coverage section

---

## [1.7.0]: 2026-03-09

### Added

- **`linux_sudo_hardening_rhel9`**: new role: installs sudo, deploys `/etc/sudoers.d/99-cis-hardening` drop-in with `Defaults use_pty` and `Defaults logfile=` (CIS 1.3.2–1.3.3), validates with `visudo -cf`
- **`linux_cron_hardening_rhel9`**: new role: hardens cron/at directory permissions (CIS 5.1.2–5.1.7), enforces `cron.allow`/`at.allow` allow-list model (CIS 5.1.8–5.1.9), enables `crond` service (CIS 5.1.1)
- **`linux_wireless_rhel9`**: new role: disables wireless via `nmcli radio all off` (with check-mode guard), blacklists Wi-Fi kernel modules in `/etc/modprobe.d/99-cis-wireless.conf` (CIS 3.1.2)
- **`linux_sudo_hardening_ubuntu`**: Ubuntu counterpart of `linux_sudo_hardening_rhel9`: same CIS controls via `/etc/sudoers.d/99-cis-hardening` drop-in with `visudo` validation
- **`linux_cron_hardening_ubuntu`**: Ubuntu counterpart: uses `cron` service name; `cron.allow` group=`crontab` mode=`0640`; `at.allow` group=`daemon` mode=`0640` per Ubuntu package defaults
- **`linux_wireless_ubuntu`**: Ubuntu counterpart: `rfkill block wifi` as primary mechanism (no NetworkManager required), `nmcli` fallback if present, kernel module blacklist with `update-initramfs -u -k all` for persistence (CIS 3.1.2)
- **`cyberaar-baseline.sh` v4.1.0**: 5 new security checks (88 → 93 total)
  - `AUTH-15`: sudo `use_pty` enforcement (CIS 1.3.2)
  - `AUTH-16`: sudo logfile configuration (CIS 1.3.3)
  - `NET-12`: wireless interfaces disabled (rfkill + nmcli + modprobe blacklist)
  - `COMP-11`: cron service enabled and running (CIS 5.1.1)
  - `COMP-12`: `cron.allow` and `at.allow` allow-list model enforced (CIS 5.1.8–5.1.9)
- **Role documentation**: `docs/role-linux_sudo_hardening_ubuntu.md`, `docs/role-linux_cron_hardening_ubuntu.md`, `docs/role-linux_wireless_ubuntu.md`

### Changed

- `galaxy.yml`: version → 1.7.0; description updated to "47 roles (23 RHEL9, 24 Ubuntu/Debian)"; tags `sudo`, `cron`, `wireless` added
- `playbooks/2_configure_hardening.yml`: `linux_wireless_ubuntu`, `linux_sudo_hardening_ubuntu`, `linux_cron_hardening_ubuntu` added with tags `network,wireless` / `auth,sudo` / `cron`
- `src/lib/ansible_map.sh`: remediation mappings added for AUTH-15, AUTH-16, NET-12, COMP-11, COMP-12

---

## [1.6.1]: 2026-03-09

### Fixed

- **SECURITY** `cyberaar-baseline.sh`: remote temp filenames now use `openssl rand -hex 8` instead of predictable `$$` PID, eliminating symlink/race attack surface on remote hosts
- **SECURITY** `cyberaar-baseline.sh`: `chmod 600` applied to JSON and HTML output files after creation, reports contain full audit data and must not be world-readable
- **BUG** `cyberaar-baseline.sh`: `grep -c ... || echo 0` pattern produced `"0\n0"` (double-zero) when grep matched nothing, causing `[[ -eq ]]` syntax error on INT-03, LOG-04, COMP-03, COMP-04 checks, replaced with `|| true` + `${VAR:-0}` guard

### Changed

- Removed region-specific branding from script output (🇸🇳 flag emoji, French Senegal tagline); project scope is now worldwide, Senegal origin context preserved in README only
- Fixed stale version badge `v2.0.0` → `v4.0.0` in HTML report header and footer

---

## [1.6.0]: 2026-03-07

### Added

- **French translation of Linux hardening guide**: `translations/02-durcissement-serveur-linux.md`, full French version of the basic server hardening practice guide, adapted for Francophone West African public-sector context (Senegal DAF attack reference, UFW/firewalld/nftables, AppArmor/SELinux, LUKS)
- **`translations/README.md`**: guide index table and contribution instructions for French translations

### Changed

- **`cyberaar-baseline.sh` v4.0.0, `src/` multi-file architecture**: script split into `automation/scripts/src/` (14 source files across `lib/`, `checks/`, `renderers/`) assembled by `build.sh`; `add_result()` decoupled from JSON/HTML renderers via parallel result arrays (`RESULT_CATEGORY[]`, `RESULT_STATUS[]`, `RESULT_ID[]`, etc.)
- **JSON report version fixed**: baseline JSON output now correctly reports `"version": "4.0.0"` (was carrying forward `"3.0.0"`)
- **`automation/scripts/README.md`**: added "Contributing to the Script" section with `src/` layout diagram, `add_result()` architecture explanation, and edit → rebuild → test workflow
- **Root `README.md`**: collection version updated to v1.5.0, repo tree updated to show `build.sh` and `src/` subtree
- **`.gitignore`**: `CLAUDE.md` excluded from version control (local Claude Code instructions)

---

## [1.5.0]: 2026-03-06

### Added

- **Comprehensive RHEL9 role documentation**: all 21 RHEL9 role docs completely rewritten to match the Ubuntu doc format: Supported Platforms section, granular CIS benchmark references with section IDs, full variable tables with backtick-formatted names and accurate defaults, `group_vars`-style usage examples, and a "Differences from Ubuntu Counterpart" table for every role

### Changed

- `galaxy.yml`: version bumped to 1.5.0; description extended to cover Ubuntu/Debian alongside RHEL9; added tags `ubuntu`, `debian`, `apparmor`, `ufw`; fixed `documentation` URL to point to `docs/` directory
- `docs/role-linux_selinux_rhel9.md`: updated with `linux_selinux_relabel_enabled` variable, performance note, and default boolean table

---

## [1.4.0]: 2026-03-06

### Added

- **README rewrite**: full pipeline documentation: three-step baseline → harden → baseline diagram, all 42 roles in dual-OS table with CIS refs, full tag reference, inventory structure, variable precedence, sensitive variable lifecycle, report output structure
- **Ubuntu/Debian role documentation**: 21 new docs in `docs/` covering every Ubuntu role with Purpose, Supported Platforms, CIS Coverage, Variables, Usage Example, and Differences sections
- `docs/index.md` and `docs/roles-overview.md` updated for dual-OS scope

### Fixed

- **HIGH** `linux_auditing_rhel9`: YAML syntax error in `line:` value (single quotes inside single-quoted string); removed `ansible_default_ipv4.gateway` injected into `GRUB_CMDLINE_LINUX` (copy-paste artifact)
- **HIGH** `linux_auditing_rhel9`: `grub_audit_result.changed` referenced without `| default(false)`: UndefinedError when `linux_auditd_enable_boot_auditing` is false
- **HIGH** `linux_ctrl_alt_del_ubuntu`: replaced `ansible.builtin.command: "systemctl mask ..."` with `ansible.builtin.systemd: masked: true`: now idempotent and check-mode aware
- **HIGH** `linux_disable_unnecessary_services_ubuntu`: replaced `systemctl mask {{ item }}` command with `ansible.builtin.systemd: masked: true` loop
- **MEDIUM** `linux_login_banner_ubuntu`: replaced `find ... chmod a-x` command task with `ansible.builtin.file: mode: "a-x"` loop, idempotent, no more always-changed
- **MEDIUM** `linux_user_management_ubuntu`: replaced `useradd -D -f` command with `ansible.builtin.lineinfile` on `/etc/default/useradd`: idempotent
- **MEDIUM** `linux_core_dumps_ubuntu`: moved `Ensure coredump.conf.d directory exists` task before the template task, fixed ordering error that caused first-run failures
- **MEDIUM** `linux_user_management_rhel9`: narrowed empty-password lock condition from `'!'` to `'!!'`; fixed awk check; removed `remember =` from `pwquality.conf` (wrong file)
- **MEDIUM** `linux_aide_ubuntu`: fixed operator precedence `not aide_init.changed | default(false)` → `not (aide_init.changed | default(false))`
- **LOW** `linux_chrony_rhel9`: added `when: not ansible_check_mode` to `chronyc tracking` task
- **LOW** `linux_auditing_ubuntu`: removed spurious `ansible.builtin.meta: flush_handlers` task
- **LOW** `linux_crypto_policies_rhel9`: removed dead `Normalize subpolicies to dict list` task with broken Jinja2

### Changed

- `run-hardening.sh` moved to `automation/scripts/` directory
- WSL detection improved across multiple roles
- Inventory structure refactored for clearer group separation

---

## [1.3.0]: 2026-03-05

### Added

- **Unified three-step pipeline** (`0_execute_full_pipeline.yml`), single entry point that orchestrates baseline audit → hardening → post-hardening audit with automatic OS detection (`ansible_os_family`)
- **`cyberaar-baseline.sh` v3.0.0**: standalone bash audit script producing HTML and JSON security reports; integrated as steps 1 and 3 of the pipeline
- **Before/after baseline playbooks**: `1_execute_baseline_before.yml` and `3_execute_baseline_after.yml` copy the script to remote hosts, run it, and fetch HTML/JSON reports to `reports/before/<hostname>/` and `reports/after/<hostname>/`

### Fixed

- **HIGH** Multiple Ansible bugs resolved across existing RHEL9 roles (9 issues: undefined variable guards, check-mode guards, handler ordering, idempotency)
- **HIGH** WSL compatibility fixes, GRUB tasks guarded with WSL detection across `linux_auditing_ubuntu`, `linux_apparmor_ubuntu`, `linux_secure_boot_ubuntu`
- **MEDIUM** Inventory refactored, `ansible_host` derivation moved to `group_vars`; `index` variable aligned across all groups

---

## [1.2.0]: 2026-03-03

### Added

- **21 Ubuntu/Debian hardening roles**: complete CIS-aligned hardening library
  for Debian-family systems, mirroring the RHEL9 role structure:
  - `linux_ssh_hardening_ubuntu`: SSH server hardening (Protocol 2, key auth, CIS ciphers)
  - `linux_kernel_hardening_ubuntu`: sysctl hardening + module blacklisting
  - `linux_auditing_ubuntu`: auditd + 14-category audit rules + rsyslog forwarding
  - `linux_aide_ubuntu`: AIDE file integrity with template-based config
  - `linux_bootloader_password_ubuntu`: GRUB PBKDF2 password protection
  - `linux_firewall_ubuntu`: UFW hardening (replaces firewalld)
  - `linux_apparmor_ubuntu`: AppArmor enforce-all (replaces SELinux)
  - `linux_authselect_ubuntu`: PAM/pwquality/faillock hardening (replaces authselect)
  - `linux_unattended_upgrades_ubuntu`: Automatic security updates (replaces dnf-automatic)
  - `linux_chrony_ubuntu`: NTP hardening, disables systemd-timesyncd
  - `linux_login_banner_ubuntu`: Login banners, disables Ubuntu dynamic MOTD
  - `linux_crypto_policies_ubuntu`: OpenSSL + GnuTLS TLS hardening
  - `linux_disable_unnecessary_services_ubuntu`: Stop/mask 20+ unnecessary services
  - `linux_user_management_ubuntu`: System accounts, umask, inactive policy
  - `linux_fail2ban_ubuntu`: fail2ban with systemd backend
  - `linux_ip_forwarding_ubuntu`: IP forwarding sysctl with validation
  - `linux_ctrl_alt_del_ubuntu`: Mask ctrl-alt-del.target
  - `linux_core_dumps_ubuntu`: Core dump restriction (limits.d + sysctl + systemd)
  - `linux_tmp_mounts_ubuntu`: /tmp and /dev/shm mount hardening
  - `linux_secure_boot_ubuntu`: Secure Boot check + /boot permissions
  - `linux_file_permissions_ubuntu`: Critical file and directory permissions

### Fixed

- **HIGH** `linux_kernel_hardening_rhel9`: sysctl and modprobe template files
  moved from role root to `templates/` directory, fixes "template not found" on all runs
- **HIGH** `linux_auditing_rhel9`: `99-cis-audit.rules.j2` was empty, deployed
  a blank ruleset on every run, wiping all audit configuration
- **HIGH** `linux_auditing_rhel9`: GRUB cmdline `lineinfile` used
  `ansible_default_ipv4.gateway` instead of backreference, corrupting kernel params
- **MEDIUM** `linux_auditing_rhel9`: removed `audispd-plugins` package (merged
  into `audit` on RHEL9, caused dnf failure)

---

## [1.1.0]: 2026-03-01

### Added

- 10 new hardening roles for RHEL 9 family servers:
  - `linux_aide_rhel9`: File integrity monitoring (AIDE)
  - `linux_chrony_rhel9`: Secure NTP with Chrony
  - `linux_ssh_hardening_rhel9`: Deep SSH server hardening
  - `linux_tmp_mounts_rhel9`: noexec/nodev/nosuid on temp dirs
  - `linux_dnf_automatic_rhel9`: Automatic security updates
  - `linux_core_dumps_rhel9`: Restrict core dumps
  - `linux_ip_forwarding_rhel9`: Disable IP forwarding & redirects
  - `linux_login_banner_rhel9`: SSH & console banners (CyberAar branding)
  - `linux_ctrl_alt_del_rhel9`: Disable Ctrl+Alt+Del reboot
  - `linux_secure_boot_rhel9`: Enforce Secure Boot verification

- Per-role detailed documentation in `docs/` (purpose, CIS refs, vars, usage, testing, notes)
- Consistent formatting across all roles (double quotes, `when:` after `name:`, `---`/`...`)
- Updated root README with new structure, roles table, and quick-start
- LICENSE aligned to GPL-3.0 everywhere

### Changed

- Minor refinements in existing roles (banner templates with CyberAar branding in English)

### Security

- Enhanced protections: Secure Boot enforcement, core dump restrictions, IP forwarding disable

---

## [1.0.0]: 2026-02-26

### Added

- Initial release of CyberAar hardening collection for RHEL 9 family
- Main playbook: `configure_hardening_rhel9.yml`
- 11 RHEL9 hardening roles:
  - `linux_crypto_policies_rhel9`
  - `linux_authselect_rhel9`
  - `linux_kernel_hardening_rhel9` (sysctl + module blacklist)
  - `linux_auditing_rhel9` (with rsyslog forwarding)
  - `linux_firewalld_rhel9` (using `ansible.posix.firewalld`)
  - `linux_fail2ban_rhel9`
  - `linux_disable_unnecessary_services_rhel9`
  - `linux_file_permissions_rhel9`
  - `linux_selinux_rhel9` (using `ansible.posix.selinux`)
  - `linux_bootloader_password_rhel9` (secure password via env/vault)
  - `linux_user_management_rhel9`

### Security

- GRUB password uses PBKDF2 hash + environment variable / vault
- No hardcoded secrets in defaults
- `no_log` protection on sensitive tasks

### Notes

- Focused on CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0
- Designed for critical infrastructure servers (Senegal government context)
- Idempotent roles with granular enable/disable variables
