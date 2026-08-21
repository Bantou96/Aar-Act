# Role: linux_disable_unnecessary_services_rhel9

## Purpose

Reduces the attack surface on RHEL 9 family systems by stopping, disabling, and masking services that are installed by default but rarely needed on production servers:
- Gathers package and service facts to safely skip non-installed services
- Masks high-risk services (`avahi-daemon`, `cups`, `bluetooth`, `ModemManager`, `nfs-server`, `rpcbind`, `postfix`)
- Disables but does not mask less critical services (`atd`, `NetworkManager-wait-online`, `lpd`)
- Optionally removes the corresponding packages entirely
- Respects an exception list (`chronyd`, `sshd`) that is never touched

## Supported Platforms

- RHEL 9.x (Red Hat Enterprise Linux)
- AlmaLinux 9.x
- Rocky Linux 9.x

## CIS Coverage

- 2.1.1 Ensure autofs services are not in use
- 2.1.2 Ensure avahi daemon services are not in use
- 2.1.3 Ensure dhcp server services are not in use
- 2.1.4 Ensure dns server services are not in use
- 2.1.5 Ensure dnsmasq services are not in use
- 2.1.6 Ensure samba file server services are not in use
- 2.1.7 Ensure ftp server services are not in use
- 2.1.8 Ensure message access server services are not in use
- 2.1.9 Ensure network file system services are not in use
- 2.1.10 Ensure nis server services are not in use
- 2.1.11 Ensure print server services are not in use
- 2.1.12 Ensure rpcbind services are not in use
- 2.1.13 Ensure rsync services are not in use

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_services_to_mask` | `[avahi-daemon, cups, cups-browsed, bluetooth, ModemManager, nfs-server, rpcbind, postfix]` | Services to mask (strongest suppression: cannot be started by any user) |
| `linux_services_to_disable` | `[NetworkManager-wait-online, atd, lpd]` | Services to stop and disable but not mask |
| `linux_services_exceptions` | `[chronyd, sshd]` | Services never touched regardless of the lists above |
| `linux_packages_to_remove.enabled` | `false` | Set `true` to also remove the packages (irreversible: use with care) |
| `linux_packages_to_remove.list` | `[avahi, cups, cups-client, cups-libs, ModemManager, bluetooth]` | Packages to purge when removal is enabled |
| `linux_unnecessary_services_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/rhel_servers.yml

# Add postfix to exceptions if the server is used as a mail relay
linux_services_exceptions:
  - "chronyd"
  - "sshd"
  - "postfix"

# Remove packages on hardened servers where reinstallation is audited
linux_packages_to_remove:
  enabled: true
  list:
    - "avahi"
    - "cups"
    - "bluetooth"
```

## Differences from Ubuntu Counterpart

| Aspect | RHEL9 | Ubuntu/Debian |
|---|---|---|
| Default masked services | Same set (avahi, cups, bluetooth, ModemManager, nfs-server, rpcbind, postfix) | Same set |
| Masking mechanism | `ansible.builtin.systemd: masked: true` | `ansible.builtin.systemd: masked: true` |
| Package removal | `dnf` | `apt` |
| Variables | Identical structure | Identical structure |
