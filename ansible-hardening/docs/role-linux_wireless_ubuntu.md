# Role: linux_wireless_ubuntu

## Purpose

Disables all wireless network interfaces and blacklists wireless kernel modules on Ubuntu/Debian servers to meet CIS benchmark requirements. This ensures servers cannot communicate over wireless networks, reducing the attack surface on infrastructure that should only use wired interfaces.

Three complementary approaches are applied:
1. **rfkill**: blocks wireless radios at the OS level (preferred on Ubuntu: available without NetworkManager)
2. **nmcli**: disables wireless via NetworkManager if present (fallback / defense-in-depth)
3. **Kernel module blacklisting**: prevents wireless modules from loading at the kernel level, with `update-initramfs` for full persistence

## Supported Platforms

| Platform | Versions |
|----------|----------|
| Ubuntu   | 20.04 LTS, 22.04 LTS, 24.04 LTS |
| Debian   | 11 (Bullseye), 12 (Bookworm) |

## CIS Coverage

- 3.1.2 Ensure wireless interfaces are disabled (L1)

## Variables

| Variable                          | Default | Description                                                          |
|-----------------------------------|---------|----------------------------------------------------------------------|
| `linux_wireless_disable`          | `true`  | Block wireless via `rfkill block wifi` and nmcli fallback            |
| `linux_wireless_block_bluetooth`  | `true`  | Block Bluetooth via `rfkill block bluetooth`                         |
| `linux_wireless_blacklist_modules`| `true`  | Blacklist iwlwifi, cfg80211, mac80211, rtl8xxxu, ath9k in modprobe   |
| `linux_wireless_disabled`         | `false` | Set to `true` to skip entire role                                    |

### Blacklisted modules (when `linux_wireless_blacklist_modules: true`)

Written to `/etc/modprobe.d/99-cis-wireless.conf`:

- `iwlwifi`: Intel wireless
- `cfg80211`: Linux wireless configuration API
- `mac80211`: Linux 802.11 MAC framework
- `rtl8xxxu`: Realtek USB wireless
- `ath9k`: Atheros wireless

## Usage Example

```yaml
# group_vars/ubuntu_servers.yml
linux_wireless_disable: true
linux_wireless_block_bluetooth: true
linux_wireless_blacklist_modules: true
```

```yaml
# Run only wireless hardening
bash scripts/run-hardening.sh -u ubuntu -t ubuntu-vm-01 -T wireless
```

## Testing

```bash
# Verify rfkill state
rfkill list wifi
rfkill list bluetooth

# Verify nmcli state (if NetworkManager present)
nmcli radio all

# Verify kernel module blacklist is in place
cat /etc/modprobe.d/99-cis-wireless.conf

# Confirm wireless modules are not loaded
lsmod | grep -E 'iwlwifi|cfg80211|mac80211'
```

## Notes

- `rfkill` is the primary mechanism on Ubuntu servers, it does not require NetworkManager. The role installs `rfkill` via apt if not present.
- The nmcli task runs only if `nmcli` is found in `$PATH`, and is skipped gracefully on minimal installs.
- A `reboot` is required for the module blacklist to take full effect if modules are currently loaded. The role calls `update-initramfs -u -k all` automatically when the blacklist file changes.
- This role is intended for server systems. Do not apply to workstations, laptops, or systems that legitimately require wireless connectivity.
- To re-enable wireless on a specific host, set `linux_wireless_disabled: true` in `host_vars/<hostname>.yml`.

## Differences from RHEL9 Counterpart

| Aspect | RHEL9 (`linux_wireless_rhel9`) | Ubuntu (`linux_wireless_ubuntu`) |
|--------|--------------------------------|----------------------------------|
| Primary mechanism | `nmcli radio all off` | `rfkill block wifi` (no NetworkManager required) |
| Bluetooth blocking | Not included | `rfkill block bluetooth` (optional via `linux_wireless_block_bluetooth`) |
| nmcli | Required (assumed present) | Optional fallback (detected via `which nmcli`) |
| initramfs update | Not applicable | `update-initramfs -u -k all` when blacklist changes |
| Blacklisted modules | iwlwifi, cfg80211, mac80211, rtl8xxxu, rtw88, brcmfmac | iwlwifi, cfg80211, mac80211, rtl8xxxu, ath9k |

The Ubuntu role uses `rfkill` as primary because Ubuntu servers frequently use `netplan`/`systemd-networkd` without NetworkManager. The RHEL9 role relies on `nmcli` (NetworkManager is standard on RHEL9).
