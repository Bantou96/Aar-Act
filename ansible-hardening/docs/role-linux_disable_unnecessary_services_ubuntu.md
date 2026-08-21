# Role: linux_disable_unnecessary_services_ubuntu

## Purpose

Stops, disables, and optionally masks unnecessary or high-risk network services on Ubuntu/Debian systems:
- Iterates over a configurable list of services and stops/disables each one
- Masks critical legacy services (`telnet`, `rsh`, `rlogin`, `rexec`) via systemd so they cannot be re-enabled without explicit unmasking
- Optionally removes the corresponding packages

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 2.2.1 Ensure X11 server components are not installed
- 2.2.2 Ensure Avahi daemon is not installed
- 2.2.4 Ensure CUPS is not installed
- 2.2.5 Ensure DHCP server is not installed
- 2.2.6 Ensure LDAP server is not installed
- 2.2.7 Ensure NFS is not installed
- 2.2.8 Ensure RPC is not installed
- 2.2.9 Ensure DNS server is not installed
- 2.2.10 Ensure FTP server is not installed
- 2.2.11 Ensure HTTP server is not installed
- 2.2.12 Ensure IMAP and POP3 server is not installed
- 2.2.13 Ensure Samba is not installed
- 2.2.14 Ensure HTTP Proxy server is not installed
- 2.2.15 Ensure SNMP server is not installed
- 2.2.16 Ensure rsync daemon is not in use
- 2.2.17 Ensure NIS server is not installed

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_disable_services_list` | See below | List of `{name, condition}` dicts: services to stop and disable |
| `linux_disable_services_mask` | `true` | Also mask the services in `linux_disable_services_masked` |
| `linux_disable_services_masked` | `[telnet.socket, rsh.socket, rlogin.socket, rexec.socket]` | Services to mask permanently via systemd |
| `linux_disable_services_remove_packages` | `false` | Remove packages of disabled services |
| `linux_disable_services_packages_to_remove` | `[telnet, nis, talk, talkd, rsh-client]` | Packages to remove when `remove_packages` is true |
| `linux_disable_services_disabled` | `false` | Set `true` to skip this role entirely |

### Default service list

| Service | CIS Ref | Default condition |
|---|---|---|
| `avahi-daemon` | 2.2.2 | enabled (disabled by role) |
| `cups` / `cups-browsed` | 2.2.4 | enabled |
| `isc-dhcp-server` | 2.2.5 | `false` (skip: set true to disable) |
| `slapd` | 2.2.6 | enabled |
| `nfs-server` | 2.2.7 | enabled |
| `rpcbind` | 2.2.8 | enabled |
| `bind9` | 2.2.9 | `false` (skip: set true to disable) |
| `vsftpd` | 2.2.10 | enabled |
| `apache2` | 2.2.11 | `false` (skip: set true to disable) |
| `dovecot` | 2.2.12 | enabled |
| `samba` | 2.2.13 | enabled |
| `squid` | 2.2.14 | enabled |
| `snmpd` | 2.2.15 | enabled |
| `rsync` | 2.2.16 | `false` (skip: set true to disable) |
| `nis` | 2.2.17 | enabled |
| `telnet` | 2.2.19 | enabled |

Services with `condition: false` default to skipping, set `condition: true` in your override to disable them.

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml

# Keep apache2 but disable bind9 (DNS server not needed)
linux_disable_services_list:
  - name: "avahi-daemon"
  - name: "cups"
  - name: "bind9"
    condition: true     # override: disable it
  - name: "apache2"
    condition: false    # keep apache2 running

# Remove legacy packages entirely
linux_disable_services_remove_packages: true
```

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| Service names | Ubuntu names (e.g. `apache2`, `bind9`, `isc-dhcp-server`) | RHEL names (e.g. `httpd`, `named`, `dhcpd`) |
| Masking | `ansible.builtin.systemd: masked: true` | `ansible.builtin.systemd: masked: true` (same) |
| Package manager | `apt` / `dpkg` | `dnf` / `rpm` |
| Variables | Structurally identical | Structurally identical |
