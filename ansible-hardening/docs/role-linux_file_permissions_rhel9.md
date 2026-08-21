# Role: linux_file_permissions_rhel9

## Purpose

Enforces strict permissions and ownership on critical system files on RHEL 9 family systems, and sets a secure default umask:
- Sets owner, group, and mode on critical files (`/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/ssh/sshd_config`, `/boot/grub2/grub.cfg`, etc.)
- Sets a default umask of `027` via `/etc/profile.d/`
- Restricts `su` to the `wheel` group via `pam_wheel`
- Optionally scans for world-writable files in critical paths

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 5.4.2 Ensure system accounts are configured to use a non-login shell
- 5.6.5 Ensure default user shell timeout is configured
- 6.1.1 Ensure permissions on `/etc/passwd` are configured
- 6.1.2 Ensure permissions on `/etc/passwd-` are configured
- 6.1.3 Ensure permissions on `/etc/group` are configured
- 6.1.4 Ensure permissions on `/etc/group-` are configured
- 6.1.5 Ensure permissions on `/etc/shadow` are configured
- 6.1.6 Ensure permissions on `/etc/shadow-` are configured
- 6.1.7 Ensure permissions on `/etc/gshadow` are configured
- 6.1.8 Ensure permissions on `/etc/gshadow-` are configured
- 6.1.9 Ensure no world-writable files exist
- 6.2.3 Ensure default group for the root account is GID 0
- 6.2.6 Ensure root path integrity

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_umask_default` | `027` | Default umask applied via `/etc/profile.d/cis-umask.sh` |
| `linux_umask_apply_profile` | `true` | Write umask to `/etc/profile.d/` (affects all login shells) |
| `linux_critical_files` | See below | List of `{path, mode, owner, group}` for critical files |
| `linux_restrict_su_to_wheel` | `true` | Restrict `su` to `wheel` group via `pam_wheel` |
| `linux_remove_world_writable` | `false` | Scan for world-writable files (report only: does not auto-fix) |
| `linux_file_permissions_disabled` | `false` | Set `true` to skip this role entirely |

### Default `linux_critical_files`

| Path | Mode | Owner | Group |
|---|---|---|---|
| `/etc/passwd` | `0644` | `root` | `root` |
| `/etc/shadow` | `0000` | `root` | `root` |
| `/etc/group` | `0644` | `root` | `root` |
| `/etc/gshadow` | `0000` | `root` | `root` |
| `/etc/ssh/sshd_config` | `0600` | `root` | `root` |
| `/boot/grub2/grub.cfg` | `0600` | `root` | `root` |
| `/etc/security/opasswd` | `0600` | `root` | `root` |
| `/var/log/lastlog` | `0600` | `root` | `root` |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

linux_umask_default: "027"

# Add custom application config to enforce
linux_critical_files:
  - { path: "/etc/shadow",           mode: "0000", owner: "root", group: "root" }
  - { path: "/etc/myapp/secrets.conf", mode: "0640", owner: "root", group: "myapp" }

# Enable world-writable scan (report only: does not modify files)
linux_remove_world_writable: false
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| `/etc/shadow` mode | `0000` (root only) | `0640` (shadow group can read) |
| `/etc/gshadow` mode | `0000` | `0640` |
| `/etc/shadow` group | `root` | `shadow` |
| GRUB config path | `/boot/grub2/grub.cfg` | `/boot/grub/grub.cfg` |
| Variable structure | `linux_critical_files` list | `linux_file_permissions_auth_files` + `linux_file_permissions_system_files` lists |

The shadow group differs: Ubuntu/Debian uses a dedicated `shadow` group for PAM, while RHEL9 restricts shadow files to `root:root` with mode `0000`.
