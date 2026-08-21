# Role: linux_wireless_rhel9

## Purpose

Disables all wireless network interfaces and blacklists wireless kernel modules on RHEL9 servers to meet CIS benchmark requirements. This ensures servers cannot communicate over wireless networks, reducing the attack surface on infrastructure that should only use wired interfaces.

Two complementary approaches are applied:
1. **nmcli**: disables all wireless radios at the NetworkManager level (if nmcli is available)
2. **Kernel module blacklisting**: prevents wireless modules from loading at the kernel level (defense-in-depth)

## CIS Coverage

- 3.1.2 Ensure wireless interfaces are disabled (L1)

## Variables

| Variable                          | Default | Description                                                       |
|-----------------------------------|---------|-------------------------------------------------------------------|
| linux_wireless_disable            | true    | Disable wireless via nmcli (`nmcli radio all off`)                |
| linux_wireless_blacklist_modules  | true    | Blacklist iwlwifi, cfg80211, mac80211, rtl8xxxu, rtw88, brcmfmac  |
| linux_wireless_disabled           | false   | Set to true to skip entire role                                   |

### Blacklisted modules (when `linux_wireless_blacklist_modules: true`)

- `iwlwifi`: Intel wireless
- `cfg80211`: Linux wireless configuration API
- `mac80211`: Linux 802.11 MAC framework
- `rtl8xxxu`: Realtek USB wireless
- `rtw88`: Realtek PCIe wireless
- `brcmfmac`: Broadcom FMAC wireless

Written to `/etc/modprobe.d/99-cis-wireless.conf`.

## Usage Example

```yaml
- role: linux_wireless_rhel9
  vars:
    linux_wireless_disable: true
    linux_wireless_blacklist_modules: true
```

## Testing

```bash
# Verify wireless radio state via nmcli
nmcli radio all

# Verify kernel module blacklist is in place
cat /etc/modprobe.d/99-cis-wireless.conf

# Confirm wireless modules are not loaded
lsmod | grep -E 'iwlwifi|cfg80211|mac80211'
```

## Notes

- The nmcli task is skipped gracefully if nmcli is not installed (e.g. minimal installs without NetworkManager).
- Module blacklisting persists across reboots via `/etc/modprobe.d/`. A reboot is required for the blacklist to take full effect if modules are currently loaded.
- This role is intended for server systems. Do not apply to workstations or systems that legitimately require wireless connectivity.