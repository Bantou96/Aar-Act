# ── Kernel attack surface catalogue ──────────────────────────────────────────
# One row per doorway. The KRN-xx family in the baseline audits these; this
# catalogue is what makes them actionable, and it carries the two things an
# audit result cannot: what the mitigation costs, and whether it is safe to
# apply without knowing the workload.
#
# Fields, tab separated:
#   id | sysctl key | desired value | tier | what it closes | what it costs
#
# tier is 'safe' or 'strict'. safe means no mainstream workload is known to
# depend on it, so it can be applied on a server without a conversation.
# strict means it will break something real for somebody, and the cost column
# says what. Defaulting to safe is the difference between a tool people run and
# a tool people uninstall after it takes down their containers.
#
# scripts/tests/test_aartool.sh asserts every id here has a matching KRN check,
# so the catalogue and the audit cannot drift apart.

surface_catalogue() {
  cat <<'ROWS'
KRN-02	kernel.unprivileged_bpf_disabled	1	safe	Unprivileged eBPF, a recurring source of kernel exploits	Nothing on a server. Some eBPF observability agents run privileged anyway.
KRN-04	vm.unprivileged_userfaultfd	0	safe	userfaultfd, used to turn kernel races into reliable exploits	Nothing outside CRIU and some live-migration tooling.
KRN-06	kernel.kexec_load_disabled	1	safe	Booting an arbitrary kernel without firmware, bypassing Secure Boot	Nothing, unless you use kdump crash capture.
KRN-07	dev.tty.ldisc_autoload	0	safe	Autoloading old, lightly audited TTY line-discipline modules	Nothing on a server. Affects some serial and ham radio setups.
KRN-09	net.core.bpf_jit_harden	2	safe	JIT-sprayed code in kernel memory	A small BPF throughput cost. Irrelevant unless you run XDP at line rate.
KRN-10	kernel.sysrq	4	safe	Kernel operations from the physical console, including a memory dump	Loses SysRq except the keyboard reset combination.
KRN-01	kernel.unprivileged_userns_clone	0	strict	The doorway most published Linux LPEs walk through	Breaks rootless Docker and Podman, Chrome's sandbox, and most CI runners.
KRN-03	kernel.io_uring_disabled	2	strict	io_uring, young and disproportionately represented in recent LPEs	Breaks workloads that use it: some databases, proxies and modern async runtimes.
KRN-05	kernel.modules_disabled	1	strict	Loading a rootkit as a kernel module	Irreversible until reboot. Blocks every later modprobe, including yours.
ROWS
}

# Read a sysctl, printing '?' when the key does not exist on this kernel.
surface_read() { sysctl -n "$1" 2>/dev/null || printf '?'; }

# A key is satisfied if it already meets or exceeds the desired value. Several
# of these are "higher is stricter", so an exact match would report a machine
# that is MORE locked down than we ask as non-compliant.
surface_ok() {
  local key="$1" want="$2" have="$3"
  [[ "$have" == "?" ]] && return 2          # not present on this kernel
  case "$key" in
    kernel.unprivileged_bpf_disabled|net.core.bpf_jit_harden|kernel.io_uring_disabled)
      [[ "$have" =~ ^[0-9]+$ ]] && [[ "$have" -ge "$want" ]] ;;
    kernel.sysrq)
      # 0 is stricter than 4; anything else is permissive.
      [[ "$have" == "0" || "$have" == "4" ]] ;;
    user.max_user_namespaces|kernel.unprivileged_userns_clone|vm.unprivileged_userfaultfd)
      [[ "$have" == "0" ]] ;;
    *)
      [[ "$have" == "$want" ]] ;;
  esac
}

# Debian and Ubuntu expose the user namespace switch under a different key from
# the RHEL family. Resolve it per machine rather than guessing from /etc/os-release,
# which is wrong on derivatives.
surface_userns_key() {
  if [[ -e /proc/sys/kernel/unprivileged_userns_clone ]]; then
    printf 'kernel.unprivileged_userns_clone'
  else
    printf 'user.max_user_namespaces'
  fi
}
