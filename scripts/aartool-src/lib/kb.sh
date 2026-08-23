# ── Knowledge base ───────────────────────────────────────────────────────────
# An audit result tells you a setting is wrong. It does not tell you what an
# attacker does with it, what you lose by changing it, or whether it is the
# thing to fix first. Operators fill that in from memory, or they don't, and
# a report with forty findings and no ordering gets read once and filed.
#
# These entries carry the three things the check line cannot fit:
#   - the concrete path from the finding to a compromised machine
#   - the honest cost of closing it, including what it breaks
#   - where it sits relative to the other findings
#
# Not every ID has an entry. `explain` falls back to the remediation map, which
# covers 99 of 109, so the command always answers. Entries are written where
# knowing the mechanism changes what a reasonable person decides to do.
#
# scripts/tests/test_aartool.sh asserts every ID named here exists as a real
# check, so this file cannot drift into documenting things that do not exist.

kb_ids() {
  cat <<'IDS'
KRN-01 KRN-02 KRN-03 KRN-04 KRN-05 KRN-06 KRN-07 KRN-08 KRN-09 KRN-10 KRN-11 KRN-12
SSH-01 SSH-02 SSH-03 SSH-09 SSH-10 SSH-11 SSH-13
AUTH-04 AUTH-09 AUTH-11 AUTH-15
SYS-03 SYS-04 SYS-05 SYS-11
NET-01 NET-02 NET-05
LOG-01 LOG-04 LOG-08
FS-01 FS-05 FS-06 FS-07
IDS
}

kb_has() { kb_ids | tr ' ' '\n' | grep -qx "$1"; }

# One entry. Sections are fixed so the output is skimmable and greppable:
# WHAT / WHY / COST / BY HAND / WITH AARTOOL / MORE.
kb_entry() {
  case "$1" in

  KRN-01) cat <<'E'
WHAT
  Whether an unprivileged user can create a user namespace, which hands them
  CAP_SYS_ADMIN inside it. Debian and Ubuntu expose this as
  kernel.unprivileged_userns_clone; the RHEL family uses user.max_user_namespaces.

WHY
  This is the doorway most published Linux privilege escalations walk through.
  The exploit rarely attacks the kernel directly from an unprivileged context.
  It creates a user namespace, becomes root inside it, and from there reaches
  subsystems that check for CAP_SYS_ADMIN and nothing else: nftables, OverlayFS,
  io_uring, netfilter. CVE-2022-0185, CVE-2023-0386 and CVE-2023-32233 all take
  this shape. Closing it does not patch those bugs, it removes the step that
  makes them reachable by a normal user.

COST
  Real, and you must decide. This breaks rootless Docker and Podman, Chrome's
  and Firefox's sandboxes, most CI runners, snap confinement, and bubblewrap.
  On a database or an appliance server, nothing notices. On a build host, it
  takes the build host down.

BY HAND
  # Debian / Ubuntu
  echo 'kernel.unprivileged_userns_clone = 0' > /etc/sysctl.d/99-userns.conf
  # RHEL 9 family
  echo 'user.max_user_namespaces = 0' > /etc/sysctl.d/99-userns.conf
  sysctl --system

WITH AARTOOL
  Off by default, deliberately: a role that silently breaks rootless containers
  gets disabled wholesale, and then none of the safe settings apply either.
  Opt in per host or group:
    linux_kernel_restrict_userns: true
  then:  aartool apply --target HOST --user USER --only kernel

MORE
  If you cannot close it, the mitigations that still help are a current kernel,
  seccomp on anything that accepts untrusted input, and Lockdown mode. Check
  first whether anything is actually using it:
    find /proc/*/ns/user -newer /proc/1/ns/user 2>/dev/null | head
E
  ;;

  KRN-02) cat <<'E'
WHAT
  kernel.unprivileged_bpf_disabled. Whether a user without CAP_BPF can load an
  eBPF program.

WHY
  eBPF is a verifier standing between user-supplied bytecode and the kernel's
  own address space. Verifier bugs are frequent and each one is a direct
  arbitrary-read or arbitrary-write in kernel memory: CVE-2021-3490,
  CVE-2021-33200, CVE-2022-23222. Unprivileged eBPF gives every local account a
  path to that verifier.

COST
  On a server, nothing. Observability agents that use eBPF (Falco, Cilium,
  Pixie, bpftrace) already run privileged and are unaffected. Value 2 also
  disables the JIT for unprivileged programs and cannot be lowered again
  without a reboot.

BY HAND
  echo 'kernel.unprivileged_bpf_disabled = 1' > /etc/sysctl.d/99-bpf.conf
  sysctl --system

WITH AARTOOL
  Applied by default (safe tier):
    aartool apply --target HOST --user USER --only kernel

MORE
  Ubuntu has shipped this on by default since 20.10. Finding it at 0 usually
  means something set it back, which is worth understanding before you change it.
E
  ;;

  KRN-03) cat <<'E'
WHAT
  kernel.io_uring_disabled. Whether io_uring rings can be created, and by whom.
  0 = anyone, 1 = only with CAP_SYS_ADMIN, 2 = nobody.

WHY
  io_uring is the youngest large syscall surface in the kernel and is
  disproportionately represented in recent local privilege escalations. Google
  reported it in roughly 60 percent of the kernel exploits submitted to its own
  bug bounty in one period, and disabled it across ChromeOS, Android and its
  production fleet. It also bypasses most seccomp filters, because the work is
  submitted through a ring rather than through the syscalls a filter watches:
  a sandbox that blocks openat does not block an io_uring open.

COST
  Real. It breaks anything that uses it, and adoption is growing: recent
  PostgreSQL and MySQL builds, some proxies, Rust and Go async runtimes,
  and modern container runtimes. Test before you set 2.

BY HAND
  echo 'kernel.io_uring_disabled = 2' > /etc/sysctl.d/99-iouring.conf
  sysctl --system
  # Requires a kernel with the knob: 6.6+, or a distro backport.

WITH AARTOOL
  Off by default. Opt in:
    linux_kernel_restrict_io_uring: true
  then:  aartool apply --target HOST --user USER --only kernel

MORE
  Check whether anything is using it before deciding:
    grep -l io_uring /proc/*/maps 2>/dev/null | head
  Value 1 is the middle ground: privileged callers keep it, everyone else
  loses it, and most of the exploit value goes with them.
E
  ;;

  KRN-04) cat <<'E'
WHAT
  vm.unprivileged_userfaultfd. Whether an unprivileged process can handle its
  own page faults in userspace.

WHY
  userfaultfd rarely is the bug. It is what makes the bug reliable. A kernel
  use-after-free or double-free usually has a race window measured in
  microseconds; userfaultfd lets an attacker stop the kernel mid-operation, at
  a page fault of their choosing, and hold it there for as long as they need to
  groom the heap. It turns a flaky proof of concept into a dependable exploit.
  It shows up in the write-ups for CVE-2022-2588, CVE-2023-3269 and many others.

COST
  Effectively none on a server. CRIU checkpoint/restore uses it, as do some
  live-migration and userspace-paging systems. If you do not run those, nothing
  changes.

BY HAND
  echo 'vm.unprivileged_userfaultfd = 0' > /etc/sysctl.d/99-uffd.conf
  sysctl --system

WITH AARTOOL
  Applied by default (safe tier):
    aartool apply --target HOST --user USER --only kernel

MORE
  This is the highest ratio of exploit reliability removed to workload broken
  in the whole KRN family. If you only change one thing here, change this one.
E
  ;;

  KRN-05) cat <<'E'
WHAT
  kernel.modules_disabled. Once set to 1, no further kernel module can be
  loaded until reboot.

WHY
  Loadable modules are how a kernel rootkit installs itself. An attacker who
  reaches root and wants to stay wants a module: it survives your process
  hunting, hides its own files and connections, and outlives anything you do in
  userspace. Setting this closes that door for the rest of the uptime.

COST
  Irreversible until reboot, and it blocks every later modprobe, including
  yours. Anything that loads modules on demand fails after this point: mounting
  an unusual filesystem, plugging in hardware, starting a VPN whose module is
  not already loaded, some container network drivers.

BY HAND
  # Load everything you need FIRST, then:
  sysctl -w kernel.modules_disabled=1
  # As a boot-time setting, it must run last:
  echo 'kernel.modules_disabled = 1' > /etc/sysctl.d/99-zz-modules.conf

WITH AARTOOL
  Off by default. Opt in only on appliances with a fixed hardware and network
  profile:
    linux_kernel_lock_modules: true
  then:  aartool apply --target HOST --user USER --only kernel

MORE
  A softer alternative that keeps modprobe working is module signature
  enforcement (module.sig_enforce=1 on the kernel command line) plus Secure
  Boot, so only modules signed by a key in the MOK database load. See SYS-08.
E
  ;;

  KRN-06) cat <<'E'
WHAT
  kernel.kexec_load_disabled. Whether kexec can load a replacement kernel.

WHY
  kexec boots a kernel image directly, skipping firmware. That skips Secure
  Boot verification with it. An attacker at root can kexec into a kernel they
  control, and every measurement your firmware made becomes meaningless. It is
  also a clean way to destroy volatile evidence: memory is gone and the machine
  looks like it rebooted normally.

COST
  Nothing, unless you use kdump crash capture, which is built on kexec. If
  kdump is enabled, decide which you want.

BY HAND
  echo 'kernel.kexec_load_disabled = 1' > /etc/sysctl.d/99-kexec.conf
  sysctl --system
  # One-way until reboot, like modules_disabled.

WITH AARTOOL
  Applied by default (safe tier):
    aartool apply --target HOST --user USER --only kernel

MORE
  systemctl is-active kdump  # check before applying on RHEL
E
  ;;

  KRN-07) cat <<'E'
WHAT
  dev.tty.ldisc_autoload. Whether an unprivileged ioctl can make the kernel
  load a TTY line discipline module on demand.

WHY
  There are around thirty line-discipline drivers in the tree. Several date to
  the 1990s, are maintained by nobody, and have never been fuzzed seriously.
  With autoload on, any user can reach all of them with one ioctl. This is how
  CVE-2017-2636 (n_hdlc) and CVE-2020-14386 were reached. Turning autoload off
  does not remove the code, it removes the unprivileged path to it.

COST
  Nothing on a server. Serial console setups, SLIP/PPP and ham radio (AX.25)
  configurations may need a specific discipline, which you can load explicitly
  at boot instead.

BY HAND
  echo 'dev.tty.ldisc_autoload = 0' > /etc/sysctl.d/99-ldisc.conf
  sysctl --system

WITH AARTOOL
  Applied by default (safe tier):
    aartool apply --target HOST --user USER --only kernel

MORE
  Cheapest item in the family: a large, ancient attack surface removed at
  essentially zero operational cost.
E
  ;;

  KRN-08) cat <<'E'
WHAT
  Kernel lockdown mode, read from /sys/kernel/security/lockdown. States are
  none, integrity and confidentiality.

WHY
  Lockdown draws a line that UID 0 alone does not: it stops root from modifying
  the running kernel. integrity blocks writes to /dev/mem, unsigned module
  loading, and raw PCI and MSR access. confidentiality additionally blocks
  reading kernel memory, so /proc/kcore and kprobes go too. Without it, root
  and ring 0 are the same privilege, and a compromised root account can install
  something your userspace tooling will never see.

COST
  integrity breaks unsigned out-of-tree modules, which in practice means NVIDIA,
  VirtualBox and ZFS builds unless they are signed for your MOK.
  confidentiality additionally breaks most kernel debugging and some profilers.

BY HAND
  Lockdown is not a sysctl. It is enabled at boot, and only meaningfully with
  Secure Boot on:
    # add to GRUB_CMDLINE_LINUX in /etc/default/grub
    lockdown=integrity
    grub2-mkconfig -o /boot/grub2/grub.cfg   # RHEL
    update-grub                              # Debian / Ubuntu

WITH AARTOOL
  No role applies this. It is a boot parameter with a firmware dependency, and
  a playbook that edits the kernel command line on a machine it cannot reach
  the console of is a way to lose the machine. aartool reports it and leaves
  the change to you.

MORE
  Under Secure Boot, most distributions enable lockdown=integrity automatically.
  Finding it at none on a Secure Boot machine means something turned it off.
E
  ;;

  KRN-09) cat <<'E'
WHAT
  net.core.bpf_jit_harden. Whether the eBPF JIT blinds constants and randomises
  its output. 0 = off, 1 = for unprivileged, 2 = for everyone.

WHY
  The JIT writes attacker-influenced constants into executable kernel memory.
  Without blinding, an attacker encodes a short instruction sequence as a
  constant in a BPF program, and the JIT faithfully emits it into a page the
  kernel will execute: JIT spraying. Blinding splits each constant across
  instructions so the encoding cannot survive.

COST
  A measurable but small BPF throughput cost. Irrelevant unless you are running
  XDP at line rate, in which case measure it. Value 2 covers privileged
  programs too, which matters because a compromised privileged agent is exactly
  the case you are defending against.

BY HAND
  echo 'net.core.bpf_jit_harden = 2' > /etc/sysctl.d/99-bpf.conf
  sysctl --system

WITH AARTOOL
  Applied by default (safe tier):
    aartool apply --target HOST --user USER --only kernel

MORE
  Redundant if KRN-02 is set to 2, which disables the JIT for unprivileged
  callers outright. Set both: they cover different callers.
E
  ;;

  KRN-10) cat <<'E'
WHAT
  kernel.sysrq. Which magic SysRq key operations the kernel will honour.

WHY
  SysRq is a debugging interface that runs in kernel context and ignores
  permissions. The dangerous ones are not the reboot: it can dump memory, kill
  every process, remount everything read-only, and drop to a kernel debugger.
  It is reachable from the physical console and, on many systems, by writing to
  /proc/sysrq-trigger. On a hosted or colocated machine, "physical console"
  means anyone with the out-of-band management credentials.

COST
  Small. Value 4 keeps the keyboard-only subset, which is the one that gets a
  hung machine down cleanly. 0 disables everything, including that.

BY HAND
  echo 'kernel.sysrq = 4' > /etc/sysctl.d/99-sysrq.conf
  sysctl --system

WITH AARTOOL
  Applied by default (safe tier), value 4:
    aartool apply --target HOST --user USER --only kernel

MORE
  aartool accepts either 0 or 4 as compliant. 0 is stricter; 4 is the value
  most operations teams can actually live with.
E
  ;;

  KRN-11) cat <<'E'
WHAT
  Whether rarely used filesystem and network protocol modules are blacklisted:
  cramfs, freevxfs, jffs2, hfs, hfsplus, squashfs, udf, dccp, sctp, rds, tipc.

WHY
  These are drivers almost nobody uses and almost nobody audits, and they are
  reachable without privileges. A filesystem driver parses attacker-controlled
  bytes the moment a user mounts an image or plugs in a device; a protocol
  driver parses attacker-controlled packets. CVE-2021-27365 (iSCSI),
  CVE-2022-2588 (route4) and the long line of DCCP and SCTP bugs are all in
  this category. If you do not use them, having them loadable is pure downside.

COST
  Nothing, provided you actually do not use them. squashfs matters if you use
  snap packages or container images that mount squashfs layers. Check before
  blacklisting that one.

BY HAND
  cat > /etc/modprobe.d/99-cis-blacklist.conf <<'EOF'
  install cramfs /bin/false
  install freevxfs /bin/false
  install jffs2 /bin/false
  install hfs /bin/false
  install hfsplus /bin/false
  install udf /bin/false
  install dccp /bin/false
  install sctp /bin/false
  install rds /bin/false
  install tipc /bin/false
  EOF

WITH AARTOOL
  Applied by default:
    aartool apply --target HOST --user USER --only kernel,sysctl

MORE
  blacklist alone is not enough: it only stops autoload by alias, not an
  explicit modprobe. install ... /bin/false is what actually blocks it.
E
  ;;

  KRN-12) cat <<'E'
WHAT
  A summary, not a separate setting. It counts how many of KRN-01 to KRN-11 are
  closed and reports the attack surface as a whole.

WHY
  The individual findings are each defensible to ignore. The aggregate is the
  thing worth looking at: a machine with every doorway open is one kernel CVE
  away from local root, and the next one is always weeks away. This line is
  what you put in front of someone who has to approve the change.

COST
  None. It changes nothing.

BY HAND
  aartool surface

WITH AARTOOL
  aartool surface            # what is open, what it costs to close
  aartool surface --strict   # include the three that break things

MORE
  KRN-12 counts recorded verdicts rather than re-reading the sysctls, so it
  cannot disagree with the checks above it. That was a real bug once.
E
  ;;

  SSH-01) cat <<'E'
WHAT
  PermitRootLogin in sshd_config.

WHY
  Root is the one username an attacker never has to guess. Leaving it able to
  log in halves the work of every credential attack against the host, and it
  destroys attribution: three admins sharing root produce a log that says root
  did it, which is useless during an incident and fails every audit that asks
  who made a change.

COST
  You need a working non-root account with sudo BEFORE you apply this, and you
  need to have tested it. This is the single most common way to lock yourself
  out of a machine.

BY HAND
  # verify first, in another session that stays open:
  ssh admin@host sudo -n true
  # then:
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool plan  --target HOST --user USER --only ssh    # preview
  aartool apply --target HOST --user USER --only ssh

MORE
  prohibit-password is also accepted: root keys work, root passwords do not.
  Use it where automation still needs root, then remove it.
E
  ;;

  SSH-02) cat <<'E'
WHAT
  PasswordAuthentication in sshd_config.

WHY
  With passwords on, your exposure is the weakest password on the machine and
  the internet gets unlimited attempts at it. Every honeypot dataset says the
  same thing: an SSH port reachable from the internet sees thousands of
  credential attempts a day within hours of opening. Key-only authentication
  removes the entire class.

COST
  Every account that needs to log in must have a key installed first. Miss one
  and that user is locked out. Check who would lose access:
    for u in $(awk -F: '$3>=1000 && $7!~/nologin|false/{print $1}' /etc/passwd); do
      [ -s "/home/$u/.ssh/authorized_keys" ] || echo "NO KEY: $u"
    done

BY HAND
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh

MORE
  Also set KbdInteractiveAuthentication no. On many builds it is a second path
  to the same password prompt, and turning off only the first one leaves the
  door open. aartool's ssh role sets both.
E
  ;;

  SSH-03) cat <<'E'
WHAT
  MaxAuthTries: how many authentication attempts one TCP connection gets.

WHY
  The default of 6 lets an attacker try six passwords per connection, which
  multiplies whatever connection rate they can sustain. Lowering it to 3 or 4
  is a rate limit that costs nothing.

COST
  One that catches people out: ssh offers every key in your agent, and each
  offer counts as an attempt. An operator with eight keys loaded fails to
  authenticate before reaching the right one, and fail2ban bans them. Use
  IdentitiesOnly=yes with an explicit -i.

BY HAND
  sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh

MORE
  Pair it with fail2ban, which turns repeated failures into a block rather
  than an unlimited retry budget.
E
  ;;

  SSH-13) cat <<'E'
WHAT
  The key exchange, cipher and MAC algorithms sshd will negotiate.

WHY
  OpenSSH still offers legacy algorithms for compatibility. Some are broken
  outright (CBC ciphers with the standard MAC construction, hmac-md5,
  hmac-sha1-96, diffie-hellman-group1-sha1 at 1024 bits). An attacker who can
  see or modify the traffic downgrades the negotiation to whichever weak
  algorithm both ends still accept, so offering them at all is the exposure.

COST
  Clients older than roughly 2014 stop connecting. In practice this means
  legacy network appliances, some Java SSH libraries, and old jump boxes. Check
  what is actually connecting before you cut:
    grep 'Accepted' /var/log/auth.log | awk '{print $NF}' | sort -u

BY HAND
  cat >> /etc/ssh/sshd_config <<'EOF'
  KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512
  Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
  MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
  EOF
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh

MORE
  On RHEL 9 the system-wide crypto policy may override sshd_config. See
  SYS/crypto checks and update-crypto-policies --set DEFAULT:NO-SHA1.
E
  ;;

  SSH-10) cat <<'E'
WHAT
  Banner in sshd_config, and the contents of /etc/issue.net.

WHY
  This one is legal, not technical, and it is the reason it is in every
  benchmark. In several jurisdictions a prosecution for unauthorised access is
  materially harder if the system never stated that access was restricted. It
  is also the control an ISO 27001 or PCI auditor checks in about four seconds,
  because it is trivially verifiable.

COST
  None, with one caveat: the banner must not name the operating system,
  version, hostname or organisation contact details. A banner that helpfully
  says "Ubuntu 22.04 LTS - contact ops@example.com" is reconnaissance you
  published yourself.

BY HAND
  cat > /etc/issue.net <<'EOF'
  Authorised access only. All activity is monitored and recorded.
  Disconnect immediately if you are not an authorised user.
  EOF
  sed -i 's|^#*Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh,banner

MORE
  Have your legal or compliance owner approve the wording once, then apply the
  same text estate-wide. Set DebianBanner no as well, so the version string is
  not leaked in the protocol handshake before the banner is ever shown.
E
  ;;

  SSH-11) cat <<'E'
WHAT
  ClientAliveInterval and ClientAliveCountMax: when sshd drops an idle session.

WHY
  The threat is an unattended authenticated session, not a network problem. An
  admin who walks away from an unlocked laptop with an open root session has
  handed over the machine to anyone who sits down. It also bounds how long a
  hijacked session stays useful after the operator's connection is gone.

COST
  Long-running interactive jobs die when the session is dropped. The answer is
  tmux or screen, not a longer timeout, and telling people that is part of
  applying this.

BY HAND
  cat >> /etc/ssh/sshd_config <<'EOF'
  ClientAliveInterval 300
  ClientAliveCountMax 0
  EOF
  sshd -t && systemctl reload sshd

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh

MORE
  ClientAliveCountMax 0 means one missed interval ends the session, so the
  interval is the timeout. This is server-side and cannot be overridden by the
  client, unlike a shell TMOUT (see AUTH-10).
E
  ;;

  AUTH-04) cat <<'E'
WHAT
  The minimum password length pam_pwquality enforces: minlen in
  /etc/security/pwquality.conf. The check wants 12 or more.

WHY
  Length is the setting that actually helps, and NIST SP 800-63B now recommends
  it over forced character classes precisely because it survives contact with
  users. A 12-character passphrase resists offline cracking of a stolen shadow
  file for orders of magnitude longer than an 8-character one with a digit and
  a symbol bolted on.

  Two neighbours matter as much and are separate checks. First, the hashing
  algorithm: if /etc/shadow still holds md5 or a low
  round count, a stolen shadow file is cracked in hours rather than years.
  Second, remember=N, which stops the rotation theatre where a forced change
  becomes Password1 to Password2 and back.

COST
  Rules that are too aggressive produce passwords on sticky notes. NIST
  SP 800-63B now recommends length and a breached-password check over forced
  character classes. Length is the setting that actually helps.

BY HAND
  # /etc/security/pwquality.conf
  minlen = 14
  dcredit = -1
  ucredit = -1
  ocredit = -1
  lcredit = -1
  # /etc/pam.d/common-password (Debian) or via authselect (RHEL)
  password requisite pam_pwquality.so retry=3
  password required  pam_pwhistory.so remember=5
  # verify the hash in use:
  awk -F: '$2 ~ /^\$/ {print $1, substr($2,1,3)}' /etc/shadow   # want $6 or $y

WITH AARTOOL
  aartool apply --target HOST --user USER --only auth,pam

MORE
  Editing PAM by hand is the classic way to lock everyone out of a machine.
  Keep a root session open in another terminal until you have tested a login.
  On RHEL 9, edit through authselect rather than the files directly.
E
  ;;

  AUTH-09) cat <<'E'
WHAT
  pam_faillock: whether repeated failed logins lock the account.

WHY
  Without it, local and console authentication has no rate limit at all.
  fail2ban watches SSH; it does not watch su, sudo, the console, or a display
  manager. Faillock is the control that covers those.

COST
  It creates a denial of service you did the work for: an attacker who knows a
  username can lock it out on purpose. Never apply an unlock_time of 0
  (permanent) to accounts you rely on, and always exempt root
  (even_deny_root off) unless you have out-of-band console access.

BY HAND
  # /etc/security/faillock.conf
  deny = 5
  unlock_time = 900
  fail_interval = 900
  # inspect and clear:
  faillock --user alice
  faillock --user alice --reset

WITH AARTOOL
  aartool apply --target HOST --user USER --only auth,pam

MORE
  15 minutes stops password guessing dead while keeping a locked-out colleague
  productive after a coffee. Permanent lockouts generate helpdesk tickets, not
  security.
E
  ;;

  AUTH-11) cat <<'E'
WHAT
  Every account in /etc/passwd whose UID is 0.

WHY
  There should be exactly one, and it should be root. A second UID 0 account is
  a textbook persistence mechanism: it is root, it does not look like root in
  the logs, and it survives a password change on the real root account. It is
  also easy to create accidentally with a mistyped useradd -u.

COST
  None to check. Before deleting one, find out what it is. Some appliance
  vendors legitimately ship a second UID 0 account, and removing it breaks
  their support tooling.

BY HAND
  awk -F: '$3==0 {print $1}' /etc/passwd      # expect exactly: root
  # if there is another, find out who made it and when:
  grep -E 'useradd|usermod' /var/log/auth.log /var/log/secure 2>/dev/null
  # then, once you are sure:
  userdel -r suspicious_account

WITH AARTOOL
  aartool inspect          # reports it
  The roles do not delete accounts. Deleting a UID 0 account on the strength of
  a scan, without knowing what it is, is how a playbook takes down an estate.

MORE
  Extend the same check to sudoers: a NOPASSWD:ALL entry is UID 0 by another
  route. grep -r NOPASSWD /etc/sudoers /etc/sudoers.d/
E
  ;;

  AUTH-15) cat <<'E'
WHAT
  Defaults use_pty in the sudoers file.

WHY
  Without a pty, a program run under sudo shares the terminal of the calling
  user. A compromised unprivileged process can then inject characters into that
  terminal with the TIOCSTI ioctl and have them executed as root after sudo
  returns. use_pty gives the privileged command its own pty, which severs that
  channel. It is also a precondition for usable sudo session logging.

COST
  Almost none. A small number of programs that expect to inherit the exact
  terminal misbehave, mostly interactive full-screen tools invoked in unusual
  ways.

BY HAND
  visudo    # never edit /etc/sudoers with a plain editor
  # add:
  Defaults use_pty
  Defaults logfile="/var/log/sudo.log"

WITH AARTOOL
  aartool apply --target HOST --user USER --only sudo

MORE
  Modern kernels also offer dev.tty.legacy_tiocsti=0, which removes the ioctl
  entirely. Set both: use_pty covers the sudo path, the sysctl covers the rest.
E
  ;;

  SYS-03) cat <<'E'
WHAT
  Whether security updates install automatically: dnf-automatic on RHEL,
  unattended-upgrades on Debian and Ubuntu.

WHY
  The window between a public exploit and a compromise is now measured in
  hours, and nobody patches a fleet by hand at that pace. Every large breach
  post-mortem that names a patch names one that was available and not applied.
  Automatic security updates are the single highest-value item in this entire
  report, and the one most often argued away.

COST
  The real objection is an unattended change breaking a service, so configure
  it honestly: security repository only, not everything; a fixed maintenance
  window; and mail on failure so a silent breakage does not go unnoticed for
  months.

BY HAND
  # RHEL
  dnf install -y dnf-automatic
  sed -i 's/^upgrade_type.*/upgrade_type = security/'   /etc/dnf/automatic.conf
  sed -i 's/^apply_updates.*/apply_updates = yes/'      /etc/dnf/automatic.conf
  systemctl enable --now dnf-automatic.timer
  # Debian / Ubuntu
  apt install -y unattended-upgrades
  dpkg-reconfigure -plow unattended-upgrades

WITH AARTOOL
  aartool apply --target HOST --user USER --only updates,patching

MORE
  Installing the update is not the same as running it. A kernel update sits in
  /boot doing nothing until reboot: that is SYS-11, and it is a separate
  problem with a separate answer.
E
  ;;

  SYS-04) cat <<'E'
WHAT
  SELinux on RHEL, AppArmor on Ubuntu and Debian: whether mandatory access
  control is enforcing.

WHY
  Discretionary permissions ask who owns the file. Mandatory access control
  asks what this program is allowed to do at all, and that is the difference
  between a web server bug and a compromised machine. When your httpd is
  exploited, SELinux is the reason the shell it spawns cannot read /etc/shadow
  or open an outbound connection. It is the highest-value control on the list
  after patching, and the one most often set to permissive during an
  installation and never set back.

COST
  Denials, which is the point. Run in permissive first, collect what would have
  been blocked, fix the labels, then enforce. Do not enable it blind on a
  production machine.

BY HAND
  # RHEL
  getenforce
  ausearch -m AVC -ts recent      # what would break
  setenforce 1                    # this boot
  sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config   # persistent
  # Ubuntu / Debian
  aa-status
  aa-enforce /etc/apparmor.d/*

WITH AARTOOL
  aartool apply --target HOST --user USER --only mac

MORE
  A relabel may be required after switching from disabled: touch /.autorelabel
  and reboot. It takes a while and the machine is unavailable during it, so
  schedule it.
E
  ;;

  SYS-05) cat <<'E'
WHAT
  Whether processes can write core dumps: fs.suid_dumpable, the hard core limit,
  and the systemd-coredump configuration.

WHY
  A core dump is the process's memory written to disk, which means private keys,
  session tokens, decrypted secrets and passwords in cleartext, in a file that
  frequently ends up world-readable or shipped to a crash reporting service. It
  is one of the most reliable ways to get credentials off a machine without
  exploiting anything at all.

COST
  You lose crash forensics. On a server running packaged software that is
  usually fine. If you are debugging your own binaries, keep dumps but restrict
  the storage path to root and make sure it is not on a shared or backed-up
  volume.

BY HAND
  echo 'fs.suid_dumpable = 0' > /etc/sysctl.d/99-coredump.conf
  echo '* hard core 0'        > /etc/security/limits.d/99-coredump.conf
  # systemd
  mkdir -p /etc/systemd/coredump.conf.d
  printf '[Coredump]\nStorage=none\nProcessSizeMax=0\n' \
    > /etc/systemd/coredump.conf.d/99-disable.conf
  sysctl --system && systemctl daemon-reload

WITH AARTOOL
  aartool apply --target HOST --user USER --only kernel,coredump

MORE
  Check for dumps already on disk before you consider this closed:
    coredumpctl list 2>/dev/null; ls -l /var/lib/systemd/coredump/ 2>/dev/null
E
  ;;

  SYS-11) cat <<'E'
WHAT
  Whether the running kernel is the newest one installed. A pending reboot.

WHY
  This is the finding people dismiss and should not. The update is applied, the
  package manager reports success, the scanner that reads package versions says
  patched, and the machine is running the vulnerable kernel it booted weeks ago
  and will keep running it until someone reboots. Every kernel CVE you patched
  since the last boot is still live.

COST
  A reboot, which on a clustered service is an orchestration problem rather
  than a configuration one: quorum, leader election, shard allocation, VRRP
  ownership. That is precisely why it gets deferred indefinitely.

BY HAND
  uname -r                                     # running
  rpm -q kernel --last | head -1               # RHEL: newest installed
  ls -t /boot/vmlinuz-* | head -1              # Debian / Ubuntu
  # and check whether anything else is waiting:
  needs-restarting -r 2>/dev/null || cat /var/run/reboot-required 2>/dev/null

WITH AARTOOL
  No role fixes this, and the remediation map says so explicitly. The roles
  named against SYS-11 only decide who owns future reboots; they do not
  activate the kernel already sitting in /boot.

MORE
  Reboot one node at a time, verify the cluster is healthy between each, and
  make the verification a gate rather than a glance. If your check queries the
  node you just rebooted, it is not a check.
E
  ;;

  NET-01) cat <<'E'
WHAT
  Whether a host firewall is present and default-deny on inbound: firewalld on
  RHEL, ufw or nftables on Debian and Ubuntu.

WHY
  A cloud or perimeter firewall filters one interface. It does not filter the
  private network, the VPN, the container bridge, or anything else that reaches
  the host by another path, and it does not exist at all once an attacker is
  inside the same segment. The host firewall is the only one that sees every
  packet that arrives.

COST
  The obvious one: lock yourself out by enabling default-deny before allowing
  SSH. Always add the SSH rule first, in the same command sequence, and keep a
  second session open.

BY HAND
  # RHEL
  systemctl enable --now firewalld
  firewall-cmd --set-default-zone=drop
  firewall-cmd --permanent --add-service=ssh && firewall-cmd --reload
  # Ubuntu / Debian
  ufw allow OpenSSH        # FIRST
  ufw default deny incoming
  ufw enable

WITH AARTOOL
  aartool plan  --target HOST --user USER --only firewall   # read this one
  aartool apply --target HOST --user USER --only firewall

MORE
  Docker writes its own rules and bypasses ufw entirely: a published container
  port is reachable even when ufw says deny. Filter Docker traffic in the
  DOCKER-USER chain, not in ufw.
E
  ;;

  NET-02) cat <<'E'
WHAT
  IP forwarding and the redirect and source-route sysctls: whether this host
  will route packets that are not addressed to it.

WHY
  A host that forwards is a bridge between segments, and an attacker who lands
  on it inherits that bridge. Accepted ICMP redirects let anyone on the local
  network rewrite your routing table; accepted source routing lets a remote
  attacker choose the return path and defeat filters that assume packets come
  back the way they left.

COST
  This is the check that breaks things silently, so read before applying:
  ip_forward=0 stops Docker container networking, every NAT gateway, every
  VPN concentrator and every Kubernetes node from working. If the host is any
  of those, forwarding must stay on and the finding is expected.

BY HAND
  cat > /etc/sysctl.d/99-net.conf <<'EOF'
  net.ipv4.ip_forward = 0
  net.ipv4.conf.all.accept_redirects = 0
  net.ipv4.conf.all.secure_redirects = 0
  net.ipv4.conf.all.send_redirects = 0
  net.ipv4.conf.all.accept_source_route = 0
  net.ipv4.conf.all.rp_filter = 1
  net.ipv4.conf.all.log_martians = 1
  EOF
  sysctl --system

WITH AARTOOL
  The role has a variable for exactly this case. On a router, gateway or
  container host set:
    linux_ip_forwarding_enabled: true
  so the redirect and source-route settings are still applied and only
  ip_forward is left alone.
    aartool apply --target HOST --user USER --only network

MORE
  Turning ip_forward off on a Docker host takes container networking down
  immediately and the cause is not obvious from the symptom. Check first:
    docker info >/dev/null 2>&1 && echo "container host: leave ip_forward on"
E
  ;;

  LOG-01) cat <<'E'
WHAT
  Whether auditd is installed, running, and has rules loaded.

WHY
  Nothing else on a Linux host records who ran what. syslog records what
  services chose to say about themselves, which is not the same thing and is
  not what an incident responder needs. Without auditd there is no answer to
  "what did the attacker do after they got in", and reconstructing an incident
  becomes guesswork. This is also the control every certification asks for by
  name.

COST
  Disk and I/O. A busy machine with aggressive rules generates gigabytes a day,
  and the default max_log_file_action can fill a partition. Size it, put
  /var/log/audit on its own volume, and ship logs off the host.

BY HAND
  systemctl enable --now auditd
  auditctl -l | wc -l          # 0 means it is running and watching nothing
  augenrules --load
  # minimum useful rules:
  -w /etc/passwd -p wa -k identity
  -w /etc/shadow -p wa -k identity
  -w /etc/sudoers -p wa -k scope
  -w /var/log/sudo.log -p wa -k actions
  -a always,exit -F arch=b64 -S execve -F euid=0 -k rootcmd

WITH AARTOOL
  aartool apply --target HOST --user USER --only audit

MORE
  A running auditd with no rules is the failure mode to watch for: every
  service check goes green and nothing is recorded. auditctl -l is the check
  that actually tells you.
E
  ;;

  LOG-08) cat <<'E'
WHAT
  Whether logs are shipped off the host, and whether local logs are persistent
  and access-restricted.

WHY
  The first thing a competent intruder does after getting root is edit the
  logs. Local logs are evidence you have handed the attacker write access to.
  Remote logs are the copy they cannot reach. On systemd machines there is a
  second failure: with journald Storage=volatile, which is still the default on
  some minimal images, the entire journal is in memory and a reboot erases it.

COST
  A log destination to run and keep available, plus the bandwidth. If the
  remote endpoint is down, decide in advance whether the host queues or drops,
  and make sure a full queue cannot fill the disk.

BY HAND
  # persist the journal
  mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal
  sed -i 's/^#*Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
  systemctl restart systemd-journald
  # forward (rsyslog)
  echo '*.* @@logs.example.internal:6514' > /etc/rsyslog.d/99-remote.conf
  systemctl restart rsyslog

WITH AARTOOL
  aartool apply --target HOST --user USER --only logging,journald

MORE
  Test it properly rather than assuming: logger "aartool test $(date +%s)"
  and then confirm the line arrived at the collector. A forwarding rule that
  silently fails looks identical to one that works.
E
  ;;

  FS-06) cat <<'E'
WHAT
  Mount options on /tmp, /var/tmp and /dev/shm: nodev, nosuid and noexec.

WHY
  These are the directories any user can write to, which makes them where a
  payload lands. noexec means the dropped binary will not run from there;
  nosuid means a setuid binary copied there does not keep its privilege. It
  does not stop a determined attacker, who can copy elsewhere or use an
  interpreter, but it breaks a large fraction of automated tooling that assumes
  /tmp is executable.

COST
  Real and easily overlooked. Package managers and installers extract to /tmp
  and execute from it: some dnf and apt operations, most vendor install
  scripts, Java's temporary native library extraction, and several databases.
  Expect to whitelist something.

BY HAND
  # /etc/fstab
  tmpfs /dev/shm  tmpfs defaults,nodev,nosuid,noexec 0 0
  tmpfs /tmp      tmpfs defaults,nodev,nosuid,noexec,size=2G 0 0
  /tmp  /var/tmp  none  rw,noexec,nosuid,nodev,bind 0 0
  mount -o remount /tmp

WITH AARTOOL
  aartool plan  --target HOST --user USER --only filesystem,mounts   # read it
  aartool apply --target HOST --user USER --only filesystem,mounts

MORE
  If a package operation fails afterwards, point it at a directory you control
  rather than removing noexec:
    export TMPDIR=/var/lib/mytmp
E
  ;;

  FS-07) cat <<'E'
WHAT
  World-writable directories that do not have the sticky bit set.

WHY
  Without the sticky bit, any user who can write to a directory can delete or
  rename anyone else's files in it, not just their own. That is the mechanism
  behind a whole family of symlink and rename races: an attacker swaps a file
  another process is about to open, between the check and the open. /tmp is the
  classic case, which is why /tmp has had the sticky bit since the 1980s.

COST
  Read the list before you act on it. On any host that runs containers, almost
  every hit is inside the image and snapshot store, and those permissions
  reflect the contents of the images rather than anything about this machine.
  Mass-chmodding a snapshot tree corrupts layers and breaks the containers
  built on them. On a real docs server all 3622 findings were under
  /var/lib/containerd and not one of them was worth changing.

BY HAND
  # Look first, and group by where they actually live:
  find / -xdev -type d -perm -0002 ! -perm -1000 2>/dev/null \
    | cut -d/ -f1-4 | sort | uniq -c | sort -rn | head
  # Then fix only what is genuinely yours:
  find /srv /opt /home -xdev -type d -perm -0002 ! -perm -1000 \
    -exec chmod a+t {} +

WITH AARTOOL
  aartool plan --target HOST --user USER --only filesystem,permissions
  Read that plan rather than applying it blind. The role fixes the paths it
  knows about; a container store is not one of them, and it should not be.

MORE
  Exclude the container root from the question instead of from the fix. If your
  storage driver lives under /var/lib/docker or /var/lib/containerd, findings
  there are about your images, and the place to fix them is the Dockerfile.
E
  ;;

  FS-05) cat <<'E'
WHAT
  Unexpected setuid and setgid binaries on the filesystem.

WHY
  A setuid root binary runs as root no matter who starts it, so every one of
  them is a potential privilege escalation and the list should be short and
  known. Two distinct problems hide here: a distribution binary with a known
  CVE (pkexec and CVE-2021-4034 is the canonical example, sudo and
  CVE-2021-3156 the other), and a planted one, which is a persistence
  mechanism that survives password changes and looks entirely ordinary in a
  directory listing.

COST
  None to look. Removing the bit from something the system needs breaks it:
  su, sudo, passwd, mount and ping legitimately carry it.

BY HAND
  find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -l {} \; 2>/dev/null
  # compare against what the package manager expects:
  rpm -Va --nofiles --noscripts 2>/dev/null | grep '^.M'     # RHEL
  dpkg --verify 2>/dev/null | grep '^..5'                     # Debian
  # drop the bit where it is not needed:
  chmod u-s /usr/bin/example

WITH AARTOOL
  aartool apply --target HOST --user USER --only filesystem,permissions
  The role fixes permissions on known files. It does not delete unknown setuid
  binaries: that decision needs a human who knows what the machine runs.

MORE
  Take a baseline on a known-good build and diff against it on every host. A
  new setuid binary appearing between two audits is one of the highest-signal
  indicators available on a Linux box, and `aartool diff` will surface it.
E
  ;;

  SSH-09) cat <<'E'
WHAT
  HostbasedAuthentication in sshd_config, and the .rhosts and .shosts files it
  reads.

WHY
  Host-based authentication trusts the client machine rather than the person on
  it. If host A is listed as trusted, sshd accepts A's assertion that the user
  is who A says they are: no password, no key of their own. One compromised
  machine in the trust set therefore becomes every machine in it, and the trust
  is transitive in practice because nobody maps it. It is a survival of the
  rlogin era and there is almost never a reason to have it on.

COST
  None on any modern estate. The only things that use it are old cluster
  schedulers and some HPC batch systems, which will say so loudly.

BY HAND
  sed -i 's/^#*HostbasedAuthentication.*/HostbasedAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/^#*IgnoreRhosts.*/IgnoreRhosts yes/'                     /etc/ssh/sshd_config
  sshd -t && systemctl reload sshd
  # and look for what is already there:
  find /home /root -maxdepth 2 -name '.rhosts' -o -name '.shosts' 2>/dev/null

WITH AARTOOL
  aartool apply --target HOST --user USER --only ssh

MORE
  Set IgnoreRhosts yes alongside it (that is SSH-08). Turning off host-based
  auth while leaving .rhosts readable keeps the files around for whatever reads
  them next.
E
  ;;

  NET-05) cat <<'E'
WHAT
  Whether legacy cleartext network services are installed or listening: telnet,
  rsh, rlogin, rexec, tftp, ypserv, ftp.

WHY
  Every one of these sends credentials in cleartext, and most authenticate the
  peer weakly or not at all. Anyone who can see the traffic has the password,
  which on a shared or cloud network is a larger set of people than you think.
  They are also frequently forgotten rather than chosen: pulled in by a
  dependency, enabled by an appliance image, still listening years later. An
  attacker port-scanning your estate finds them long before you audit for them.

COST
  None, unless something genuinely uses them, in which case the fix is to
  replace it rather than keep it. tftp is the common real exception: PXE boot
  and network device firmware need it. If so, bind it to the provisioning
  network and firewall it there.

BY HAND
  ss -tulpn | grep -E ':(23|21|69|512|513|514|111)\b'
  systemctl list-unit-files | grep -E 'telnet|rsh|rlogin|rexec|tftp|ypserv|vsftpd'
  apt purge -y telnetd rsh-server tftpd ypserv    # Debian / Ubuntu
  dnf remove -y telnet-server rsh-server tftp-server ypserv   # RHEL

WITH AARTOOL
  aartool apply --target HOST --user USER --only services

MORE
  Removing the package beats masking the unit. A masked service comes back the
  next time something re-enables it, and nothing will tell you.
E
  ;;

  FS-01) cat <<'E'
WHAT
  Permissions and ownership on /etc/passwd. It must be root-owned and 644.

WHY
  /etc/passwd has to be world-readable, which is fine: it holds no hashes any
  more. What matters is that it must not be world- or group-WRITABLE. An
  attacker who can write it does not need an exploit at all. They add a line
  with UID 0, or blank the second field so a system account has no password, or
  change root's shell. It is the shortest path from any write primitive to root
  on the machine, and it is silent.

COST
  None. A correct system already looks like this, so this check failing means
  something changed it, and finding out what changed it matters more than
  fixing the mode.

BY HAND
  stat -c '%U %G %a' /etc/passwd      # want: root root 644
  chown root:root /etc/passwd && chmod 644 /etc/passwd
  # find out who did it, before you conclude it was an accident:
  ausearch -f /etc/passwd -ts recent 2>/dev/null
  # and check the neighbours, which are separate checks:
  stat -c '%n %U %G %a' /etc/shadow /etc/group /etc/gshadow /etc/sudoers

WITH AARTOOL
  aartool apply --target HOST --user USER --only filesystem,permissions

MORE
  /etc/shadow (FS-02) is the one that must not be world-READABLE. The two files
  have opposite requirements and are easy to reason about backwards.
E
  ;;

  LOG-04) cat <<'E'
WHAT
  Whether auditd has rules loaded. Not whether it is running: whether it is
  watching anything.

WHY
  This is the check that catches the most convincing false sense of security in
  the whole report. auditd starts, systemd reports active, every service check
  goes green, and with an empty ruleset it records essentially nothing. When you
  need it during an incident, six months of "audit was enabled" turns out to
  mean six months of nothing. LOG-01 asks whether the daemon runs. This asks
  whether it does anything.

COST
  Disk and I/O, in proportion to how aggressive the rules are. Rules on execve
  for every user on a busy machine generate gigabytes a day. Start with the
  identity and privilege rules, which are cheap and high-signal, and add
  syscall rules deliberately.

BY HAND
  auditctl -l | wc -l          # 0 means running and watching nothing
  cat > /etc/audit/rules.d/50-base.rules <<'EOF'
  -w /etc/passwd -p wa -k identity
  -w /etc/shadow -p wa -k identity
  -w /etc/sudoers -p wa -k scope
  -w /etc/sudoers.d/ -p wa -k scope
  -w /var/log/sudo.log -p wa -k actions
  -a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=-1 -k rootcmd
  EOF
  augenrules --load && auditctl -l | wc -l

WITH AARTOOL
  aartool apply --target HOST --user USER --only audit

MORE
  Make the rules immutable once you are happy with them: a final "-e 2" line
  means they cannot be changed until reboot, so an intruder cannot quietly
  unload the rule that would have recorded them.
E
  ;;

  *) return 1 ;;
  esac
}
