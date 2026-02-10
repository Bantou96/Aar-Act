# Basic Server & Endpoint Hardening for Limited-Resource Environments

## Why This Matters in Senegal
Critical infrastructure often runs on outdated or minimally maintained Linux servers due to:
- Intermittent internet : Delayed patches.
- Limited budget/hardware : Can't afford commercial tools or frequent reboots.
- Common threats: Ransomware (example: recent DAF attack), phishing leading to initial access, brute-force on SSH.

**Goal:** Reduce attack surface - no heavy dependencies, works offline after initial setup.

**Target distros** (common in Senegal/public sector):
- Debian 11/12 or Ubuntu LTS (widely used, stable, free support community).
- Rocky Linux 8/9 or AlmaLinux (RHEL-compatible, enterprise-like stability).

**Test on a non-production VM first !**

## 1. System Update & Patch Management
- Patches known vulnerabilities - do this regularly, even offline.
**Debian/Ubuntu:**
```
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove --purge
sudo apt autoclean
```
**Rocky/Alma:**
```
sudo dnf update -y
sudo dnf autoremove
sudo dnf clean all
```
- **Low-connectivity tip:**

Use apt-offline (Debian/Ubuntu) or download RPMs on another machine / transfer via USB. Schedule via cron (weekly if connectivity allows):
```
# Example cron (edit /etc/crontab): @weekly root apt update && apt upgrade -y
```
- Enable automatic security updates (low risk on servers):

**Debian/Ubuntu:** Install `unattended-upgrades` and configure `/etc/apt/apt.conf.d/50unattended-upgrades`.

**Rocky:** Use `dnf-automatic`.

## 2. Disable Unnecessary Services (Reduce Attack Surface)
- List running services:
```
systemctl list-units --type=service
```
- Disable common risks (if not needed - check your workload first):
```
sudo systemctl disable --now avahi-daemon      # mDNS discovery
sudo systemctl disable --now cups              # Printing
sudo systemctl disable --now bluetooth
sudo systemctl mask rpcbind                    # RPC (often exploited/dangerous)
```
**For web servers:** Disable if unused - `apache2`/`httpd`, `nginx`.

## 3. Firewall Basics - Deny by Default, Allow Only Needed
Use the distro-default tool.
- Option A: UFW (Debian/Ubuntu default - very simple):
```
sudo apt install ufw   # if not present
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH          # or ssh (port 22)
# Add app-specific: sudo ufw allow 'Apache Full' or sudo ufw allow 80,443/tcp
sudo ufw enable
sudo ufw status verbose
```
- Option B: firewalld (Rocky/Alma default - more flexible with zones):
```
sudo dnf install firewalld   # if needed
sudo systemctl enable --now firewalld

# Default zone is usually 'public'
sudo firewall-cmd --permanent --zone=public --add-service=ssh
# For web server: --add-service=http --add-service=https
# Or ports: --add-port=8080/tcp

# Advanced: Create custom zone for internal trusted network (if multi-interface)
sudo firewall-cmd --permanent --new-zone=internal
sudo firewall-cmd --permanent --zone=internal --add-source=192.168.1.0/24
sudo firewall-cmd --permanent --zone=internal --add-service=ssh

sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```
**Tip:** 
For very limited resources, use `ufw` if on Debian family. `firewalld` uses more memory but handles dynamic changes better (no restart needed).

- Usage of nftables (modern replacement for iptables):
```
sudo nft add rule inet filter input tcp dport ssh accept
sudo nft add rule inet filter input drop
```

## 4. SSH Hardening (Common Attack Vector)
- Edit `/etc/ssh/sshd_config` (backup first):
```
PermitRootLogin no
PasswordAuthentication no          # Prefer keys
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
```
- Restart: `sudo systemctl restart sshd`
- Use key-based auth and disable password if possible (generate keys with `ssh-keygen -t ed25519`)
- Install Fail2Ban (lightweight brute-force blocker):
```
# Debian/Ubuntu: sudo apt install fail2ban
# Rocky: sudo dnf install fail2ban
sudo systemctl enable --now fail2ban
```

## 5. User & Access Controls
- Create non-root admin user for daily work.
- Enforce strong passwords: Edit `etc/security/pwquality.conf` (minlen=`12`, dcredit=`-1`, etc.).
- Lock unused accounts: `sudo passwd -l olduser`

## 6. Free Auditing & Monitoring Tools (Low Resource)
- **Lynis** (excellent auditing, offline after install): Run weekly and review suggestions.
```
# Debian/Ubuntu: sudo apt install lynis
# Rocky: sudo dnf install lynis
sudo lynis audit system
```
- **ClamAV** for basic malware scan (scan USBs/offline files).

## 7. Application Whitelisting / Execution Controls (Mandatory Access Control - MAC)
Prevent compromised processes from accessing unauthorized files/network even if running as root.

**Debian/Ubuntu (AppArmor - default, path-based, easier to manage):**
- Already enabled (check: `aa-status`)
- Enforce profiles:
```
sudo aa-enforce /etc/apparmor.d/*          # Enforce all default profiles
sudo aa-enforce /usr/sbin/apache2          # Example for Apache/Nginx
```
- Create custom profile :
Use `aa-genprof /path/to/binary` (interactive learning mode in complain first).
Edit `/etc/apparmor.d/usr.bin.yourapp` and add rules like:
```
/usr/bin/yourapp {
  #include <abstractions/base>
  /etc/yourapp/** r,
  /var/log/yourapp/** w,
  deny /etc/passwd r,   # Block sensitive access
  network inet stream,
}
```
- Reload: `sudo apparmor_parser -r /etc/apparmor.d/usr.bin.yourapp`
- Switch to enforce: `sudo aa-enforce /etc/apparmor.d/usr.bin.yourapp`

**Rocky/AlmaLinux (SELinux - default, label-based):**
- Enabled by default in enforcing mode (check: `getenforce` or `sestatus`).
- Switch/confirm enforcing:
```
sudo setenforce 1                          # Temporary
# Permanent: Edit /etc/selinux/config > SELINUX=enforcing
reboot
```
- Restore contexts if issues: `sudo restorecon -Rv /var/www`
- Check denials: `sudo ausearch -m avc -ts recent`
- Create custom policy (advanced): use `audit2allow` for modules from logs.
- For Apache/Nginx/Postfix, enable booleans if needed:
```
sudo setsebool -P httpd_can_network_connect 1
```

**Recommendation for Senegal:** 
Use distro default (AppArmor on Debian family for simplicity; SELinux on Rocky for stricter control). Start in permissive mode if testing, then enforce.

## 8. Disk Encryption (Protect Data at Rest)
Critical for physical theft/loss or forensic recovery after breach. Use LUKS (built-in, standardized, low overhead with AES-NI).

**Why in Senegal:** Protects sensitive data (citizen records, financials) if hardware stolen/lost. Minimal perf hit on modern CPUs.
Setup during install (recommended): Most installers (Debian/Rocky) offer LUKS + LVM option—encrypt root + data partitions.

**Manual / Existing System (Advanced - Backup First):**
- For new partition (/dev/sdb1 example):
```
sudo cryptsetup luksFormat /dev/sdb1          # Set strong passphrase
sudo cryptsetup luksOpen /dev/sdb1 encrypted_disk
sudo mkfs.ext4 /dev/mapper/encrypted_disk
sudo mount /dev/mapper/encrypted_disk /mnt
```
- Auto-unlock at boot: Add to `/etc/crypttab` and update initramfs (`update-initramfs -u` on Debian; `dracut -f` on Rocky).
- Best practices:
Strong passphrase (20+ chars) or keyfile (stored securely/USB).

Backup LUKS header: `cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file header.backup`

For swap: Encrypt or use encrypted swapfile to avoid leaks.

Test recovery: Reboot & unlock manually.

**Low-resource note:**
LUKS overhead is ~5-10% I/O on SSDs; negligible on modern hardware. Avoid on very old/slow disks if perf critical.

## References
- AppArmor: https://wiki.ubuntu.com/AppArmor (Debian/Ubuntu guide)
- SELinux: https://docs.rockylinux.org/guides/security/learning_selinux/
- LUKS/cryptsetup: https://wiki.debian.org/cryptsetup or man cryptsetup
- CIS Benchmarks (free PDFs): Debian / Rocky Linux
