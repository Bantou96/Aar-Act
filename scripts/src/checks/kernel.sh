# =============================================================================
#  KERNEL ATTACK SURFACE  (KRN-01 .. KRN-12)
#
#  WHY THIS FAMILY EXISTS
#  Every other family here asks "is this configured correctly". This one asks a
#  different question: "when the next local privilege escalation lands, does it
#  reach you".
#
#  Red Hat and Debian ship the patch. Nobody helps with the window before the
#  patch exists, or with the machine you cannot reboot this quarter. That window
#  is the whole point of these checks: each one closes a class of exploit rather
#  than a single CVE, and each takes effect without a reboot.
#
#  A worked example, so the framing is not marketing. Unprivileged user
#  namespaces are the entry point for a large share of published Linux LPEs:
#  they hand an unprivileged process CAP_SYS_ADMIN inside its own namespace,
#  which is what turns a bug in nftables, io_uring, OverlayFS or a network
#  protocol into root. Turning them off does not fix any of those bugs. It
#  removes the doorway they all walk through.
#
#  These are WARN, not FAIL, and deliberately. Several of them break real
#  workloads: containers need user namespaces, some databases want io_uring,
#  debuggers want ptrace. A tool that fails a build over a setting the workload
#  requires teaches people to ignore it. Each check says what it costs.
# =============================================================================

_krn_sysctl() { sysctl -n "$1" 2>/dev/null || printf '?'; }

# The summary at KRN-12 counts these rather than re-testing the values. An
# earlier version evaluated the sysctls a second time and disagreed with itself:
# KRN-02 passed on unprivileged_bpf_disabled=2 while the summary, matching only
# "1", counted the same setting as an open door. A summary derived from anything
# other than the verdicts it summarises will drift from them.
_KRN_DOORS_OPEN=0
_KRN_DOORS_KNOWN=0
_krn_door() {           # _krn_door open|closed|na
  case "$1" in
    open)   _KRN_DOORS_OPEN=$((_KRN_DOORS_OPEN+1)); _KRN_DOORS_KNOWN=$((_KRN_DOORS_KNOWN+1)) ;;
    closed) _KRN_DOORS_KNOWN=$((_KRN_DOORS_KNOWN+1)) ;;
  esac
}
_checks_kernel() {
# =============================================================================
#  1b. KERNEL ATTACK SURFACE
# =============================================================================
section "1b. KERNEL ATTACK SURFACE"

  # ── KRN-01  Unprivileged user namespaces ─────────────────────────────────────
  # The single highest-value setting in this family.
  _KRN_USERNS="?"
  if [[ -r /proc/sys/kernel/unprivileged_userns_clone ]]; then
    _KRN_USERNS="$(_krn_sysctl kernel.unprivileged_userns_clone)"   # Debian/Ubuntu
    if [[ "$_KRN_USERNS" == "0" ]]; then
      add_result "Kernel" "PASS" "KRN-01" "Unprivileged user namespaces disabled" \
        "Espaces de noms utilisateur non privilégiés désactivés" "unprivileged_userns_clone=0" ""
      _krn_door closed
    else
      add_result "Kernel" "WARN" "KRN-01" "Unprivileged user namespaces allowed" \
        "Espaces de noms utilisateur non privilégiés autorisés" "unprivileged_userns_clone=$_KRN_USERNS" \
        "A doorway for many local privilege escalations. 'sysctl -w kernel.unprivileged_userns_clone=0'. Breaks rootless Docker/Podman and the Chrome sandbox."
      _krn_door open
    fi
  else
    _KRN_USERNS="$(_krn_sysctl user.max_user_namespaces)"            # RHEL family
    if [[ "$_KRN_USERNS" == "0" ]]; then
      add_result "Kernel" "PASS" "KRN-01" "Unprivileged user namespaces disabled" \
        "Espaces de noms utilisateur non privilégiés désactivés" "user.max_user_namespaces=0" ""
      _krn_door closed
    elif [[ "$_KRN_USERNS" == "?" ]]; then
      add_result "Kernel" "WARN" "KRN-01" "Cannot determine user namespace policy" \
        "Politique des espaces de noms indéterminée" "no unprivileged_userns_clone or max_user_namespaces" ""
      _krn_door na
    else
      add_result "Kernel" "WARN" "KRN-01" "Unprivileged user namespaces allowed" \
        "Espaces de noms utilisateur non privilégiés autorisés" "user.max_user_namespaces=$_KRN_USERNS" \
        "A doorway for many local privilege escalations. 'sysctl -w user.max_user_namespaces=0'. Breaks rootless containers."
      _krn_door open
    fi
  fi

  # ── KRN-02  Unprivileged eBPF ────────────────────────────────────────────────
  _KRN_BPF="$(_krn_sysctl kernel.unprivileged_bpf_disabled)"
  case "$_KRN_BPF" in
    1|2) add_result "Kernel" "PASS" "KRN-02" "Unprivileged eBPF disabled" \
           "eBPF non privilégié désactivé" "unprivileged_bpf_disabled=$_KRN_BPF" ""
         _krn_door closed ;;
    "?") add_result "Kernel" "WARN" "KRN-02" "eBPF policy not readable" \
           "Politique eBPF illisible" "kernel.unprivileged_bpf_disabled absent" ""
         _krn_door na ;;
    *)   add_result "Kernel" "WARN" "KRN-02" "Unprivileged eBPF allowed" \
           "eBPF non privilégié autorisé" "unprivileged_bpf_disabled=$_KRN_BPF" \
           "The eBPF verifier is a recurring exploitation surface. 'sysctl -w kernel.unprivileged_bpf_disabled=1'"
         _krn_door open ;;
  esac

  # ── KRN-03  io_uring ─────────────────────────────────────────────────────────
  # Young, large and fast-moving: a disproportionate share of recent LPEs.
  _KRN_URING="$(_krn_sysctl kernel.io_uring_disabled)"
  if [[ "$_KRN_URING" == "?" ]]; then
    add_result "Kernel" "PASS" "KRN-03" "io_uring control not present" \
      "Contrôle io_uring absent" "kernel.io_uring_disabled unsupported on this kernel" ""
    _krn_door na
  elif [[ "$_KRN_URING" == "2" ]]; then
    add_result "Kernel" "PASS" "KRN-03" "io_uring disabled" "io_uring désactivé" "io_uring_disabled=2" ""
    _krn_door closed
  else
    add_result "Kernel" "WARN" "KRN-03" "io_uring available to unprivileged users" \
      "io_uring accessible sans privilège" "io_uring_disabled=$_KRN_URING" \
      "A young and heavily exposed subsystem. 'sysctl -w kernel.io_uring_disabled=2' (1 = restricted to io_uring_group). May affect some databases and proxies."
    _krn_door open
  fi

  # ── KRN-04  userfaultfd ──────────────────────────────────────────────────────
  # Not itself a bug, but what turns a race into a reliable exploit.
  _KRN_UFFD="$(_krn_sysctl vm.unprivileged_userfaultfd)"
  if [[ "$_KRN_UFFD" == "0" ]]; then
    add_result "Kernel" "PASS" "KRN-04" "Unprivileged userfaultfd disabled" \
      "userfaultfd non privilégié désactivé" "vm.unprivileged_userfaultfd=0" ""
    _krn_door closed
  elif [[ "$_KRN_UFFD" == "?" ]]; then
    add_result "Kernel" "PASS" "KRN-04" "userfaultfd control not present" \
      "Contrôle userfaultfd absent" "vm.unprivileged_userfaultfd unsupported" ""
    _krn_door na
  else
    add_result "Kernel" "WARN" "KRN-04" "Unprivileged userfaultfd allowed" \
      "userfaultfd non privilégié autorisé" "vm.unprivileged_userfaultfd=$_KRN_UFFD" \
      "Used to make kernel race conditions reliably exploitable. 'sysctl -w vm.unprivileged_userfaultfd=0'"
    _krn_door open
  fi

  # ── KRN-05  Kernel module loading ────────────────────────────────────────────
  _KRN_MODLOCK="$(_krn_sysctl kernel.modules_disabled)"
  if [[ "$_KRN_MODLOCK" == "1" ]]; then
    add_result "Kernel" "PASS" "KRN-05" "Module loading locked" "Chargement de modules verrouillé" "kernel.modules_disabled=1" ""
  else
    add_result "Kernel" "WARN" "KRN-05" "Module loading open" "Chargement de modules ouvert" "kernel.modules_disabled=${_KRN_MODLOCK/\?/0}" \
      "Locking after boot stops a rootkit being loaded as a module. 'sysctl -w kernel.modules_disabled=1' once the machine has settled. Irreversible until reboot."
  fi

  # ── KRN-06  kexec ────────────────────────────────────────────────────────────
  _KRN_KEXEC="$(_krn_sysctl kernel.kexec_load_disabled)"
  if [[ "$_KRN_KEXEC" == "1" ]]; then
    add_result "Kernel" "PASS" "KRN-06" "kexec disabled" "kexec désactivé" "kexec_load_disabled=1" ""
  else
    add_result "Kernel" "WARN" "KRN-06" "kexec allowed" "kexec autorisé" "kexec_load_disabled=${_KRN_KEXEC/\?/0}" \
      "kexec boots an arbitrary kernel without going through the firmware, bypassing Secure Boot. 'sysctl -w kernel.kexec_load_disabled=1'"
  fi

  # ── KRN-07  TTY line discipline autoload ─────────────────────────────────────
  _KRN_LDISC="$(_krn_sysctl dev.tty.ldisc_autoload)"
  if [[ "$_KRN_LDISC" == "0" ]]; then
    add_result "Kernel" "PASS" "KRN-07" "TTY line discipline autoload disabled" \
      "Chargement auto des disciplines TTY désactivé" "dev.tty.ldisc_autoload=0" ""
  elif [[ "$_KRN_LDISC" == "?" ]]; then
    add_result "Kernel" "PASS" "KRN-07" "ldisc autoload control not present" \
      "Contrôle ldisc absent" "dev.tty.ldisc_autoload unsupported" ""
  else
    add_result "Kernel" "WARN" "KRN-07" "TTY line discipline autoload enabled" \
      "Chargement auto des disciplines TTY activé" "dev.tty.ldisc_autoload=$_KRN_LDISC" \
      "Lets an unprivileged user load old, lightly audited TTY modules. 'sysctl -w dev.tty.ldisc_autoload=0'"
  fi

  # ── KRN-08  Kernel lockdown ──────────────────────────────────────────────────
  if [[ -r /sys/kernel/security/lockdown ]]; then
    _KRN_LOCKDOWN="$(sed -n 's/.*\[\([a-z]*\)\].*/\1/p' /sys/kernel/security/lockdown 2>/dev/null)"
    case "$_KRN_LOCKDOWN" in
      integrity|confidentiality)
        add_result "Kernel" "PASS" "KRN-08" "Kernel lockdown active" "Verrouillage noyau actif" "lockdown=$_KRN_LOCKDOWN" "" ;;
      *)
        add_result "Kernel" "WARN" "KRN-08" "Kernel lockdown off" "Verrouillage noyau inactif" "lockdown=${_KRN_LOCKDOWN:-none}" \
          "Stops even root from changing the running kernel. Enabled through Secure Boot, or 'lockdown=integrity' on the kernel command line." ;;
    esac
  else
    add_result "Kernel" "WARN" "KRN-08" "Kernel lockdown not available" "Verrouillage noyau indisponible" \
      "/sys/kernel/security/lockdown absent" "Requires a kernel built with CONFIG_SECURITY_LOCKDOWN_LSM."
  fi

  # ── KRN-09  BPF JIT hardening ────────────────────────────────────────────────
  _KRN_JIT="$(_krn_sysctl net.core.bpf_jit_harden)"
  if [[ "$_KRN_JIT" =~ ^[12]$ ]]; then
    add_result "Kernel" "PASS" "KRN-09" "BPF JIT hardening on" "Durcissement JIT BPF actif" "bpf_jit_harden=$_KRN_JIT" ""
  elif [[ "$_KRN_JIT" == "?" ]]; then
    add_result "Kernel" "PASS" "KRN-09" "BPF JIT control not present" "Contrôle JIT BPF absent" "net.core.bpf_jit_harden unsupported" ""
  else
    add_result "Kernel" "WARN" "KRN-09" "BPF JIT hardening off" "Durcissement JIT BPF inactif" "bpf_jit_harden=$_KRN_JIT" \
      "Without hardening, the JIT makes spraying code into kernel memory easier. 'sysctl -w net.core.bpf_jit_harden=2'"
  fi

  # ── KRN-10  SysRq ────────────────────────────────────────────────────────────
  _KRN_SYSRQ="$(_krn_sysctl kernel.sysrq)"
  if [[ "$_KRN_SYSRQ" == "0" || "$_KRN_SYSRQ" == "4" ]]; then
    add_result "Kernel" "PASS" "KRN-10" "SysRq restricted" "SysRq restreint" "kernel.sysrq=$_KRN_SYSRQ" ""
  else
    add_result "Kernel" "WARN" "KRN-10" "SysRq permissive" "SysRq permissif" "kernel.sysrq=${_KRN_SYSRQ/\?/unknown}" \
      "SysRq exposes kernel operations from the physical console, including a memory dump. 'sysctl -w kernel.sysrq=0' (4 keeps only the keyboard reset)."
  fi

  # ── KRN-11  Exotic filesystem modules ────────────────────────────────────────
  # Rarely used, rarely audited, historically a steady source of CVEs. Reached by
  # anyone who can plug in a USB stick or mount an image.
  _KRN_FS_LOADED=""
  for _m in cramfs freevxfs jffs2 hfs hfsplus squashfs udf ksmbd; do
    lsmod 2>/dev/null | awk '{print $1}' | grep -qx "$_m" && _KRN_FS_LOADED+="$_m "
  done
  if [[ -z "$_KRN_FS_LOADED" ]]; then
    add_result "Kernel" "PASS" "KRN-11" "No exotic filesystem modules loaded" \
      "Aucun module de système de fichiers exotique chargé" "cramfs/freevxfs/jffs2/hfs/hfsplus/udf/ksmbd absent" ""
  else
    add_result "Kernel" "WARN" "KRN-11" "Exotic filesystem modules loaded" \
      "Modules de systèmes de fichiers exotiques chargés" "loaded: ${_KRN_FS_LOADED% }" \
      "Rarely used, rarely audited, a regular source of CVEs. Add 'install <module> /bin/true' to /etc/modprobe.d/ for any you do not need."
  fi

  # ── KRN-12  Exposure summary ─────────────────────────────────────────────────
  # The point of the family, stated once: how many doorways are still open.
  # Counts the verdicts recorded above; it does not re-read a single sysctl.
  if [[ "$_KRN_DOORS_KNOWN" -eq 0 ]]; then
    add_result "Kernel" "WARN" "KRN-12" "LPE doorway status unknown" \
      "État des portes d'élévation inconnu" "no doorway control readable on this kernel" ""
  elif [[ "$_KRN_DOORS_OPEN" -eq 0 ]]; then
    add_result "Kernel" "PASS" "KRN-12" "Primary LPE doorways closed" \
      "Principales portes d'élévation fermées" "$_KRN_DOORS_KNOWN of $_KRN_DOORS_KNOWN closed" ""
  else
    add_result "Kernel" "WARN" "KRN-12" "Primary LPE doorways open" \
      "Principales portes d'élévation ouvertes" \
      "$_KRN_DOORS_OPEN of $_KRN_DOORS_KNOWN open (userns, eBPF, io_uring, userfaultfd)" \
      "These settings neutralise whole classes of exploit, with no patch and no reboot. See 'aartool surface'."
  fi
}
