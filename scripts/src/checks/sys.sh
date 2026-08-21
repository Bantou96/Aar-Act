_checks_system() {
# =============================================================================
#  1. SYSTEM & OS
# =============================================================================
section "1. SYSTEM & OS / Système et OS"

# SYS-01 Supported OS
if grep -qiE 'rhel|centos|almalinux|rocky|ubuntu|debian' /etc/os-release 2>/dev/null; then
  add_result "System" "PASS" "SYS-01" "Supported OS detected" "OS supporté" "$OS_VAL" ""
else
  add_result "System" "WARN" "SYS-01" "Supported OS detected" "OS supporté" "Unknown: $OS_VAL" \
    "Utilisez RHEL, Ubuntu ou Debian pour un support sécurité officiel."
fi

# SYS-02 Kernel (informational — always WARN to prompt version review)
add_result "System" "WARN" "SYS-02" "Kernel version" "Version noyau" "$(uname -r)" \
  "Vérifiez les mises à jour noyau: 'dnf check-update kernel' ou 'apt list --upgradable | grep linux-image'."

# SYS-03 Pending security patches
PENDING=0
if cmd_exists dnf; then
  PENDING=$(dnf check-update --security -q 2>/dev/null | grep -cE '\.' || true)
  if [[ "$PENDING" -eq 0 ]]; then
    add_result "System" "PASS" "SYS-03" "No pending security updates" "Système à jour" "0 packages" ""
  else
    add_result "System" "FAIL" "SYS-03" "Pending security updates" "Mises à jour en attente" "$PENDING package(s)" \
      "Appliquez: 'dnf update --security -y'"
  fi
elif cmd_exists apt-get; then
  apt-get update -qq 2>/dev/null || true
  PENDING=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || true)
  if [[ "$PENDING" -eq 0 ]]; then
    add_result "System" "PASS" "SYS-03" "No pending updates" "Système à jour" "0 packages" ""
  else
    add_result "System" "FAIL" "SYS-03" "Pending updates" "Mises à jour en attente" "$PENDING package(s)" \
      "Appliquez: 'apt-get upgrade -y'"
  fi
fi

# SYS-11 Running kernel is the newest one installed
#
# Placed here rather than at the end of the section because it completes the
# patching story SYS-03 starts; the ID is out of sequence so existing report
# comparisons keep working.
#
# A kernel fix only takes effect once the machine boots into it. unattended-upgrades
# installs the package and, with Automatic-Reboot "false" (the default), never
# activates it. The host then reads as fully patched on disk while still executing
# the vulnerable image, and SYS-03 cannot see it: there is nothing left pending to
# count. Found on a 13-node estate where every host had a newer kernel in /boot and
# seven had been running the old one for 108 days.
KRUN=$(uname -r)
KNEW=$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's|.*/vmlinuz-||' | grep -vE '\.(sig|efi|signed|old)$' | sort -V | tail -1)
KUP=$(awk '{printf "%d", $1/86400}' /proc/uptime 2>/dev/null || echo "?")
if [[ -z "$KNEW" ]]; then
  add_result "System" "WARN" "SYS-11" "Cannot determine installed kernels" "Noyaux installés indéterminés" \
    "no /boot/vmlinuz-* found" \
    "Comparez manuellement 'uname -r' au noyau installé le plus récent."
elif [[ "$KNEW" == "$KRUN" ]]; then
  add_result "System" "PASS" "SYS-11" "Running the newest installed kernel" "Noyau le plus récent actif" \
    "$KRUN (uptime ${KUP}j)" ""
elif [[ "$(printf '%s\n%s\n' "$KRUN" "$KNEW" | sort -V | tail -1)" == "$KRUN" ]]; then
  # Running kernel outranks everything in /boot. Not a missing reboot: usually a
  # custom or vendor kernel whose image lives outside /boot.
  add_result "System" "WARN" "SYS-11" "Running kernel not found in /boot" "Noyau actif absent de /boot" \
    "running $KRUN, newest in /boot $KNEW" \
    "Noyau hors dépôt ou image hors /boot. Vérifiez que sa source livre bien les correctifs de sécurité."
else
  add_result "System" "FAIL" "SYS-11" "Newer kernel installed but not running" "Noyau plus récent installé mais inactif" \
    "running $KRUN, installed $KNEW, uptime ${KUP}j" \
    "Le correctif est installé mais inactif. Redémarrez pour activer $KNEW. Sur un cluster à quorum (OpenSearch, Kafka, etcd), un nœud à la fois en vérifiant la santé entre chaque."
fi

# SYS-04 SELinux / AppArmor
if cmd_exists getenforce; then
  SEMODE=$(getenforce 2>/dev/null || echo "Unknown")
  case "$SEMODE" in
    Enforcing) add_result "System" "PASS" "SYS-04" "SELinux Enforcing" "SELinux Enforcing" "$SEMODE" "" ;;
    Permissive) add_result "System" "WARN" "SYS-04" "SELinux Permissive" "SELinux Permissive" "$SEMODE" \
      "Activez Enforcing: 'setenforce 1' et modifiez /etc/selinux/config." ;;
    *) add_result "System" "FAIL" "SYS-04" "SELinux Disabled" "SELinux désactivé" "$SEMODE" \
      "Activez SELinux dans /etc/selinux/config: SELINUX=enforcing" ;;
  esac
elif cmd_exists apparmor_status; then
  AA=$(apparmor_status 2>/dev/null | head -1 || echo "present")
  add_result "System" "PASS" "SYS-04" "AppArmor present" "AppArmor présent" "$AA" ""
else
  add_result "System" "FAIL" "SYS-04" "No MAC framework" "Pas de contrôle d'accès MAC" "SELinux/AppArmor absent" \
    "Installez et activez SELinux ou AppArmor."
fi

# SYS-05 Core dumps
CORE_RESTRICTED=false
grep -qsE '^\s*\*\s+hard\s+core\s+0' /etc/security/limits.conf /etc/security/limits.d/*.conf 2>/dev/null && CORE_RESTRICTED=true
[[ "$(sysctl -n fs.suid_dumpable 2>/dev/null)" == "0" ]] && CORE_RESTRICTED=true
if $CORE_RESTRICTED; then
  add_result "System" "PASS" "SYS-05" "Core dumps restricted" "Core dumps restreints" "Restricted" ""
else
  add_result "System" "WARN" "SYS-05" "Core dumps not restricted" "Core dumps non restreints" "May expose memory" \
    "Ajoutez '* hard core 0' dans /etc/security/limits.conf"
fi

# SYS-06 Time synchronization
_TSVC=""
svc_active chronyd         && _TSVC="chronyd"
svc_active chrony          && _TSVC="chrony"
svc_active ntpd            && _TSVC="ntpd"
svc_active systemd-timesyncd && _TSVC="systemd-timesyncd"
if [[ -n "$_TSVC" ]]; then
  add_result "System" "PASS" "SYS-06" "Time synchronization active" "Synchronisation temps active" "$_TSVC: running" ""
else
  add_result "System" "FAIL" "SYS-06" "No time sync daemon running" "Pas de synchronisation temps" "chronyd/ntpd/timesyncd inactive" \
    "Installez et activez: 'dnf install chrony && systemctl enable --now chronyd'"
fi

# SYS-07 GRUB config permissions
GRUB_CFG=""
[[ -f /boot/grub2/grub.cfg ]] && GRUB_CFG="/boot/grub2/grub.cfg"
[[ -f /boot/grub/grub.cfg  ]] && GRUB_CFG="/boot/grub/grub.cfg"
if [[ -n "$GRUB_CFG" ]]; then
  GRUB_PERMS=$(stat -c "%a" "$GRUB_CFG" 2>/dev/null || echo "")
  if [[ "$GRUB_PERMS" =~ ^(600|400|000)$ ]]; then
    add_result "System" "PASS" "SYS-07" "GRUB config permissions OK" "Perms GRUB correctes" "Mode: $GRUB_PERMS ($GRUB_CFG)" ""
  else
    add_result "System" "FAIL" "SYS-07" "GRUB config perms too open" "Perms GRUB trop permissives" "Mode: ${GRUB_PERMS:-?} ($GRUB_CFG)" \
      "Corrigez: 'chmod 600 $GRUB_CFG && chown root:root $GRUB_CFG'"
  fi
else
  add_result "System" "WARN" "SYS-07" "GRUB config not found" "GRUB config introuvable" "No grub.cfg at standard paths" \
    "Vérifiez l'emplacement de votre configuration GRUB."
fi

# SYS-08 Secure Boot
if cmd_exists mokutil; then
  SB_STATE=$(mokutil --sb-state 2>/dev/null | tr -d '\n' || echo "unknown")
  if echo "$SB_STATE" | grep -qi "enabled"; then
    add_result "System" "PASS" "SYS-08" "Secure Boot enabled" "Secure Boot activé" "$SB_STATE" ""
  else
    add_result "System" "WARN" "SYS-08" "Secure Boot not enabled" "Secure Boot désactivé" "${SB_STATE:-not determined}" \
      "Activez Secure Boot dans le UEFI/BIOS. Ne peut pas être configuré par Ansible."
  fi
else
  add_result "System" "WARN" "SYS-08" "Cannot check Secure Boot" "Vérif Secure Boot impossible" "mokutil absent" \
    "Installez mokutil ('dnf install mokutil') ou vérifiez dans le UEFI/BIOS."
fi

# SYS-09 /dev/shm mount hardening
SHM_OPTS=$(grep -E '\s/dev/shm\s' /proc/mounts 2>/dev/null | awk '{print $4}' | head -1 || echo "")
SHM_OK=true
[[ -z "$SHM_OPTS" ]] && SHM_OK=false
echo "$SHM_OPTS" | grep -q "noexec" || SHM_OK=false
echo "$SHM_OPTS" | grep -q "nosuid" || SHM_OK=false
echo "$SHM_OPTS" | grep -q "nodev"  || SHM_OK=false
if $SHM_OK; then
  add_result "System" "PASS" "SYS-09" "/dev/shm hardened" "/dev/shm sécurisé" "noexec,nosuid,nodev" ""
else
  add_result "System" "WARN" "SYS-09" "/dev/shm missing hardening" "/dev/shm non sécurisé" "${SHM_OPTS:-not mounted or options missing}" \
    "Ajoutez dans /etc/fstab: 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0'"
fi

# SYS-10 Ctrl-Alt-Delete disabled
if systemctl is-masked ctrl-alt-del.target &>/dev/null; then
  add_result "System" "PASS" "SYS-10" "Ctrl-Alt-Del masked" "Ctrl-Alt-Suppr désactivé" "ctrl-alt-del.target: masked" ""
else
  add_result "System" "FAIL" "SYS-10" "Ctrl-Alt-Del not masked" "Ctrl-Alt-Suppr actif" "ctrl-alt-del.target: not masked" \
    "Masquez: 'systemctl mask ctrl-alt-del.target && systemctl daemon-reload'"
fi
}
