# Roles Overview

| Role                                      | Main Purpose                                      | CIS Sections          | Status     | Tags                     |
|-------------------------------------------|---------------------------------------------------|-----------------------|------------|--------------------------|
| linux_crypto_policies_rhel9               | Strong system-wide crypto (FUTURE + disable SHA1) | 1.13                  | Stable     | crypto, tls              |
| linux_authselect_rhel9                    | PAM, pwquality, faillock, authselect profile      | 5.3, 5.4              | Stable     | auth, pam                |
| linux_kernel_hardening_rhel9              | Sysctl hardening + module blacklisting            | 1.5, 3.3              | Stable     | kernel, sysctl           |
| linux_auditing_rhel9                      | auditd rules + rsyslog forwarding                 | 6.3                   | Stable     | audit, logging           |
| linux_firewalld_rhel9                     | firewalld default drop + SSH restrictions         | 4.2                   | Stable     | firewall                 |
| linux_fail2ban_rhel9                      | Brute-force protection (sshd + firewalld synergy) |:                     | Stable     | fail2ban                 |
| linux_disable_unnecessary_services_rhel9  | Mask/disable legacy services                      | 2.x                   | Stable     | services                 |
| linux_file_permissions_rhel9              | Strict perms on shadow, ssh keys, umask 027       | 5.4, 6.1              | Stable     | permissions              |
| linux_selinux_rhel9                       | Enforcing mode + booleans + restorecon            | 1.6                   | Stable     | selinux                  |
| linux_bootloader_password_rhel9           | GRUB2 PBKDF2 password protection                  | 1.4                   | Stable     | bootloader               |
| linux_user_management_rhel9               | Root lock, legacy users, password policy + 6.2.x audits | 5.2–5.5, 6.2          | Stable     | users                    |
| linux_sudo_hardening_rhel9                | sudo use_pty + logfile enforcement                | 1.3.1–1.3.3           | Stable     | auth, sudo               |
| linux_cron_hardening_rhel9                | crond + strict cron perms + cron.allow/at.allow   | 5.1.1–5.1.9           | Stable     | cron                     |
| linux_wireless_rhel9                      | Disable wireless interfaces + blacklist modules   | 3.1.2                 | Stable     | network, wireless        |

> **Extended in v1.3.0**
> `linux_bootloader_password_rhel9`: added single user mode auth (CIS 1.5.3)
> `linux_tmp_mounts_rhel9`: added /home nodev (CIS 1.1.14) + sticky bit (CIS 1.1.21)
> `linux_disable_unnecessary_services_rhel9`: expanded service/package lists (CIS 2.x)

**Legend**  
- **Stable**: production ready, well tested  
- **Beta**: functional but needs more testing (none currently)

Each role has its own detailed page:  
`docs/role-<name>.md`
Each control area has **two parallel roles**: one for RHEL 9 family and one for Ubuntu/Debian.
OS detection is automatic in the playbook, you do not need to select which set to apply.

## RHEL 9 / AlmaLinux 9 / Rocky Linux 9

| Role | Main Purpose | CIS Sections | Tags | Doc |
|---|---|---|---|---|
| `linux_kernel_hardening_rhel9` | Sysctl hardening + module blacklisting | 1.5, 3.3 | kernel, sysctl | [→](role-linux_kernel_hardening_rhel9.md) |
| `linux_selinux_rhel9` | SELinux enforcing mode + booleans + restorecon | 1.6 | mac, selinux | [→](role-linux_selinux_rhel9.md) |
| `linux_authselect_rhel9` | PAM, pwquality, faillock, authselect profile | 5.3, 5.4 | auth, pam | [→](role-linux_authselect_rhel9.md) |
| `linux_user_management_rhel9` | Root lock, legacy users, password policy | 5.2–5.5 | users | [→](role-linux_user_management_rhel9.md) |
| `linux_ssh_hardening_rhel9` | Deep SSH server hardening | 5.1 | ssh | [→](role-linux_ssh_hardening_rhel9.md) |
| `linux_firewalld_rhel9` | firewalld default drop + SSH restrictions | 3.5 | firewall | [→](role-linux_firewalld_rhel9.md) |
| `linux_ip_forwarding_rhel9` | Disable IP forwarding & redirects | 3.1, 3.2 | network, sysctl | [→](role-linux_ip_forwarding_rhel9.md) |
| `linux_crypto_policies_rhel9` | System-wide crypto (FUTURE + no SHA1) | 1.13 | crypto, tls | [→](role-linux_crypto_policies_rhel9.md) |
| `linux_auditing_rhel9` | auditd rules + rsyslog forwarding | 6.3 | audit, logging | [→](role-linux_auditing_rhel9.md) |
| `linux_aide_rhel9` | File integrity monitoring (AIDE) | 1.4 | integrity, aide | [→](role-linux_aide_rhel9.md) |
| `linux_chrony_rhel9` | Secure NTP with Chrony | 2.1 | time, ntp | [→](role-linux_chrony_rhel9.md) |
| `linux_bootloader_password_rhel9` | GRUB2 PBKDF2 password | 1.5.2 | boot, grub | [→](role-linux_bootloader_password_rhel9.md) |
| `linux_login_banner_rhel9` | SSH & console banners | 1.7 | banner | [→](role-linux_login_banner_rhel9.md) |
| `linux_disable_unnecessary_services_rhel9` | Mask/disable legacy services | 2.x | services | [→](role-linux_disable_unnecessary_services_rhel9.md) |
| `linux_dnf_automatic_rhel9` | Automatic security updates (dnf-automatic) | 1.9 | updates, patching | [→](role-linux_dnf_automatic_rhel9.md) |
| `linux_core_dumps_rhel9` | Restrict core dumps | 1.5.1 | coredump | [→](role-linux_core_dumps_rhel9.md) |
| `linux_ctrl_alt_del_rhel9` | Disable Ctrl+Alt+Del reboot | 1.6.1 | system | [→](role-linux_ctrl_alt_del_rhel9.md) |
| `linux_tmp_mounts_rhel9` | noexec/nodev/nosuid on /tmp, /dev/shm | 1.1.2.x | mounts, filesystem | [→](role-linux_tmp_mounts_rhel9.md) |
| `linux_secure_boot_rhel9` | Secure Boot verification + /boot permissions | 1.5.1 | boot, secureboot | [→](role-linux_secure_boot_rhel9.md) |
| `linux_file_permissions_rhel9` | Critical file permissions + world-writable scan | 6.1 | permissions | [→](role-linux_file_permissions_rhel9.md) |
| `linux_fail2ban_rhel9` | Brute-force protection (sshd + firewalld) |: | fail2ban | [→](role-linux_fail2ban_rhel9.md) |

---

## Ubuntu 20.04 / 22.04 / 24.04: Debian 11 / 12

| Role | Main Purpose | CIS Sections | Tags | Doc |
|---|---|---|---|---|
| `linux_kernel_hardening_ubuntu` | Sysctl hardening + module blacklisting | 1.5, 3.3 | kernel, sysctl | [→](role-linux_kernel_hardening_ubuntu.md) |
| `linux_apparmor_ubuntu` | AppArmor enforce mode + profile management | 1.6 | mac, apparmor | [→](role-linux_apparmor_ubuntu.md) |
| `linux_authselect_ubuntu` | PAM, pwquality, pam_faillock, password policy | 5.3, 5.4 | auth, pam | [→](role-linux_authselect_ubuntu.md) |
| `linux_user_management_ubuntu` | Root lock, system accounts, inactive lock | 5.4, 5.5 | users | [→](role-linux_user_management_ubuntu.md) |
| `linux_ssh_hardening_ubuntu` | Deep SSH server hardening | 5.1 | ssh | [→](role-linux_ssh_hardening_ubuntu.md) |
| `linux_firewall_ubuntu` | UFW default-deny + custom allow/deny rules | 3.5 | firewall | [→](role-linux_firewall_ubuntu.md) |
| `linux_ip_forwarding_ubuntu` | Disable IP forwarding & redirects | 3.1, 3.2 | network, sysctl | [→](role-linux_ip_forwarding_ubuntu.md) |
| `linux_crypto_policies_ubuntu` | OpenSSL/GnuTLS TLS policy (no TLS 1.0/1.1) | 1.10 | crypto, tls | [→](role-linux_crypto_policies_ubuntu.md) |
| `linux_auditing_ubuntu` | auditd rules + rsyslog forwarding | 6.3 | audit, logging | [→](role-linux_auditing_ubuntu.md) |
| `linux_aide_ubuntu` | File integrity monitoring (AIDE) | 1.4 | integrity, aide | [→](role-linux_aide_ubuntu.md) |
| `linux_chrony_ubuntu` | Secure NTP with Chrony | 2.1 | time, ntp | [→](role-linux_chrony_ubuntu.md) |
| `linux_bootloader_password_ubuntu` | GRUB password protection (BIOS + EFI) | 1.5.2 | boot, grub | [→](role-linux_bootloader_password_ubuntu.md) |
| `linux_login_banner_ubuntu` | SSH & console banners + disable dynamic MOTD | 1.7 | banner | [→](role-linux_login_banner_ubuntu.md) |
| `linux_disable_unnecessary_services_ubuntu` | Mask/disable legacy services | 2.x | services | [→](role-linux_disable_unnecessary_services_ubuntu.md) |
| `linux_unattended_upgrades_ubuntu` | Automatic security updates (unattended-upgrades) | 1.9 | updates, patching | [→](role-linux_unattended_upgrades_ubuntu.md) |
| `linux_core_dumps_ubuntu` | Restrict core dumps | 1.5.1 | coredump | [→](role-linux_core_dumps_ubuntu.md) |
| `linux_ctrl_alt_del_ubuntu` | Disable Ctrl+Alt+Del reboot | 1.6.1 | system | [→](role-linux_ctrl_alt_del_ubuntu.md) |
| `linux_tmp_mounts_ubuntu` | noexec/nodev/nosuid on /tmp, /dev/shm | 1.1.2.x | mounts, filesystem | [→](role-linux_tmp_mounts_ubuntu.md) |
| `linux_secure_boot_ubuntu` | Secure Boot verification + /boot permissions | 1.5.1 | boot, secureboot | [→](role-linux_secure_boot_ubuntu.md) |
| `linux_file_permissions_ubuntu` | Critical file permissions + world-writable scan | 6.1 | permissions | [→](role-linux_file_permissions_ubuntu.md) |
| `linux_fail2ban_ubuntu` | Brute-force protection via Fail2ban *(Ubuntu only)* |: | fail2ban | [→](role-linux_fail2ban_ubuntu.md) |

---

## OS-to-Technology Mapping

| Control Area | RHEL9 Technology | Ubuntu/Debian Technology |
|---|---|---|
| Mandatory Access Control | SELinux (enforcing) | AppArmor (enforce mode) |
| Firewall | firewalld | UFW |
| Automatic updates | dnf-automatic | unattended-upgrades |
| Crypto policies | `update-crypto-policies` | OpenSSL + GnuTLS config |
| Auth profile | `authselect` profiles | Direct PAM config |

---

**Legend**
- **Stable**: production ready, tested on RHEL9 family and Ubuntu 22.04
- All roles support `--check` / `--diff` mode and are idempotent
