# =============================================================================
#  ANSIBLE REMEDIATION MAP
#  Maps each check ID → ansible tags + role names for RHEL9 and Ubuntu/Debian
#  Used to generate targeted remediation commands after the scan.
# =============================================================================
declare -A ANSIBLE_MAP=(
  # SYS-01: OS detection — informational, no Ansible remediation
  # SYS-02: kernel version — remediation is applying updates, not sysctl tuning
  ["SYS-02"]="updates,patching|linux_dnf_automatic_rhel9|linux_unattended_upgrades_ubuntu|Apply pending kernel updates"
  ["SYS-03"]="updates,patching|linux_dnf_automatic_rhel9|linux_unattended_upgrades_ubuntu|Automatic security updates"
  ["SYS-04"]="mac|linux_selinux_rhel9|linux_apparmor_ubuntu|SELinux/AppArmor enforcement"
  ["SYS-05"]="kernel,coredump|linux_core_dumps_rhel9|linux_core_dumps_ubuntu|Core dump restriction"
  ["SYS-06"]="time,ntp|linux_chrony_rhel9|linux_chrony_ubuntu|Time synchronization (chrony)"
  ["SYS-07"]="boot,grub|linux_bootloader_password_rhel9|linux_bootloader_password_ubuntu|GRUB config permissions"
  ["SYS-08"]="secureboot|linux_secure_boot_rhel9|linux_secure_boot_ubuntu|Secure Boot verification"
  ["SYS-09"]="filesystem,mounts|linux_tmp_mounts_rhel9|linux_tmp_mounts_ubuntu|/dev/shm mount hardening"
  ["SYS-10"]="system|linux_ctrl_alt_del_rhel9|linux_ctrl_alt_del_ubuntu|Ctrl-Alt-Delete disabled"
  # SYS-11: no role can fix this one. The remediation is a reboot, and on a quorum
  # cluster a reboot is an orchestration problem, not a configuration one. The roles
  # named here only decide who owns the reboot from now on (their *_reboot variable);
  # they do not activate the kernel already sitting in /boot.
  ["SYS-11"]="updates,patching|linux_dnf_automatic_rhel9|linux_unattended_upgrades_ubuntu|Reboot policy (does NOT activate the installed kernel)"
  ["AUTH-01"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|User management hardening"
  ["AUTH-02"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|User management hardening"
  # AUTH-03: PASS_MAX_DAYS in /etc/login.defs is set by user_management, not authselect
  ["AUTH-03"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Password expiry policy (login.defs)"
  ["AUTH-04"]="auth,pam|linux_authselect_rhel9|linux_authselect_ubuntu|PAM / password complexity"
  ["AUTH-05"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Sudo / user access controls"
  ["AUTH-06"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Inactive account cleanup"
  ["AUTH-07"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Password minimum age (login.defs)"
  ["AUTH-08"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Password warning age (login.defs)"
  ["AUTH-09"]="auth,pam|linux_authselect_rhel9|linux_authselect_ubuntu|Account lockout (faillock)"
  ["AUTH-10"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|Shell timeout (TMOUT)"
  ["AUTH-11"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|UID 0 account audit"
  ["AUTH-12"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|/etc/group permissions"
  ["AUTH-13"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|/etc/gshadow permissions"
  ["AUTH-14"]="auth,pam|linux_authselect_rhel9|linux_authselect_ubuntu|Password complexity (pwquality)"
  ["AUTH-15"]="sudo|linux_sudo_hardening_rhel9|linux_sudo_hardening_ubuntu|sudo use_pty enforcement"
  ["AUTH-16"]="sudo|linux_sudo_hardening_rhel9|linux_sudo_hardening_ubuntu|sudo logfile configuration"
  ["SSH-01"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-02"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-03"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-04"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-05"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-06"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-07"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-08"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-09"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-10"]="ssh,banner|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH legal banner"
  ["SSH-11"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH session timeout"
  ["SSH-12"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["SSH-13"]="ssh,crypto|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH cipher hardening"
  ["SSH-14"]="ssh,filesystem|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|sshd_config permissions"
  ["SSH-15"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH server hardening"
  ["FS-01"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|File permissions hardening"
  ["FS-02"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|File permissions hardening"
  ["FS-03"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|File permissions hardening"
  ["FS-04"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|File permissions hardening"
  ["FS-05"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|SUID binary audit"
  ["FS-06"]="filesystem,mounts|linux_tmp_mounts_rhel9|linux_tmp_mounts_ubuntu|/tmp mount hardening"
  ["FS-07"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|Sticky bit on world-writable dirs"
  ["FS-08"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|/etc/crontab permissions"
  ["FS-09"]="filesystem,mounts|linux_tmp_mounts_rhel9|linux_tmp_mounts_ubuntu|/var/tmp mount hardening"
  ["FS-10"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|Unowned files audit"
  ["FS-11"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|/var/log permissions"
  ["FS-12"]="ssh|linux_ssh_hardening_rhel9|linux_ssh_hardening_ubuntu|SSH host key permissions"
  ["NET-01"]="firewall|linux_firewalld_rhel9|linux_firewall_ubuntu|Firewall configuration"
  ["NET-02"]="network,sysctl|linux_ip_forwarding_rhel9|linux_ip_forwarding_ubuntu|IP forwarding restriction"
  # NET-03: accept_redirects is set by ip_forwarding role, not kernel_hardening
  ["NET-03"]="network,sysctl|linux_ip_forwarding_rhel9|linux_ip_forwarding_ubuntu|ICMP redirect hardening"
  ["NET-04"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|TCP SYN cookie hardening"
  ["NET-05"]="services|linux_disable_unnecessary_services_rhel9|linux_disable_unnecessary_services_ubuntu|Disable dangerous services"
  ["NET-06"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Source routing disabled"
  ["NET-07"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Send redirects disabled"
  ["NET-08"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Martian packet logging"
  ["NET-09"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Reverse path filtering"
  ["NET-10"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|IPv6 RA disabled"
  ["NET-11"]="network,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|ICMP broadcast protection"
  ["NET-12"]="network,wireless|linux_wireless_rhel9|linux_wireless_ubuntu|Wireless interfaces disabled"
  ["NET-13"]="network,ipv6|linux_ipv6_rhel9|linux_ipv6_ubuntu|IPv6 disabled (CIS 3.3.1)"
  ["LOG-01"]="audit,logging|linux_auditing_rhel9|linux_auditing_ubuntu|auditd configuration"
  ["LOG-02"]="audit,logging|linux_auditing_rhel9|linux_auditing_ubuntu|System logging (rsyslog)"
  # LOG-03: logrotate is not managed by any hardening role — no Ansible remediation
  ["LOG-04"]="audit,logging|linux_auditing_rhel9|linux_auditing_ubuntu|Audit rules configuration"
  ["LOG-05"]="audit,logging|linux_auditing_rhel9|linux_auditing_ubuntu|Audit log size configuration"
  ["LOG-06"]="audit,logging|linux_auditing_rhel9|linux_auditing_ubuntu|Kernel audit boot parameter"
  ["LOG-07"]="audit,logging,journald|linux_journald_rhel9|linux_journald_ubuntu|journald persistent storage (/var/log/journal)"
  # LOG-08: remote syslog not managed by any hardening role — no Ansible remediation
  ["LOG-09"]="audit,logging,journald|linux_journald_rhel9|linux_journald_ubuntu|journald Storage=persistent config"
  ["LOG-10"]="audit,logging,journald|linux_journald_rhel9|linux_journald_ubuntu|journald rate limiting config"
  ["INT-01"]="integrity,aide|linux_aide_rhel9|linux_aide_ubuntu|AIDE file integrity monitor"
  # INT-02: rkhunter/chkrootkit not managed by any role — no Ansible remediation
  # INT-03: suspicious cron requires manual investigation — no Ansible remediation
  # INT-04: open port count is informational / always WARN — no Ansible remediation
  ["INT-05"]="updates,patching|linux_dnf_automatic_rhel9|linux_unattended_upgrades_ubuntu|Package GPG signature check"
  ["INT-06"]="fail2ban|linux_fail2ban_rhel9|linux_fail2ban_ubuntu|Brute-force protection (fail2ban)"
  ["INT-07"]="integrity,aide|linux_aide_rhel9|linux_aide_ubuntu|AIDE database initialization"
  ["INT-08"]="filesystem,permissions|linux_file_permissions_rhel9|linux_file_permissions_ubuntu|Cron directory permissions"
  ["COMP-01"]="banner|linux_login_banner_rhel9|linux_login_banner_ubuntu|Legal login banner"
  ["COMP-02"]="filesystem,mounts|linux_tmp_mounts_rhel9|linux_tmp_mounts_ubuntu|/tmp dedicated partition"
  # COMP-03: /home partition layout — cannot be changed by Ansible post-install
  # COMP-04: /var partition layout — cannot be changed by Ansible post-install
  ["COMP-05"]="auth,users|linux_user_management_rhel9|linux_user_management_ubuntu|System umask hardening"
  ["COMP-06"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|ASLR kernel hardening"
  ["COMP-07"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Kernel pointer restriction"
  ["COMP-08"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|dmesg restriction"
  ["COMP-09"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|ptrace scope restriction"
  ["COMP-10"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|USB storage module blacklist"
  ["COMP-11"]="cron|linux_cron_hardening_rhel9|linux_cron_hardening_ubuntu|Cron service enabled"
  ["COMP-12"]="cron|linux_cron_hardening_rhel9|linux_cron_hardening_ubuntu|cron/at allow-list enforcement"

  # ── Kernel attack surface (KRN-01..KRN-12) ─────────────────────────────────
  # All served by the same role and the same tag, because they are all sysctls
  # in one drop-in file. Without these entries a KRN warning appeared in the
  # report with no way into the remediation plan: the renderer skips any id it
  # cannot map, silently.
  #
  # The role applies the safe tier by default. KRN-01, KRN-03 and KRN-05 break
  # real workloads, so their toggles default to false and the operator opts in
  # deliberately; the description says so rather than leaving them to find out.
  ["KRN-01"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Unprivileged user namespaces (opt-in: linux_kernel_restrict_userns=true, breaks rootless containers)"
  ["KRN-02"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Unprivileged eBPF disabled"
  ["KRN-03"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|io_uring restricted (opt-in: linux_kernel_restrict_io_uring=true)"
  ["KRN-04"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Unprivileged userfaultfd disabled"
  ["KRN-05"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Module loading lockdown (opt-in: linux_kernel_lock_modules=true, irreversible until reboot)"
  ["KRN-06"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|kexec disabled"
  ["KRN-07"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|TTY line discipline autoload disabled"
  # KRN-08 lockdown is a boot parameter or Secure Boot, not a sysctl. No role.
  ["KRN-09"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|BPF JIT hardening"
  ["KRN-10"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|SysRq restricted"
  ["KRN-11"]="kernel,sysctl|linux_kernel_hardening_rhel9|linux_kernel_hardening_ubuntu|Exotic filesystem modules blacklisted"
  # KRN-12 is the summary of the four above it, not a setting of its own.
)

# ── Reachability wave ────────────────────────────────────────────────────────
# Which question a finding answers: what an attacker reaches with no account,
# what turns an account into root, what would have stopped you noticing, and
# hygiene. This is the ordering `aartool advise` prints and the thing that makes
# the tool different from a flat severity list.
#
# It is emitted into the JSON for the same reason remediation_tags is: a
# consumer that wants the ordering should not have to reimplement it. The
# dashboard kept its own copy in JS and advise has one in shell; that is two
# places that must agree, which is the drift that has bitten this repository
# three times. scripts/tests/test_waves.sh asserts this function and
# _advise_wave give the same answer for every ID the baseline can emit, so a new
# check family cannot be classified differently by the two of them.
_wave_of() {
  case "$1" in
    SSH-*|NET-*)               printf 1 ;;
    KRN-*|AUTH-*|SYS-04|SYS-05|SYS-07|SYS-08|SYS-09|SYS-10|FS-01|FS-02|FS-03|FS-05|FS-06|FS-09)
                               printf 2 ;;
    LOG-*|INT-*|AUD-*)         printf 3 ;;
    SYS-02|SYS-03|SYS-11)      printf 1 ;;   # unpatched is reachable from the network
    *)                         printf 4 ;;
  esac
}
