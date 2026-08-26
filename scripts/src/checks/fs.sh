_checks_filesystem() {
# =============================================================================
#  4. FILESYSTEM & PERMISSIONS
# =============================================================================
section "4. FILESYSTEM & PERMISSIONS"

# FS-01 /etc/passwd
PP=$(stat -c "%a" /etc/passwd 2>/dev/null || echo "")
[[ "$PP" == "644" ]] && \
  add_result "Files" "PASS" "FS-01" "/etc/passwd perms 644" "Perms /etc/passwd correctes" "Mode: 644" "" || \
  add_result "Files" "FAIL" "FS-01" "/etc/passwd perms wrong" "Perms /etc/passwd incorrectes" "Mode: ${PP:-?}" \
    "Corrigez: 'chmod 644 /etc/passwd'"

# FS-02 /etc/shadow
SP=$(stat -c "%a" /etc/shadow 2>/dev/null || echo "")
if [[ "$SP" =~ ^(640|600|000|400)$ ]]; then
  add_result "Files" "PASS" "FS-02" "/etc/shadow perms correct" "Perms /etc/shadow correctes" "Mode: $SP" ""
else
  add_result "Files" "FAIL" "FS-02" "/etc/shadow perms wrong" "Perms /etc/shadow incorrectes" "Mode: ${SP:-?}" \
    "Fix: 'chmod 640 /etc/shadow'"
fi

# FS-03 /etc/sudoers
SDP=$(stat -c "%a" /etc/sudoers 2>/dev/null || echo "")
if [[ "$SDP" =~ ^(440|400)$ ]]; then
  add_result "Files" "PASS" "FS-03" "/etc/sudoers perms 440" "Perms sudoers correctes" "Mode: $SDP" ""
else
  add_result "Files" "WARN" "FS-03" "/etc/sudoers perms wrong" "Perms sudoers incorrectes" "Mode: ${SDP:-not found}" \
    "Fix: 'chmod 440 /etc/sudoers'"
fi

# FS-04 World-writable files
WW=$(find /etc /usr /bin /sbin -xdev -perm -0002 -type f 2>/dev/null | wc -l)
if [[ "$WW" -eq 0 ]]; then
  add_result "Files" "PASS" "FS-04" "No world-writable files" "Aucun fichier inscriptible par tous" "0 found in /etc /usr /bin /sbin" ""
else
  add_result "Files" "FAIL" "FS-04" "World-writable files found" "Fichiers inscriptibles par tous" "$WW file(s)" \
    "Auditez: 'find /etc /usr -perm -0002 -type f -ls'"
fi

# FS-05 SUID count
SUID=$(find / -xdev -perm -4000 -type f 2>/dev/null | wc -l)
if [[ "$SUID" -le 20 ]]; then
  add_result "Files" "PASS" "FS-05" "SUID binary count OK" "Binaires SUID: count OK" "Count: $SUID" ""
else
  add_result "Files" "WARN" "FS-05" "High SUID binary count" "Nombre élevé de binaires SUID" "Count: $SUID (manual review required)" \
    "Audit: 'find / -xdev -perm -4000 -ls', then remove the SUID bit from binaries that do not need it."
fi

# FS-06 /tmp noexec
TMP_OPTS=$(grep -E '\s/tmp\s' /proc/mounts 2>/dev/null | awk '{print $4}' | head -1 || echo "")
if echo "$TMP_OPTS" | grep -q "noexec"; then
  add_result "Files" "PASS" "FS-06" "/tmp mounted noexec" "/tmp monté noexec" "noexec on /tmp" ""
else
  add_result "Files" "WARN" "FS-06" "/tmp not noexec" "/tmp sans noexec" "Executables can run from /tmp" \
    "Mount /tmp with noexec,nosuid,nodev in /etc/fstab"
fi

# FS-07 Sticky bit on world-writable directories
NOSTICKY=$(find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null | wc -l)
if [[ "$NOSTICKY" -eq 0 ]]; then
  add_result "Files" "PASS" "FS-07" "Sticky bit on all world-writable dirs" "Sticky bit sur répertoires partagés" "All world-writable dirs have sticky bit" ""
else
  add_result "Files" "FAIL" "FS-07" "World-writable dirs without sticky bit" "Répertoires sans sticky bit" "$NOSTICKY dir(s)" \
    "Fix: 'find / -xdev -type d -perm -0002 ! -perm -1000 -exec chmod +t {} \;'"
fi

# FS-08 /etc/crontab permissions
CRONTAB_PERMS=$(stat -c "%a" /etc/crontab 2>/dev/null || echo "")
if [[ "$CRONTAB_PERMS" =~ ^(600|400)$ ]]; then
  add_result "Files" "PASS" "FS-08" "/etc/crontab perms OK" "Perms /etc/crontab correctes" "Mode: $CRONTAB_PERMS" ""
elif [[ -z "$CRONTAB_PERMS" ]]; then
  add_result "Files" "WARN" "FS-08" "/etc/crontab not found" "/etc/crontab introuvable" "File absent" ""
else
  add_result "Files" "WARN" "FS-08" "/etc/crontab perms too open" "Perms /etc/crontab trop permissives" "Mode: $CRONTAB_PERMS" \
    "Fix: 'chmod 600 /etc/crontab && chown root:root /etc/crontab'"
fi

# FS-09 /var/tmp noexec
VARTMP_OPTS=$(grep -E '\s/var/tmp\s' /proc/mounts 2>/dev/null | awk '{print $4}' | head -1 || echo "")
if echo "$VARTMP_OPTS" | grep -q "noexec"; then
  add_result "Files" "PASS" "FS-09" "/var/tmp mounted noexec" "/var/tmp monté noexec" "noexec on /var/tmp" ""
else
  add_result "Files" "WARN" "FS-09" "/var/tmp not noexec" "/var/tmp sans noexec" "${VARTMP_OPTS:-not separately mounted}" \
    "Mount /var/tmp with noexec,nosuid,nodev in /etc/fstab"
fi

# FS-10 Unowned files and directories
UNOWNED=$(find / -xdev \( -nouser -o -nogroup \) -type f 2>/dev/null | wc -l)
if [[ "$UNOWNED" -eq 0 ]]; then
  add_result "Files" "PASS" "FS-10" "No unowned files" "Aucun fichier sans propriétaire" "0 files" ""
else
  add_result "Files" "WARN" "FS-10" "Unowned files found" "Fichiers sans propriétaire" "$UNOWNED file(s) (manual review required)" \
    "Audit: 'find / -xdev \( -nouser -o -nogroup \) -type f -ls' and assign an owner."
fi

# FS-11 /var/log not world-readable
VARLOG_PERMS=$(stat -c "%a" /var/log 2>/dev/null || echo "")
_VL_LAST="${VARLOG_PERMS: -1}"
if [[ "$_VL_LAST" == "0" || "$_VL_LAST" == "1" ]]; then
  add_result "Files" "PASS" "FS-11" "/var/log not world-readable" "/var/log non lisible par tous" "Mode: $VARLOG_PERMS" ""
else
  add_result "Files" "WARN" "FS-11" "/var/log world-readable" "/var/log lisible par tous" "Mode: ${VARLOG_PERMS:-?}" \
    "Fix: 'chmod 750 /var/log'"
fi

# FS-12 SSH host private key permissions
SSH_KEY_ISSUES=$(find /etc/ssh -name "ssh_host_*_key" ! -name "*.pub" ! -perm 600 2>/dev/null | wc -l)
if [[ "$SSH_KEY_ISSUES" -eq 0 ]]; then
  add_result "Files" "PASS" "FS-12" "SSH host private keys 600" "Clés privées SSH protégées" "All at mode 600" ""
else
  add_result "Files" "FAIL" "FS-12" "SSH host private key perms wrong" "Clés privées SSH mal protégées" "$SSH_KEY_ISSUES key(s) wrong perms" \
    "Fix: 'chmod 600 /etc/ssh/ssh_host_*_key'"
fi
}
