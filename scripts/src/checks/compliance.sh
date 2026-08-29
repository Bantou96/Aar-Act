_checks_compliance() {
# =============================================================================
#  8. COMPLIANCE & POLICY
# =============================================================================
section "8. COMPLIANCE & POLICY"

# COMP-01 Legal banner /etc/issue.net
if [[ -f /etc/issue.net ]]; then
  BANNER_LINES=$(wc -l < /etc/issue.net 2>/dev/null || echo 0)
  if [[ "$BANNER_LINES" -ge 2 ]]; then
    add_result "Compliance" "PASS" "COMP-01" "Legal banner configured (/etc/issue.net)" "Bannière légale configurée" "${BANNER_LINES} line(s)" ""
  else
    add_result "Compliance" "WARN" "COMP-01" "Legal banner too short" "Bannière légale trop courte" "${BANNER_LINES} line(s) in /etc/issue.net" \
      "Add an authorised-access warning to /etc/issue.net (at least 2 lines)"
  fi
else
  add_result "Compliance" "WARN" "COMP-01" "No legal banner (/etc/issue.net)" "Bannière légale absente" "/etc/issue.net missing" \
    "Create /etc/issue.net with a legal warning message."
fi

# COMP-02 /tmp on dedicated partition or tmpfs
TMP_DEDICATED=false
grep -qE '\s/tmp\s' /etc/fstab 2>/dev/null && TMP_DEDICATED=true
grep -qE 'tmpfs\s+/tmp' /proc/mounts 2>/dev/null && TMP_DEDICATED=true
if $TMP_DEDICATED; then
  add_result "Compliance" "PASS" "COMP-02" "/tmp on dedicated partition/tmpfs" "/tmp partition dédiée" "Separate /tmp mount found" ""
else
  add_result "Compliance" "WARN" "COMP-02" "/tmp not on dedicated partition" "/tmp non isolé" "/tmp not separately mounted" \
    "Isolez /tmp: ajoutez 'tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0' dans /etc/fstab"
fi

# COMP-03 /home on separate partition (informational, cannot change post-install)
HOME_PART=$(grep -cE '\s/home\s' /proc/mounts 2>/dev/null || true)
HOME_PART=${HOME_PART:-0}
if [[ "$HOME_PART" -ge 1 ]]; then
  add_result "Compliance" "PASS" "COMP-03" "/home on separate partition" "/home partition dédiée" "Separate /home mount" ""
else
  add_result "Compliance" "WARN" "COMP-03" "/home not on separate partition" "/home non isolé" "Shared with / partition (manual review)" \
    "Manual review: putting /home on its own partition is recommended (CIS 1.1.18)"
fi

# COMP-04 /var on separate partition (informational, cannot change post-install)
VAR_PART=$(grep -cE '\s/var\s' /proc/mounts 2>/dev/null || true)
VAR_PART=${VAR_PART:-0}
if [[ "$VAR_PART" -ge 1 ]]; then
  add_result "Compliance" "PASS" "COMP-04" "/var on separate partition" "/var partition dédiée" "Separate /var mount" ""
else
  add_result "Compliance" "WARN" "COMP-04" "/var not on separate partition" "/var non isolé" "Shared with / partition (manual review)" \
    "Manual review: a separate /var stops logs filling / (CIS 1.1.12)"
fi

# COMP-05 Default umask hardened (027 or stricter)
UMASK_VAL=""
while IFS= read -r _um; do
  [[ "$_um" =~ ^0?(027|077)$ ]] && UMASK_VAL="$_um" && break
done < <(grep -rE "^\s*(umask|UMASK)\s+" \
  /etc/profile /etc/profile.d/*.sh /etc/bashrc /etc/bash.bashrc /etc/login.defs 2>/dev/null | \
  grep -v "^#" | grep -oE '[0-7]{3,4}')
if [[ -n "$UMASK_VAL" ]]; then
  add_result "Compliance" "PASS" "COMP-05" "Umask 027 or stricter" "Umask 027 ou plus restrictif" "umask=$UMASK_VAL" ""
else
  _RAW_UMASK=$(grep -rE "^\s*(umask|UMASK)\s+" \
    /etc/profile /etc/profile.d/*.sh /etc/bashrc /etc/bash.bashrc /etc/login.defs 2>/dev/null | \
    grep -v "^#" | grep -oE '[0-7]{3,4}' | head -1 || echo "022 (default)")
  add_result "Compliance" "WARN" "COMP-05" "Umask too permissive" "Umask trop permissif" "umask=${_RAW_UMASK}" \
    "Set 'umask 027' in /etc/profile.d/umask.sh: it protects newly created files."
fi

# COMP-06 ASLR fully enabled
ASLR=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "?")
if [[ "$ASLR" == "2" ]]; then
  add_result "Compliance" "PASS" "COMP-06" "ASLR fully enabled" "ASLR activé (niveau 2)" "randomize_va_space=2" ""
elif [[ "$ASLR" == "1" ]]; then
  add_result "Compliance" "WARN" "COMP-06" "ASLR partial (level 1)" "ASLR partiel" "randomize_va_space=1 (prefer 2)" \
    "Enable level 2: 'sysctl -w kernel.randomize_va_space=2'"
else
  add_result "Compliance" "FAIL" "COMP-06" "ASLR disabled" "ASLR désactivé" "randomize_va_space=$ASLR" \
    "Enable ASLR: 'sysctl -w kernel.randomize_va_space=2'"
fi

# COMP-07 Kernel pointer restriction
KPTR=$(sysctl -n kernel.kptr_restrict 2>/dev/null || echo "?")
if [[ "$KPTR" == "2" ]]; then
  add_result "Compliance" "PASS" "COMP-07" "Kernel pointers hidden (kptr_restrict=2)" "Pointeurs noyau cachés" "kptr_restrict=2" ""
elif [[ "$KPTR" == "1" ]]; then
  add_result "Compliance" "WARN" "COMP-07" "Kernel pointers partially restricted" "Pointeurs noyau partiellement restreints" "kptr_restrict=1 (prefer 2)" \
    "Harden it: 'sysctl -w kernel.kptr_restrict=2'"
else
  add_result "Compliance" "FAIL" "COMP-07" "Kernel pointers exposed" "Pointeurs noyau exposés" "kptr_restrict=$KPTR" \
    "Enable: 'sysctl -w kernel.kptr_restrict=2' in /etc/sysctl.d/"
fi

# COMP-08 dmesg restriction
DMESG=$(sysctl -n kernel.dmesg_restrict 2>/dev/null || echo "?")
if [[ "$DMESG" == "1" ]]; then
  add_result "Compliance" "PASS" "COMP-08" "dmesg restricted to root" "dmesg restreint à root" "dmesg_restrict=1" ""
else
  add_result "Compliance" "WARN" "COMP-08" "dmesg not restricted" "dmesg accessible à tous" "dmesg_restrict=$DMESG" \
    "Enable: 'sysctl -w kernel.dmesg_restrict=1'"
fi

# COMP-09 ptrace scope restricted
PTRACE=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null || echo "?")
if [[ "$PTRACE" =~ ^[1-3]$ ]]; then
  add_result "Compliance" "PASS" "COMP-09" "ptrace scope restricted" "ptrace restreint" "ptrace_scope=$PTRACE" ""
else
  add_result "Compliance" "WARN" "COMP-09" "ptrace unrestricted" "ptrace non restreint" "ptrace_scope=${PTRACE:-0}" \
    "Enable: 'sysctl -w kernel.yama.ptrace_scope=1'"
fi

# COMP-10 USB storage module blacklisted
if grep -rqsE "blacklist\s+usb.storage|blacklist\s+usb_storage" /etc/modprobe.d/ 2>/dev/null; then
  add_result "Compliance" "PASS" "COMP-10" "USB storage blacklisted" "Stockage USB désactivé" "usb_storage in modprobe blacklist" ""
else
  add_result "Compliance" "WARN" "COMP-10" "USB storage not blacklisted" "Stockage USB non désactivé" "usb_storage module loadable" \
    "Add 'blacklist usb-storage' to /etc/modprobe.d/blacklist.conf (unless this is a workstation)"
fi

# COMP-11 cron service enabled (CIS 5.1.1)
_CRON_SVC="crond"
systemctl list-units --type=service 2>/dev/null | grep -q "^.*cron\.service" && _CRON_SVC="cron"
if systemctl is-enabled "$_CRON_SVC" &>/dev/null && systemctl is-active "$_CRON_SVC" &>/dev/null; then
  add_result "Compliance" "PASS" "COMP-11" "Cron service enabled and running" "Service cron actif" "$_CRON_SVC: enabled + active" ""
else
  add_result "Compliance" "WARN" "COMP-11" "Cron service not active" "Service cron inactif" "$_CRON_SVC not running or not enabled" \
    "Enable: 'systemctl enable --now cron' (Ubuntu) or 'systemctl enable --now crond' (RHEL)"
fi

# COMP-12 cron.allow and at.allow exist (CIS 5.1.8 / 5.1.9)
_CRON_ALLOW=true
_CRON_ALLOW_DETAIL=""
[[ -f /etc/cron.allow ]] || { _CRON_ALLOW=false; _CRON_ALLOW_DETAIL="/etc/cron.allow missing"; }
[[ -f /etc/at.allow ]]   || { _CRON_ALLOW=false; _CRON_ALLOW_DETAIL="${_CRON_ALLOW_DETAIL:+$_CRON_ALLOW_DETAIL, }/etc/at.allow missing"; }
if $_CRON_ALLOW; then
  add_result "Compliance" "PASS" "COMP-12" "cron.allow and at.allow configured" "Accès cron/at restreint" "allow-list model enforced" ""
else
  add_result "Compliance" "WARN" "COMP-12" "cron/at allow-list not enforced" "Accès cron/at non restreint" "${_CRON_ALLOW_DETAIL}" \
    "Create /etc/cron.allow and /etc/at.allow (empty = root only) and remove cron.deny/at.deny (CIS 5.1.8-5.1.9)"
fi
}
