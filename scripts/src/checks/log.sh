_checks_logging() {
# =============================================================================
#  6. LOGGING & AUDIT
# =============================================================================
section "6. LOGGING & AUDIT"

# LOG-01 auditd
if svc_active auditd; then
  add_result "Logging" "PASS" "LOG-01" "auditd running" "auditd actif" "auditd: active" ""
else
  add_result "Logging" "FAIL" "LOG-01" "auditd not running" "auditd inactif" "auditd: inactive" \
    "Enable: 'systemctl enable --now auditd'"
fi

# LOG-02 syslog
if svc_active rsyslog || svc_active syslog || svc_active systemd-journald; then
  add_result "Logging" "PASS" "LOG-02" "System logging active" "Journalisation active" "rsyslog/journald running" ""
else
  add_result "Logging" "FAIL" "LOG-02" "No system logging" "Journalisation inactive" "rsyslog/journald inactive" \
    "Enable: 'systemctl enable --now rsyslog'"
fi

# LOG-03 logrotate
if [[ -f /etc/logrotate.conf ]]; then
  add_result "Logging" "PASS" "LOG-03" "logrotate configured" "Rotation logs configurée" "/etc/logrotate.conf present" ""
else
  add_result "Logging" "WARN" "LOG-03" "logrotate not found" "Rotation logs absente" "No logrotate.conf" \
    "Install: 'dnf install logrotate'"
fi

# LOG-04 Audit rules
if cmd_exists auditctl; then
  AUDIT_RULES=$(auditctl -l 2>/dev/null | grep -cE "execve|chmod|chown|delete|login|sudo" || true)
  AUDIT_RULES=${AUDIT_RULES:-0}
  if [[ "$AUDIT_RULES" -ge 3 ]]; then
    add_result "Logging" "PASS" "LOG-04" "Audit rules configured" "Règles d'audit présentes" "$AUDIT_RULES rules found" ""
  else
    add_result "Logging" "WARN" "LOG-04" "Few audit rules" "Peu de règles d'audit" "$AUDIT_RULES rule(s)" \
      "Add rules under /etc/audit/rules.d/ (see the cyberaar.hardening Ansible roles)."
  fi
else
  add_result "Logging" "WARN" "LOG-04" "auditctl not available" "auditctl indisponible" "Cannot check rules" \
    "Install: 'dnf install audit'"
fi

# LOG-05 Audit log max size configured
AUDITD_CONF="/etc/audit/auditd.conf"
if [[ -f "$AUDITD_CONF" ]]; then
  MAX_LOG=$(grep -E "^\s*max_log_file\s*=" "$AUDITD_CONF" 2>/dev/null | \
    awk -F= '{print $2}' | tr -d ' ' | head -1 || echo "")
  if [[ -n "$MAX_LOG" && "$MAX_LOG" -ge 8 ]]; then
    add_result "Logging" "PASS" "LOG-05" "Audit log max size >= 8 MB" "Taille max log audit ≥ 8 Mo" "max_log_file=${MAX_LOG}MB" ""
  else
    add_result "Logging" "WARN" "LOG-05" "Audit log max size too small" "Taille max log audit insuffisante" "max_log_file=${MAX_LOG:-not set}" \
      "Set 'max_log_file = 8' in /etc/audit/auditd.conf"
  fi
else
  add_result "Logging" "WARN" "LOG-05" "auditd.conf not found" "auditd.conf introuvable" "Not at /etc/audit/auditd.conf" \
    "Install auditd: 'dnf install audit'"
fi

# LOG-06 Kernel audit=1 at boot
if grep -qE '\baudit=1\b' /proc/cmdline 2>/dev/null; then
  add_result "Logging" "PASS" "LOG-06" "Kernel audit enabled at boot" "Audit noyau activé au boot" "audit=1 in kernel cmdline" ""
else
  add_result "Logging" "WARN" "LOG-06" "Kernel audit not enabled at boot" "Audit noyau absent au boot" "audit=1 missing from /proc/cmdline" \
    "Add 'audit=1' to GRUB_CMDLINE_LINUX in /etc/default/grub, then regenerate grub.cfg"
fi

# LOG-07 journald persistent storage
if [[ -d /var/log/journal ]]; then
  add_result "Logging" "PASS" "LOG-07" "journald persistent storage" "Journald persistant" "/var/log/journal exists" ""
else
  add_result "Logging" "WARN" "LOG-07" "journald not persistent" "Journald non persistant" "/var/log/journal absent (volatile)" \
    "Enable: 'mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal'"
fi

# LOG-09 journald Storage=persistent configured (CIS 4.2.1.1)
_JD_STORAGE=$(grep -rshE '^\s*Storage\s*=' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null | \
  awk -F= '{print $2}' | tr -d ' ' | tail -1)
if [[ "$_JD_STORAGE" == "persistent" || "$_JD_STORAGE" == "auto" ]]; then
  add_result "Logging" "PASS" "LOG-09" "journald Storage configured" "Stockage journald configuré" "Storage=$_JD_STORAGE" ""
else
  add_result "Logging" "WARN" "LOG-09" "journald Storage not set" "Stockage journald non configuré" "Storage=${_JD_STORAGE:-not set}" \
    "Create /etc/systemd/journald.conf.d/99-cis-journald.conf with Storage=persistent"
fi

# LOG-10 journald rate limiting configured (CIS 4.2.1.3)
_JD_BURST=$(grep -rshE '^\s*RateLimitBurst\s*=' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null | \
  awk -F= '{print $2}' | tr -d ' ' | tail -1)
if [[ -n "$_JD_BURST" && "$_JD_BURST" -gt 0 ]] 2>/dev/null; then
  add_result "Logging" "PASS" "LOG-10" "journald rate limiting configured" "Limitation débit journald configurée" "RateLimitBurst=$_JD_BURST" ""
else
  add_result "Logging" "WARN" "LOG-10" "journald rate limiting not set" "Limitation débit journald absente" "RateLimitBurst=${_JD_BURST:-not set}" \
    "Add RateLimitBurst=10000 and RateLimitInterval=30s to /etc/systemd/journald.conf.d/99-cis-journald.conf"
fi

# LOG-08 Remote syslog configured (informational — no Ansible remediation)
REMOTE_LOG=false
if [[ -f /etc/rsyslog.conf ]] || [[ -d /etc/rsyslog.d ]]; then
  grep -rqE '@@?[0-9a-zA-Z]|action\(type="omfwd"' /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null && REMOTE_LOG=true
fi
if $REMOTE_LOG; then
  add_result "Logging" "PASS" "LOG-08" "Remote syslog configured" "Syslog distant configuré" "Remote forwarding found in rsyslog" ""
else
  add_result "Logging" "WARN" "LOG-08" "No remote syslog" "Pas de syslog distant" "Logs stored locally only" \
    "Configure a remote syslog server in /etc/rsyslog.d/ so logs are centralised."
fi
}
