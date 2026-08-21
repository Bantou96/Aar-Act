# Role: linux_apparmor_ubuntu

## Purpose

Enables and enforces AppArmor Mandatory Access Control on Ubuntu/Debian systems:
- Ensures AppArmor is installed and the service is active
- Transitions all complain-mode profiles to enforce mode (or a curated list)
- Supports local profile overrides for custom application policies
- Ubuntu/Debian equivalent of SELinux enforcement on RHEL9

> **Container hosts.** The container runtime ships and manages its own AppArmor
> profiles. See [Running on a Container Host](container-hosts.md).

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 1.6.1 Ensure AppArmor is installed
- 1.6.2 Ensure AppArmor is enabled in the bootloader configuration
- 1.6.3 Ensure all AppArmor profiles are in enforce or complain mode
- 1.6.4 Ensure all AppArmor profiles are enforcing

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_apparmor_enforce_all` | `true` | Enforce all profiles currently in complain mode |
| `linux_apparmor_enforce_profiles` | `[]` | Specific profiles to enforce when `enforce_all` is false |
| `linux_apparmor_local_overrides` | `[]` | List of `{profile, content}` dicts for local profile customisation |
| `linux_apparmor_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# Enforce all profiles (recommended)
linux_apparmor_enforce_all: true

# Enforce only specific profiles
linux_apparmor_enforce_all: false
linux_apparmor_enforce_profiles:
  - "/etc/apparmor.d/usr.sbin.sshd"
  - "/etc/apparmor.d/usr.sbin.nginx"

# Add a local override for a custom application
linux_apparmor_local_overrides:
  - profile: "usr.sbin.sshd"
    content: |
      # Allow reading custom key directory
      /opt/keys/ r,
```

## RHEL9 Counterpart

| Ubuntu/Debian | RHEL9 |
|---|---|
| `linux_apparmor_ubuntu` | `linux_selinux_rhel9` |
| AppArmor profiles (enforce/complain) | SELinux enforcing/permissive modes |
| `/etc/apparmor.d/` | `/etc/selinux/config` |
| `aa-enforce` / `aa-complain` | `setenforce`, `semanage` |

See [`role-linux_selinux_rhel9.md`](role-linux_selinux_rhel9.md) for the RHEL9 equivalent.
