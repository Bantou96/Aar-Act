_checks_system() {
# =============================================================================
#  1. SYSTEM & OS
# =============================================================================
section "1. SYSTEM & OS"

# SYS-01 Distribution and what is available for it
#
# Two claims, kept apart. The audit reads sysctls, /proc, /etc and systemd, so it
# runs on anything with a Linux kernel. The Ansible hardening roles are written
# for two families and CI-tested on two images. The old check conflated them and
# told anyone outside six names to change distribution, which helps nobody.
_SYS_FAM="$(distro_family)"
if distro_roles_available; then
  add_result "System" "PASS" "SYS-01" "Distribution supported" "Distribution supportée" \
    "$(distro_pretty), family: $_SYS_FAM, hardening roles available" ""
elif [[ "$_SYS_FAM" == "unknown" ]]; then
  add_result "System" "WARN" "SYS-01" "Distribution not identified" "Distribution non identifiée" \
    "$(distro_pretty): audit still valid, hardening roles unavailable" \
    "The audit still holds: it reads /proc, /etc and systemd, which do not depend on the distribution. The hardening roles cover the RHEL and Debian families (tested on $(distro_roles_tested))."
else
  add_result "System" "WARN" "SYS-01" "Audit-only distribution" "Distribution en audit seul" \
    "$(distro_pretty), family: $_SYS_FAM, audit valid, no hardening roles" \
    "The audit and 'aartool surface' work normally. The Ansible roles do not cover the $_SYS_FAM family yet: the recommendation on each check still applies by hand."
fi

# SYS-02 Kernel (informational, always WARN to prompt version review)
add_result "System" "WARN" "SYS-02" "Kernel version" "Version noyau" "$(uname -r)" \
  "Check for kernel updates: 'dnf check-update kernel' or 'apt list --upgradable | grep linux-image'."

# SYS-03 Pending updates
#
# Every branch ends in a result. The previous version handled dnf and apt-get
# and nothing else, so on SUSE, Arch or Alpine the check emitted NOTHING: the
# report simply had one fewer line and the operator had no way to know an update
# check had been skipped. A check that disappears silently is worse than one
# that says it cannot tell.
PENDING=0
_SYS_PKG="$(distro_pkg_mgr)"
case "$_SYS_PKG" in
  dnf|dnf5|yum)
    PENDING=$("$_SYS_PKG" check-update --security -q 2>/dev/null | grep -cE '\.' || true)
    if [[ "$PENDING" -eq 0 ]]; then
      add_result "System" "PASS" "SYS-03" "No pending security updates" "Système à jour" "0 packages" ""
    else
      add_result "System" "FAIL" "SYS-03" "Pending security updates" "Mises à jour en attente" "$PENDING package(s)" \
        "Appliquez: '$_SYS_PKG update --security -y'"
    fi ;;
  apt-get)
    # Scoped to SECURITY updates, like the dnf and zypper branches above it.
    #
    # This counted every upgradable package, so the same check ID meant
    # "unpatched CVEs" on RHEL and "any package is not the newest" on Debian.
    # A docs server with unattended-upgrades running correctly, zero security
    # updates outstanding and twenty routine ones reported exactly the same
    # FAIL as a RHEL host with twenty unpatched CVEs. Anyone comparing an
    # Ubuntu fleet against a RHEL fleet was reading two different questions.
    #
    # apt marks the origin in the simulated Inst line:
    #   Inst libfoo [1.2] (1.3 Ubuntu:24.04/noble-security [amd64])
    apt-get update -qq 2>/dev/null || true
    _SYS_APT_SIM=$(apt-get -s upgrade 2>/dev/null | grep "^Inst" || true)
    PENDING=$(printf '%s\n' "$_SYS_APT_SIM" | grep -c -- '-security' || true)
    _SYS_APT_TOTAL=$(printf '%s\n' "$_SYS_APT_SIM" | grep -c . || true)
    if [[ "$PENDING" -eq 0 ]]; then
      add_result "System" "PASS" "SYS-03" "No pending security updates" "Système à jour" \
        "0 security (${_SYS_APT_TOTAL} total pending)" ""
    else
      add_result "System" "FAIL" "SYS-03" "Pending security updates" "Mises à jour de sécurité en attente" \
        "${PENDING} security (${_SYS_APT_TOTAL} total pending)" \
        "Appliquez: 'apt-get upgrade -y' (ou laissez unattended-upgrades le faire)"
    fi ;;
  zypper)
    # list-patches --category security is the SUSE equivalent of --security.
    PENDING=$(zypper --non-interactive list-patches --category security 2>/dev/null | grep -cE '^[a-zA-Z]' || true)
    PENDING=$(( PENDING > 0 ? PENDING - 1 : 0 ))   # drop the header row
    if [[ "$PENDING" -eq 0 ]]; then
      add_result "System" "PASS" "SYS-03" "No pending security patches" "Système à jour" "0 patches" ""
    else
      add_result "System" "FAIL" "SYS-03" "Pending security patches" "Correctifs en attente" "$PENDING patch(es)" \
        "Appliquez: 'zypper patch --category security'"
    fi ;;
  pacman)
    # Rolling release: there is no security-only channel, so this is all updates.
    PENDING=$(pacman -Qu 2>/dev/null | grep -c . || true)
    if [[ "$PENDING" -eq 0 ]]; then
      add_result "System" "PASS" "SYS-03" "No pending updates" "Système à jour" "0 packages" ""
    else
      add_result "System" "WARN" "SYS-03" "Pending updates" "Mises à jour en attente" "$PENDING package(s), rolling release" \
        "Apply: 'pacman -Syu'. A rolling-release distribution does not separate security fixes from the rest."
    fi ;;
  apk)
    PENDING=$(apk version -l '<' 2>/dev/null | grep -c '^[a-zA-Z]' || true)
    PENDING=$(( PENDING > 0 ? PENDING - 1 : 0 ))
    if [[ "$PENDING" -eq 0 ]]; then
      add_result "System" "PASS" "SYS-03" "No pending updates" "Système à jour" "0 packages" ""
    else
      add_result "System" "WARN" "SYS-03" "Pending updates" "Mises à jour en attente" "$PENDING package(s)" \
        "Appliquez: 'apk upgrade'"
    fi ;;
  none)
    add_result "System" "WARN" "SYS-03" "No package manager found" "Aucun gestionnaire de paquets" \
      "checked: dnf, apt-get, zypper, pacman, apk" \
      "Minimal image or immutable distribution. Check for updates through whatever mechanism that image provides." ;;
  *)
    add_result "System" "WARN" "SYS-03" "Update status not determined" "État des mises à jour indéterminé" \
      "package manager: $_SYS_PKG (unsupported by this check)" \
      "Ce gestionnaire de paquets n'est pas encore couvert. Le reste de l'audit reste valable." ;;
esac

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
    "Compare 'uname -r' by hand against the newest installed kernel."
elif [[ "$KNEW" == "$KRUN" ]]; then
  add_result "System" "PASS" "SYS-11" "Running the newest installed kernel" "Noyau le plus récent actif" \
    "$KRUN (uptime ${KUP}j)" ""
elif [[ "$(printf '%s\n%s\n' "$KRUN" "$KNEW" | sort -V | tail -1)" == "$KRUN" ]]; then
  # Running kernel outranks everything in /boot. Not a missing reboot: usually a
  # custom or vendor kernel whose image lives outside /boot.
  add_result "System" "WARN" "SYS-11" "Running kernel not found in /boot" "Noyau actif absent de /boot" \
    "running $KRUN, newest in /boot $KNEW" \
    "Kernel from outside the repositories, or an image outside /boot. Check that its source actually ships security fixes."
else
  add_result "System" "FAIL" "SYS-11" "Newer kernel installed but not running" "Noyau plus récent installé mais inactif" \
    "running $KRUN, installed $KNEW, uptime ${KUP}j" \
    "The fix is installed but not running. Reboot to activate $KNEW. On a quorum cluster (OpenSearch, Kafka, etcd), one node at a time, checking health between each."
fi

# SYS-04 SELinux / AppArmor
if cmd_exists getenforce; then
  SEMODE=$(getenforce 2>/dev/null || echo "Unknown")
  case "$SEMODE" in
    Enforcing) add_result "System" "PASS" "SYS-04" "SELinux Enforcing" "SELinux Enforcing" "$SEMODE" "" ;;
    Permissive) add_result "System" "WARN" "SYS-04" "SELinux Permissive" "SELinux Permissive" "$SEMODE" \
      "Set Enforcing: 'setenforce 1' and update /etc/selinux/config." ;;
    *) add_result "System" "FAIL" "SYS-04" "SELinux Disabled" "SELinux désactivé" "$SEMODE" \
      "Enable SELinux in /etc/selinux/config: SELINUX=enforcing" ;;
  esac
elif cmd_exists apparmor_status; then
  AA=$(apparmor_status 2>/dev/null | head -1 || echo "present")
  add_result "System" "PASS" "SYS-04" "AppArmor present" "AppArmor présent" "$AA" ""
else
  add_result "System" "FAIL" "SYS-04" "No MAC framework" "Pas de contrôle d'accès MAC" "SELinux/AppArmor absent" \
    "Install and enable SELinux or AppArmor."
fi

# SYS-05 Core dumps
CORE_RESTRICTED=false
grep -qsE '^\s*\*\s+hard\s+core\s+0' /etc/security/limits.conf /etc/security/limits.d/*.conf 2>/dev/null && CORE_RESTRICTED=true
[[ "$(sysctl -n fs.suid_dumpable 2>/dev/null)" == "0" ]] && CORE_RESTRICTED=true
if $CORE_RESTRICTED; then
  add_result "System" "PASS" "SYS-05" "Core dumps restricted" "Core dumps restreints" "Restricted" ""
else
  add_result "System" "WARN" "SYS-05" "Core dumps not restricted" "Core dumps non restreints" "May expose memory" \
    "Add '* hard core 0' to /etc/security/limits.conf"
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
    "Install and enable: 'dnf install chrony && systemctl enable --now chronyd'"
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
      "Fix: 'chmod 600 $GRUB_CFG && chown root:root $GRUB_CFG'"
  fi
else
  add_result "System" "WARN" "SYS-07" "GRUB config not found" "GRUB config introuvable" "No grub.cfg at standard paths" \
    "Check where your GRUB configuration lives."
fi

# SYS-08 Secure Boot
if cmd_exists mokutil; then
  SB_STATE=$(mokutil --sb-state 2>/dev/null | tr -d '\n' || echo "unknown")
  if echo "$SB_STATE" | grep -qi "enabled"; then
    add_result "System" "PASS" "SYS-08" "Secure Boot enabled" "Secure Boot activé" "$SB_STATE" ""
  else
    add_result "System" "WARN" "SYS-08" "Secure Boot not enabled" "Secure Boot désactivé" "${SB_STATE:-not determined}" \
      "Enable Secure Boot in the UEFI/BIOS. Cannot be configured by Ansible."
  fi
else
  add_result "System" "WARN" "SYS-08" "Cannot check Secure Boot" "Vérif Secure Boot impossible" "mokutil absent" \
    "Install mokutil ('dnf install mokutil') or check in the UEFI/BIOS."
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
    "Add to /etc/fstab: 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0'"
fi

# SYS-10 Ctrl-Alt-Delete disabled
#
# `systemctl is-masked` is not a systemd verb. It never has been: systemd
# answers "Unknown command verb 'is-masked', did you mean 'is-failed'?" and
# exits non-zero, so this check reported FAIL on every host ever scanned,
# including hosts where the target was correctly masked. Confirmed across a
# 15-node estate: 15 FAIL, 0 PASS, every one of them masked.
#
# `is-enabled` is the verb that reports masking, and it prints "masked" for a
# unit symlinked to /dev/null. Accept both "masked" and "masked-runtime".
CAD_STATE=$(systemctl is-enabled ctrl-alt-del.target 2>/dev/null || true)
if [[ "$CAD_STATE" == masked* ]]; then
  add_result "System" "PASS" "SYS-10" "Ctrl-Alt-Del masked" "Ctrl-Alt-Suppr désactivé" "ctrl-alt-del.target: ${CAD_STATE}" ""
else
  add_result "System" "FAIL" "SYS-10" "Ctrl-Alt-Del not masked" "Ctrl-Alt-Suppr actif" "ctrl-alt-del.target: ${CAD_STATE:-unknown}" \
    "Mask it: 'systemctl mask ctrl-alt-del.target && systemctl daemon-reload'"
fi
}
