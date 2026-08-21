# Role: linux_chrony_ubuntu

## Purpose

Installs and configures Chrony as the NTP time synchronisation daemon on Ubuntu/Debian systems:
- Installs the `chrony` package
- Deploys a CIS-aligned `chrony.conf` (NTP servers, access restrictions, step threshold)
- Enables and starts the `chrony` service
- Verifies synchronisation status with `chronyc tracking` (skipped in check mode)

## Supported Platforms

- Ubuntu 20.04 LTS (Focal)
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11 (Bullseye) / Debian 12 (Bookworm)

## CIS Coverage

- 2.1.1 Ensure time synchronisation is in use
- 2.1.2 Ensure chrony is configured with authorised timeserver
- 2.1.3 Ensure chrony is not run as root

## Variables

| Variable | Default | Description |
|---|---|---|
| `linux_chrony_servers` | `[0–3.pool.ntp.org]` | NTP server list — replace with government/regional servers for production |
| `linux_chrony_server_options` | `iburst` | Options appended to each NTP server line (`iburst` = fast initial sync) |
| `linux_chrony_allow_networks` | `[]` | Networks allowed to use this host as an NTP server (empty = client only) |
| `linux_chrony_makestep` | `1.0 3` | Step threshold — allow step adjustments of up to 1s during the first 3 updates |
| `linux_chrony_hwtimestamp` | `false` | Enable hardware timestamping if NIC supports it |
| `linux_chrony_disabled` | `false` | Set `true` to skip this role entirely |

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml

# Prefer a national or regional NTP source, then a pool as fallback.
# Replace the zone with the one closest to your estate.
linux_chrony_servers:
  - "ntp.example.org"
  - "0.pool.ntp.org"
  - "1.pool.ntp.org"

# If this host is an internal NTP server for your LAN
linux_chrony_allow_networks:
  - "10.0.0.0/8"
  - "192.168.1.0/24"
```

## Differences from RHEL9 Counterpart

| Aspect | Ubuntu/Debian | RHEL9 |
|---|---|---|
| Package name | `chrony` | `chrony` (same) |
| Service name | `chrony` | `chronyd` |
| Config file | `/etc/chrony/chrony.conf` | `/etc/chrony.conf` |
| Variables | Identical | Identical |

Note: The Ubuntu service is named `chrony` (not `chronyd`). The handler in this role uses the correct service name.
