_checks_auth() {
# =============================================================================
#  2. AUTHENTICATION & ACCESS
# =============================================================================
section "2. AUTHENTICATION & ACCESS"

# AUTH-01 Root account locked
ROOT_STATUS=$(passwd -S root 2>/dev/null | awk '{print $2}' || echo "")
if [[ "$ROOT_STATUS" =~ ^L ]]; then
  add_result "Auth" "PASS" "AUTH-01" "Root account locked" "Compte root verrouillé" "Status: $ROOT_STATUS" ""
else
  add_result "Auth" "WARN" "AUTH-01" "Root account not locked" "Root non verrouillé" "Status: ${ROOT_STATUS:-unknown}" \
    "Verrouillez: 'passwd -l root'"
fi

# AUTH-02 Empty passwords
EMPTY_PASS=$(awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
if [[ -z "$EMPTY_PASS" ]]; then
  add_result "Auth" "PASS" "AUTH-02" "No empty password accounts" "Aucun compte sans mdp" "All accounts secured" ""
else
  add_result "Auth" "FAIL" "AUTH-02" "Empty password accounts" "Comptes sans mot de passe" "$EMPTY_PASS" \
    "Set a password, or lock the account: 'passwd -l <user>'"
fi

# AUTH-03 Password max age
PASSMAX=$(grep -E "^PASS_MAX_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "")
if [[ -n "$PASSMAX" && "$PASSMAX" -le 90 ]]; then
  add_result "Auth" "PASS" "AUTH-03" "Password max age <= 90 days" "Expiration mdp ≤ 90j" "PASS_MAX_DAYS=$PASSMAX" ""
else
  add_result "Auth" "FAIL" "AUTH-03" "Password max age too long" "Expiration mdp trop longue" "PASS_MAX_DAYS=${PASSMAX:-not set}" \
    "Set PASS_MAX_DAYS=90 in /etc/login.defs"
fi

# AUTH-04 Password min length (pwquality preferred, fallback to login.defs)
PASSMINLEN=""
if [[ -f /etc/security/pwquality.conf ]]; then
  PASSMINLEN=$(grep -E "^\s*minlen\s*=" /etc/security/pwquality.conf 2>/dev/null | \
    awk -F= '{print $2}' | tr -d ' ' | head -1 || echo "")
fi
[[ -z "$PASSMINLEN" ]] && \
  PASSMINLEN=$(grep -E "^PASS_MIN_LEN" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "")
if [[ -n "$PASSMINLEN" && "$PASSMINLEN" -ge 12 ]]; then
  add_result "Auth" "PASS" "AUTH-04" "Password min length >= 12" "Longueur mdp ≥ 12" "minlen=$PASSMINLEN" ""
else
  add_result "Auth" "WARN" "AUTH-04" "Password min length too short" "Longueur mdp insuffisante" "minlen=${PASSMINLEN:-not set}" \
    "Set 'minlen = 14' in /etc/security/pwquality.conf"
fi

# AUTH-05 No NOPASSWD ALL in sudo
if grep -rE '^\s*[^#].*NOPASSWD\s*:\s*ALL' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -qv "^#"; then
  add_result "Auth" "FAIL" "AUTH-05" "Passwordless sudo ALL found" "Sudo sans mdp (ALL) détecté" "NOPASSWD:ALL present" \
    "Review /etc/sudoers: grant NOPASSWD only on specific commands."
else
  add_result "Auth" "PASS" "AUTH-05" "No unrestricted passwordless sudo" "Sudo sans mdp (ALL) absent" "sudoers OK" ""
fi

# AUTH-06 Inactive never-logged accounts
INACTIVE=$(lastlog 2>/dev/null | awk 'NR>1 && /Never logged in/{print $1}' | \
  grep -vE "^(root|bin|daemon|adm|lp|sync|shutdown|halt|mail|operator|games|ftp|nobody)$" | \
  tr '\n' ',' | sed 's/,$//' || echo "")
if [[ -z "$INACTIVE" ]]; then
  add_result "Auth" "PASS" "AUTH-06" "No stale never-logged accounts" "Pas de comptes inutilisés" "OK" ""
else
  add_result "Auth" "WARN" "AUTH-06" "Never-logged-in accounts found" "Comptes jamais utilisés" "${INACTIVE:0:80}" \
    "Check and remove: 'userdel <user>'"
fi

# AUTH-07 Password minimum age (PASS_MIN_DAYS)
PASSMIN_DAYS=$(grep -E "^PASS_MIN_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "")
if [[ -n "$PASSMIN_DAYS" && "$PASSMIN_DAYS" -ge 1 ]]; then
  add_result "Auth" "PASS" "AUTH-07" "Password min age >= 1 day" "Âge min mdp ≥ 1j" "PASS_MIN_DAYS=$PASSMIN_DAYS" ""
else
  add_result "Auth" "WARN" "AUTH-07" "Password min age not set" "Âge min mdp non défini" "PASS_MIN_DAYS=${PASSMIN_DAYS:-0}" \
    "Set PASS_MIN_DAYS=7 in /etc/login.defs"
fi

# AUTH-08 Password warning age (PASS_WARN_AGE)
PASS_WARN=$(grep -E "^PASS_WARN_AGE" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "")
if [[ -n "$PASS_WARN" && "$PASS_WARN" -ge 7 ]]; then
  add_result "Auth" "PASS" "AUTH-08" "Password warning age >= 7 days" "Alerte expiration mdp ≥ 7j" "PASS_WARN_AGE=$PASS_WARN" ""
else
  add_result "Auth" "WARN" "AUTH-08" "Password warning age too low" "Alerte expiration mdp insuffisante" "PASS_WARN_AGE=${PASS_WARN:-not set}" \
    "Set PASS_WARN_AGE=14 in /etc/login.defs"
fi

# AUTH-09 Account lockout policy (faillock / pam_tally2)
LOCKOUT_OK=false
if [[ -f /etc/security/faillock.conf ]]; then
  DENY_VAL=$(grep -E "^\s*deny\s*=" /etc/security/faillock.conf 2>/dev/null | \
    awk -F= '{print $2}' | tr -d ' ' | head -1 || echo "")
  [[ -n "$DENY_VAL" && "$DENY_VAL" -le 5 && "$DENY_VAL" -gt 0 ]] && LOCKOUT_OK=true
fi
grep -rqE 'pam_tally2|pam_faillock' /etc/pam.d/ 2>/dev/null && LOCKOUT_OK=true
if $LOCKOUT_OK; then
  add_result "Auth" "PASS" "AUTH-09" "Account lockout configured" "Verrouillage compte configuré" "faillock/pam_tally2 active" ""
else
  add_result "Auth" "FAIL" "AUTH-09" "No account lockout policy" "Aucune politique de verrouillage" "faillock unconfigured" \
    "Configure faillock: 'deny=5, unlock_time=900' in /etc/security/faillock.conf"
fi

# AUTH-10 Shell timeout (TMOUT)
TMOUT_VAL=$(grep -rE "^\s*TMOUT\s*=" /etc/profile /etc/profile.d/*.sh /etc/bashrc /etc/bash.bashrc 2>/dev/null | \
  grep -oE '[0-9]+' | sort -n | head -1 || echo "")
if [[ -n "$TMOUT_VAL" && "$TMOUT_VAL" -le 900 && "$TMOUT_VAL" -gt 0 ]]; then
  add_result "Auth" "PASS" "AUTH-10" "Shell timeout configured" "Délai session shell configuré" "TMOUT=${TMOUT_VAL}s" ""
else
  add_result "Auth" "WARN" "AUTH-10" "Shell timeout not configured" "Délai session shell absent" "TMOUT=${TMOUT_VAL:-not set}" \
    "Add to /etc/profile.d/timeout.sh: 'readonly TMOUT=600; export TMOUT'"
fi

# AUTH-11 No extra UID 0 accounts (besides root)
UID0_ACCOUNTS=$(awk -F: '($3==0 && $1!="root"){print $1}' /etc/passwd 2>/dev/null | \
  tr '\n' ',' | sed 's/,$//' || echo "")
if [[ -z "$UID0_ACCOUNTS" ]]; then
  add_result "Auth" "PASS" "AUTH-11" "No extra UID 0 accounts" "Aucun compte UID 0 illégitime" "root only" ""
else
  add_result "Auth" "FAIL" "AUTH-11" "Extra UID 0 accounts found" "Comptes UID 0 supplémentaires" "$UID0_ACCOUNTS" \
    "Remove or change these accounts: only root should have UID 0."
fi

# AUTH-12 /etc/group permissions
GRP_PERMS=$(stat -c "%a" /etc/group 2>/dev/null || echo "")
if [[ "$GRP_PERMS" == "644" ]]; then
  add_result "Auth" "PASS" "AUTH-12" "/etc/group perms 644" "Perms /etc/group correctes" "Mode: 644" ""
else
  add_result "Auth" "FAIL" "AUTH-12" "/etc/group perms wrong" "Perms /etc/group incorrectes" "Mode: ${GRP_PERMS:-?}" \
    "Fix: 'chmod 644 /etc/group'"
fi

# AUTH-13 /etc/gshadow permissions
GSHADOW_PERMS=$(stat -c "%a" /etc/gshadow 2>/dev/null || echo "")
if [[ "$GSHADOW_PERMS" =~ ^(640|600|000|400)$ ]]; then
  add_result "Auth" "PASS" "AUTH-13" "/etc/gshadow perms correct" "Perms /etc/gshadow correctes" "Mode: $GSHADOW_PERMS" ""
else
  add_result "Auth" "FAIL" "AUTH-13" "/etc/gshadow perms wrong" "Perms /etc/gshadow incorrectes" "Mode: ${GSHADOW_PERMS:-?}" \
    "Fix: 'chmod 640 /etc/gshadow && chown root:shadow /etc/gshadow'"
fi

# AUTH-14 Password complexity (pwquality)
PWQUAL_OK=false
if [[ -f /etc/security/pwquality.conf ]]; then
  PWQUAL_MINLEN=$(grep -E "^\s*minlen\s*=" /etc/security/pwquality.conf 2>/dev/null | \
    awk -F= '{print $2}' | tr -d ' ' | head -1 || echo "")
  [[ -n "$PWQUAL_MINLEN" && "$PWQUAL_MINLEN" -ge 12 ]] && PWQUAL_OK=true
fi
if $PWQUAL_OK; then
  add_result "Auth" "PASS" "AUTH-14" "Password complexity configured" "Complexité mdp configurée" "pwquality: minlen=${PWQUAL_MINLEN}" ""
else
  add_result "Auth" "WARN" "AUTH-14" "Password complexity not enforced" "Complexité mdp non configurée" "pwquality.conf absent or weak" \
    "Configure /etc/security/pwquality.conf: minlen=14, dcredit=-1, ucredit=-1, ocredit=-1"
fi

# AUTH-15 sudo use_pty enforced (CIS 1.3.2)
if grep -rqsE "^\s*Defaults\s+.*use_pty" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
  add_result "Auth" "PASS" "AUTH-15" "sudo use_pty enforced" "sudo use_pty activé" "Defaults use_pty found" ""
else
  add_result "Auth" "WARN" "AUTH-15" "sudo use_pty not enforced" "sudo use_pty absent" "Defaults use_pty not found in sudoers" \
    "Add 'Defaults use_pty' to /etc/sudoers.d/99-cis-hardening (CIS 1.3.2)"
fi

# AUTH-16 sudo logfile configured (CIS 1.3.3)
SUDO_LOGFILE=$(grep -rshE "^\s*Defaults\s+.*logfile=" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | \
  grep -oE 'logfile=[^ ]+' | head -1 || echo "")
if [[ -n "$SUDO_LOGFILE" ]]; then
  add_result "Auth" "PASS" "AUTH-16" "sudo logfile configured" "Journal sudo configuré" "$SUDO_LOGFILE" ""
else
  add_result "Auth" "WARN" "AUTH-16" "sudo logfile not configured" "Journal sudo absent" "No logfile= in sudoers" \
    "Add 'Defaults logfile=/var/log/sudo.log' to /etc/sudoers.d/99-cis-hardening (CIS 1.3.3)"
fi
}
