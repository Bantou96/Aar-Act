# Role: linux_cron_hardening_rhel9

## Purpose

Hardens the cron and at scheduling subsystems on RHEL9 to meet CIS benchmark requirements:
- Ensures crond is enabled and running
- Applies strict permissions (root-only) on all cron directories and files
- Removes cron.deny and at.deny (deny-list model is insecure by default)
- Creates cron.allow and at.allow (allow-list model, only root by default)

## CIS Coverage

- 5.1.1 Ensure cron daemon is enabled and running (L1)
- 5.1.2 Ensure permissions on /etc/crontab are configured (L1)
- 5.1.3 Ensure permissions on /etc/cron.hourly are configured (L1)
- 5.1.4 Ensure permissions on /etc/cron.daily are configured (L1)
- 5.1.5 Ensure permissions on /etc/cron.weekly are configured (L1)
- 5.1.6 Ensure permissions on /etc/cron.monthly are configured (L1)
- 5.1.7 Ensure permissions on /etc/cron.d are configured (L1)
- 5.1.8 Ensure cron is restricted to authorized users (L1)
- 5.1.9 Ensure at is restricted to authorized users (L1)

## Variables

| Variable                       | Default | Description                                                     |
|--------------------------------|---------|-----------------------------------------------------------------|
| linux_cron_enabled             | true    | Ensure crond is enabled and running                             |
| linux_cron_paths               | (list)  | List of cron paths with mode and is_dir flag (see defaults)     |
| linux_cron_allow_enabled       | true    | Create /etc/cron.allow (root-only) and remove /etc/cron.deny   |
| linux_at_allow_enabled         | true    | Create /etc/at.allow (root-only) and remove /etc/at.deny       |
| linux_cron_hardening_disabled  | false   | Set to true to skip entire role                                 |

### Default `linux_cron_paths`

```yaml
linux_cron_paths:
  - { path: "/etc/crontab",     mode: "0600", is_dir: false }
  - { path: "/etc/cron.hourly", mode: "0700", is_dir: true  }
  - { path: "/etc/cron.daily",  mode: "0700", is_dir: true  }
  - { path: "/etc/cron.weekly", mode: "0700", is_dir: true  }
  - { path: "/etc/cron.monthly",mode: "0700", is_dir: true  }
  - { path: "/etc/cron.d",      mode: "0700", is_dir: true  }
```

## Usage Example

```yaml
- role: linux_cron_hardening_rhel9
  vars:
    linux_cron_allow_enabled: true
    linux_at_allow_enabled: true
```

## Testing

```bash
# Verify crond is enabled and active
systemctl is-enabled crond && systemctl is-active crond

# Verify permissions on cron files
stat -c "%a %U %G %n" /etc/crontab /etc/cron.hourly /etc/cron.daily \
  /etc/cron.weekly /etc/cron.monthly /etc/cron.d

# Verify allow-list model
ls -la /etc/cron.allow /etc/at.allow
ls /etc/cron.deny /etc/at.deny 2>&1  # should report: No such file or directory
```

## Notes

- Removing cron.deny is intentional and recommended by CIS. An empty deny file still allows access for non-listed users; an allow file restricts access to listed users only.
- cron.allow and at.allow are created empty (root-only access); add additional users as needed for your environment.
- The role is idempotent, running it multiple times produces the same result.