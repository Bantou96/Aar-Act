_checks_ssh() {
# =============================================================================
#  3. SSH HARDENING
# =============================================================================
section "3. SSH HARDENING"

# SSH-01 PermitRootLogin
RL=$(get_ssh "PermitRootLogin")
if [[ "$RL" =~ ^(no|prohibit-password)$ ]]; then
  add_result "SSH" "PASS" "SSH-01" "PermitRootLogin disabled" "Root SSH désactivé" "PermitRootLogin=$RL" ""
else
  add_result "SSH" "FAIL" "SSH-01" "PermitRootLogin enabled" "Root SSH activé" "PermitRootLogin=${RL:-yes(default)}" \
    "Add 'PermitRootLogin no' to /etc/ssh/sshd_config"
fi

# SSH-02 PasswordAuthentication
PA=$(get_ssh "PasswordAuthentication")
if [[ "$PA" == "no" ]]; then
  add_result "SSH" "PASS" "SSH-02" "Password auth disabled" "Auth mdp SSH désactivée" "PasswordAuthentication=no" ""
else
  add_result "SSH" "WARN" "SSH-02" "Password auth enabled" "Auth mdp SSH activée" "PasswordAuthentication=${PA:-yes(default)}" \
    "Prefer SSH keys: 'PasswordAuthentication no'"
fi

# SSH-03 MaxAuthTries
MA=$(get_ssh "MaxAuthTries")
if [[ -n "$MA" && "$MA" -le 4 ]]; then
  add_result "SSH" "PASS" "SSH-03" "MaxAuthTries <= 4" "Tentatives SSH ≤ 4" "MaxAuthTries=$MA" ""
else
  add_result "SSH" "WARN" "SSH-03" "MaxAuthTries not restricted" "Tentatives SSH non limitées" "MaxAuthTries=${MA:-6(default)}" \
    "Set 'MaxAuthTries 3' in sshd_config"
fi

# SSH-04 AllowTcpForwarding
TF=$(get_ssh "AllowTcpForwarding")
if [[ "$TF" == "no" ]]; then
  add_result "SSH" "PASS" "SSH-04" "TCP Forwarding disabled" "Transfert TCP désactivé" "AllowTcpForwarding=no" ""
else
  add_result "SSH" "WARN" "SSH-04" "TCP Forwarding enabled" "Transfert TCP activé" "AllowTcpForwarding=${TF:-yes(default)}" \
    "Add 'AllowTcpForwarding no' if it is not required."
fi

# SSH-05 X11Forwarding
X11=$(get_ssh "X11Forwarding")
if [[ "$X11" == "no" ]]; then
  add_result "SSH" "PASS" "SSH-05" "X11 Forwarding disabled" "Redirection X11 désactivée" "X11Forwarding=no" ""
else
  add_result "SSH" "WARN" "SSH-05" "X11 Forwarding enabled" "Redirection X11 activée" "X11Forwarding=${X11:-yes}" \
    "Add 'X11Forwarding no' to sshd_config"
fi

# SSH-06 LoginGraceTime
LGT=$(get_ssh "LoginGraceTime")
LGT_INT=$(echo "${LGT:-120}" | grep -oE '[0-9]+' | head -1)
if [[ -n "$LGT_INT" && "$LGT_INT" -le 60 ]]; then
  add_result "SSH" "PASS" "SSH-06" "LoginGraceTime <= 60s" "Délai connexion SSH ≤ 60s" "LoginGraceTime=${LGT}" ""
else
  add_result "SSH" "WARN" "SSH-06" "LoginGraceTime too long" "Délai connexion SSH trop long" "LoginGraceTime=${LGT:-120(default)}" \
    "Set 'LoginGraceTime 60' in sshd_config"
fi

# SSH-07 PermitEmptyPasswords
PE=$(get_ssh "PermitEmptyPasswords")
if [[ "$PE" == "no" || -z "$PE" ]]; then
  add_result "SSH" "PASS" "SSH-07" "PermitEmptyPasswords disabled" "Mdp vide SSH interdit" "PermitEmptyPasswords=${PE:-no(default)}" ""
else
  add_result "SSH" "FAIL" "SSH-07" "PermitEmptyPasswords enabled" "Mdp vide SSH autorisé" "PermitEmptyPasswords=$PE" \
    "Add 'PermitEmptyPasswords no' to sshd_config"
fi

# SSH-08 IgnoreRhosts
IR=$(get_ssh "IgnoreRhosts")
if [[ "$IR" == "yes" || -z "$IR" ]]; then
  add_result "SSH" "PASS" "SSH-08" "IgnoreRhosts enabled" "Rhosts ignorés" "IgnoreRhosts=${IR:-yes(default)}" ""
else
  add_result "SSH" "FAIL" "SSH-08" "IgnoreRhosts disabled" "Rhosts autorisés" "IgnoreRhosts=$IR" \
    "Add 'IgnoreRhosts yes' to sshd_config"
fi

# SSH-09 HostbasedAuthentication
HBA=$(get_ssh "HostbasedAuthentication")
if [[ "$HBA" == "no" || -z "$HBA" ]]; then
  add_result "SSH" "PASS" "SSH-09" "HostbasedAuthentication disabled" "Auth par hôte désactivée" "HostbasedAuthentication=${HBA:-no(default)}" ""
else
  add_result "SSH" "FAIL" "SSH-09" "HostbasedAuthentication enabled" "Auth par hôte activée" "HostbasedAuthentication=$HBA" \
    "Add 'HostbasedAuthentication no' to sshd_config"
fi

# SSH-10 Legal banner
BANNER_FILE=$(get_ssh "Banner")
BANNER_OK=false
if [[ -n "$BANNER_FILE" && -f "$BANNER_FILE" ]]; then
  BANNER_LEN=$(wc -c < "$BANNER_FILE" 2>/dev/null || echo 0)
  [[ "${BANNER_LEN:-0}" -gt 10 ]] && BANNER_OK=true
fi
if $BANNER_OK; then
  add_result "SSH" "PASS" "SSH-10" "SSH legal banner configured" "Bannière légale SSH présente" "Banner=$BANNER_FILE" ""
else
  add_result "SSH" "WARN" "SSH-10" "SSH legal banner missing" "Bannière légale SSH absente" "Banner=${BANNER_FILE:-not set}" \
    "Create /etc/issue.net and add 'Banner /etc/issue.net' to sshd_config"
fi

# SSH-11 ClientAliveInterval
CAI=$(get_ssh "ClientAliveInterval")
if [[ -n "$CAI" && "$CAI" -le 300 && "$CAI" -gt 0 ]]; then
  add_result "SSH" "PASS" "SSH-11" "ClientAliveInterval <= 300s" "Délai inactivité SSH configuré" "ClientAliveInterval=$CAI" ""
else
  add_result "SSH" "WARN" "SSH-11" "ClientAliveInterval not configured" "Délai inactivité SSH absent" "ClientAliveInterval=${CAI:-not set}" \
    "Set 'ClientAliveInterval 300' and 'ClientAliveCountMax 3' in sshd_config"
fi

# SSH-12 UsePAM
UPAM=$(get_ssh "UsePAM")
if [[ "$UPAM" == "yes" || -z "$UPAM" ]]; then
  add_result "SSH" "PASS" "SSH-12" "UsePAM enabled" "PAM SSH activé" "UsePAM=${UPAM:-yes(default)}" ""
else
  add_result "SSH" "WARN" "SSH-12" "UsePAM disabled" "PAM SSH désactivé" "UsePAM=$UPAM" \
    "Add 'UsePAM yes' to sshd_config"
fi

# SSH-13 Weak ciphers absent
CIPHERS=$(get_ssh "Ciphers")
if [[ -n "$CIPHERS" ]] && echo "$CIPHERS" | grep -qiE '(arcfour|3des|des|blowfish|cast128)'; then
  add_result "SSH" "FAIL" "SSH-13" "Weak SSH ciphers configured" "Chiffrements SSH faibles détectés" "$CIPHERS" \
    "Allow only strong ciphers in sshd_config (chacha20, aes256-gcm, aes128-ctr)"
else
  add_result "SSH" "PASS" "SSH-13" "No weak SSH ciphers" "Pas de chiffrements SSH faibles" "${CIPHERS:-default (verify)}" ""
fi

# SSH-14 sshd_config permissions
SSHD_CFG_PERMS=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null || echo "")
if [[ "$SSHD_CFG_PERMS" =~ ^(600|640|644)$ ]]; then
  add_result "SSH" "PASS" "SSH-14" "sshd_config permissions OK" "Perms sshd_config correctes" "Mode: $SSHD_CFG_PERMS" ""
else
  add_result "SSH" "WARN" "SSH-14" "sshd_config permissions loose" "Perms sshd_config trop permissives" "Mode: ${SSHD_CFG_PERMS:-?}" \
    "Fix: 'chmod 600 /etc/ssh/sshd_config && chown root:root /etc/ssh/sshd_config'"
fi

# SSH-15 MaxSessions
MS=$(get_ssh "MaxSessions")
if [[ -n "$MS" && "$MS" -le 4 ]]; then
  add_result "SSH" "PASS" "SSH-15" "MaxSessions <= 4" "Sessions SSH max ≤ 4" "MaxSessions=$MS" ""
else
  add_result "SSH" "WARN" "SSH-15" "MaxSessions not restricted" "Sessions SSH non limitées" "MaxSessions=${MS:-10(default)}" \
    "Set 'MaxSessions 4' in sshd_config"
fi
}
