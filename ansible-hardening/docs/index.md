# CyberAar Hardening Documentation

Ansible-based hardening suite for **RHEL 9 family** (RHEL 9, AlmaLinux 9, Rocky Linux 9) **and Ubuntu/Debian** (Ubuntu 20.04/22.04/24.04, Debian 11/12), aligned with:
- **CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0** (RHEL9 roles)
- **CIS Ubuntu Linux 22.04 LTS Benchmark v1.0.0** (Ubuntu roles)

**Goal**
Help secure critical infrastructure — government, utilities, finance, telecom, healthcare — against common threats, with a focus on practicality, idempotence, and auditability.

## Quick Links

- [Installation & Setup](installation.md)
- [How to Use / Run the Playbook](usage.md)
- [All Roles Overview](roles-overview.md)
- [Security Baseline Checker](../../scripts/README.md)
- [Security Considerations & Testing Advice](security-considerations.md)
- [Contributing / Adding New Roles](contributing.md)
- [Changelog](../CHANGELOG.md)

## Current Roles (as of March 2026)

See [roles-overview.md](roles-overview.md) for full list and status.

Each control area has **two parallel roles** — one for RHEL9 family and one for Ubuntu/Debian.
Individual role pages are named `role-linux_<name>_rhel9.md` and `role-linux_<name>_ubuntu.md`.

## Supported Platforms

| Family | Distributions |
|---|---|
| RHEL 9 | RHEL 9, AlmaLinux 9, Rocky Linux 9 |
| Ubuntu/Debian | Ubuntu 20.04, 22.04, 24.04 — Debian 11, 12 |

OS detection is automatic — the correct role set is applied per host based on `ansible_os_family`.

## Philosophy

- **Idempotent** — safe to re-run many times; always-changed commands replaced with proper modules
- **Granular control** — enable/disable each role via `<role_name>_disabled=true`
- **Secure defaults** — no hardcoded secrets; sensitive variables read from environment
- **CIS-focused** — Level 1 + selected Level 2 controls for both OS families
- **Check-mode aware** — all roles work correctly with `--check --diff` (no false failures)
- **Critical infra ready** — SELinux/AppArmor enforcing, audit forwarding, bootloader password, etc.

## License

GPL-3.0 — open for reuse and contribution.

**CyberAar Team** — Hardening you can read, run and verify
