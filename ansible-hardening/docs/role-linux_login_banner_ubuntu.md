# Role: linux_login_banner_ubuntu

## Purpose

Deploys legally compliant pre-login and post-login banners on Ubuntu/Debian systems:
- Deploys `/etc/issue` (local console pre-login banner)
- Deploys `/etc/issue.net` (SSH pre-login banner — referenced by `sshd_config Banner`)
- Deploys `/etc/motd` (post-login message of the day)
- Optionally disables Ubuntu's dynamic MOTD scripts (ESM notices, ads, livepatch status) which can expose system information

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.7.1 Ensure message of the day is configured properly
- 1.7.2 Ensure local login warning banner is configured (`/etc/issue`)
- 1.7.3 Ensure remote login warning banner is configured (`/etc/issue.net`)
- 1.7.4 Ensure permissions on `/etc/motd` are configured
- 1.7.5 Ensure permissions on `/etc/issue` are configured
- 1.7.6 Ensure permissions on `/etc/issue.net` are configured

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_login_banner_org` | `CyberAar` | Organisation name shown in the banner |
| `linux_login_banner_text` | `""` | Custom banner text (overrides the default template if set) |
| `linux_login_banner_disable_dynamic_motd` | `true` | Remove executable bit from `/etc/update-motd.d/` scripts |
| `linux_login_banner_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_login_banner_org: "Example Organisation"

# Custom banner overriding the template
linux_login_banner_text: |
  ******************************************************************************
  *  SYSTEME INFORMATIQUE AUTORISE UNIQUEMENT                                  *
  *  Tout accès non autorisé est interdit et punissable par la loi.            *
  *  Example Organisation — IT Operations                                     *
  ******************************************************************************
```

## Ubuntu-Specific: Dynamic MOTD

Ubuntu installs several scripts under `/etc/update-motd.d/` that run on login and display system information (ESM ads, Livepatch status, etc.). These can leak system details and should be disabled on hardened servers:

```
/etc/update-motd.d/10-help-text
/etc/update-motd.d/50-motd-news
/etc/update-motd.d/80-esm
/etc/update-motd.d/80-livepatch
/etc/update-motd.d/91-contract-ua-esm-status
```

When `linux_login_banner_disable_dynamic_motd: true`, the role removes the executable bit from these scripts using `ansible.builtin.file: mode: "a-x"` (idempotent).

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| Dynamic MOTD | `update-motd.d/` scripts (disabled by this role) | Not present |
| Banner variables | Identical | Identical |
| File paths | Same (`/etc/issue`, `/etc/issue.net`, `/etc/motd`) | Same |
