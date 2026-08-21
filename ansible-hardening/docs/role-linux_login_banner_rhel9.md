# Role: linux_login_banner_rhel9

## Purpose

Deploys legally compliant pre-login and post-login banners on RHEL 9 family systems:
- Deploys `/etc/issue` (local console pre-login banner)
- Deploys `/etc/issue.net` (SSH pre-login banner, referenced by `sshd_config Banner`)
- Deploys `/etc/motd` (post-login message of the day)
- Sets strict permissions (`0644 root:root`) on all banner files

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

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
| `linux_login_banner_enabled` | `true` | Enable banner deployment |
| `linux_login_banner_prelogin` | `true` | Deploy `/etc/issue.net` (SSH pre-login) |
| `linux_login_banner_postlogin` | `true` | Deploy `/etc/motd` (post-login message) |
| `linux_login_banner_issue` | `true` | Deploy `/etc/issue` (console/TTY pre-login) |
| `linux_login_banner_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Defaults deploy all three banners: no changes needed
linux_login_banner_prelogin: true
linux_login_banner_postlogin: true
linux_login_banner_issue: true
```

The banner text is defined in the role's Jinja2 template (`templates/banner.j2`) and includes a legal warning, hostname, and monitoring notice. To use a custom banner text, override the template in your own role overlay.

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Dynamic MOTD | Not present | `/etc/update-motd.d/` scripts (disabled by Ubuntu role) |
| Banner variables | `linux_login_banner_prelogin/postlogin/issue` | `linux_login_banner_org` + `linux_login_banner_text` |
| Custom text | Override Jinja2 template | `linux_login_banner_text` variable |
| File paths | `/etc/issue`, `/etc/issue.net`, `/etc/motd` | Same |

The Ubuntu counterpart (`linux_login_banner_ubuntu`) offers more variable-level customisation (`linux_login_banner_org`, `linux_login_banner_text`) and also disables Ubuntu-specific dynamic MOTD scripts that leak system information.
