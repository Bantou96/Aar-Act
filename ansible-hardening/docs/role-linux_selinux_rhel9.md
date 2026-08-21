# Role: linux_selinux_rhel9

## Purpose

Ensures SELinux is in enforcing mode with the targeted policy, sets hardening booleans, and optionally restores file contexts on critical paths:
- Configures SELinux mode and policy via `ansible.posix.selinux`
- Sets security booleans (`deny_ptrace`, `ssh_sysadm_login`, `httpd_can_network_connect`, etc.)
- Optionally runs `restorecon -R` on critical paths to fix corrupted file contexts
- Optionally touches `/.autorelabel` to trigger a full filesystem relabel on next boot

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 1.6.1 Ensure SELinux is installed and enabled in the bootloader configuration
- 1.6.1.1 Ensure SELinux is not disabled in the bootloader
- 1.6.1.2 Ensure SELinux state is enforcing or permissive
- 1.6.1.3 Ensure SELinux policy is configured
- 1.6.1.4 Ensure the SELinux mode is not disabled
- 1.6.1.5 Ensure no unconfined services exist

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_selinux_mode` | `enforcing` | SELinux mode: `enforcing` / `permissive` / `disabled` |
| `linux_selinux_policy` | `targeted` | SELinux policy: `targeted` (default) or `mls` |
| `linux_selinux_booleans` | See below | List of `{name, state}` booleans to set persistently |
| `linux_selinux_relabel_paths` | `[/etc, /boot, /var/log, /home, /root]` | Paths passed to `restorecon -R` when enabled |
| `linux_selinux_relabel_enabled` | **`false`** | Run `restorecon -R` on relabel paths (slow: opt-in) |
| `linux_selinux_force_autorelabel` | `false` | Touch `/.autorelabel` to trigger full relabel on next boot |
| `linux_selinux_disabled` | `false` | Set `true` to skip this role entirely |

> **Performance note:** `restorecon -R` on paths like `/etc`, `/home`, `/var/log` scans every inode and can take several minutes on a loaded system. It is disabled by default (`linux_selinux_relabel_enabled: false`). Enable it only when file contexts are known to be corrupted, for example after a manual file migration or OS upgrade.

### Default `linux_selinux_booleans`

| Boolean | Default state | Purpose |
|---|---|---|
| `deny_ptrace` | `on` | Restrict ptrace (debugging): defense-in-depth |
| `ssh_sysadm_login` | `off` | Prevent SSH logins as `sysadm_u` (admin role) |
| `httpd_can_network_connect` | `off` | Disable if no web server needs outbound connections |
| `httpd_can_sendmail` | `off` | Disable unless web app sends mail |
| `use_nfs_home_dirs` | `off` | Disable if no NFS-mounted home directories |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_selinux_mode: "enforcing"
linux_selinux_policy: "targeted"

# Enable restorecon only when migrating files or recovering from context corruption
linux_selinux_relabel_enabled: false

# Add custom booleans for a web server
linux_selinux_booleans:
  - { name: "deny_ptrace",               state: "on" }
  - { name: "ssh_sysadm_login",          state: "off" }
  - { name: "httpd_can_network_connect", state: "on" }   # web app needs outbound
```

## Differences from Ubuntu Counterpart

SELinux is RHEL-specific. The Ubuntu/Debian equivalent is AppArmor, managed by the `linux_apparmor_ubuntu` role.

| Aspect | RHEL9 (SELinux) | Ubuntu/Debian (AppArmor) |
|---|---|---|
| Role name | `linux_selinux_rhel9` | `linux_apparmor_ubuntu` |
| MAC framework | SELinux (type enforcement, MLS) | AppArmor (path-based profiles) |
| Policy model | `targeted` / `mls` | Profile-based (`enforce` / `complain`) |
| Module | `ansible.posix.selinux`, `ansible.posix.seboolean` | `ansible.builtin.service`, `aa-enforce` |
| Context relabeling | `restorecon -R` | Not applicable |
| Boolean tuning | `ansible.posix.seboolean` | Profile overrides in `/etc/apparmor.d/local/` |
