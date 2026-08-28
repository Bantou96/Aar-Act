# ── doctor ───────────────────────────────────────────────────────────────────
# Everything that has to be true before plan or apply can work, checked in one
# place and reported all at once.
#
# The failure this replaces: ansible-playbook exits with "couldn't resolve module
# ansible.posix.sysctl" partway through a run, which tells the operator nothing
# about ansible-galaxy and nothing about which of the two collections is
# missing. Preflight is cheap; a half-applied hardening run is not.

_doc_ok=0; _doc_bad=0
_doc_pass() { printf '  %s✔%s  %-34s %s\n' "$GREEN" "$RESET" "$1" "${2:-}"; _doc_ok=$((_doc_ok+1)); }
_doc_fail() {
  printf '  %s✗%s  %-34s %s\n' "$RED" "$RESET" "$1" "${2:-}"
  [[ -n "${3:-}" ]] && printf '     %sfix%s  %s\n' "$CYAN" "$RESET" "$3"
  _doc_bad=$((_doc_bad+1))
}
_doc_warn() {
  printf '  %s!%s  %-34s %s\n' "$YELLOW" "$RESET" "$1" "${2:-}"
  [[ -n "${3:-}" ]] && printf '     %snote%s %s\n' "$CYAN" "$RESET" "$3"
}

cmd_doctor_usage() {
  cat <<'EOF'
aartool doctor: check everything plan and apply depend on. Changes nothing.

Usage:
  aartool doctor [--target HOST [--user USER] [--ssh-key FILE]]

Options:
  -t, --target HOST   Also test SSH reachability and sudo on that host
  -u, --user USER     SSH user for that test. Without it, ansible connects as
                      whoever you are locally, which is almost never right on
                      a real estate.
      --ssh-key FILE  SSH private key for that test
  -h, --help          Show this help

Exits non-zero if anything is missing, so it works as a CI gate.
EOF
}

cmd_doctor() {
  local target="" user="" sshkey=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target) [[ $# -ge 2 ]] || die "$1 needs a value."; target="$2"; shift 2 ;;
      -u|--user)   [[ $# -ge 2 ]] || die "$1 needs a value."; user="$2";   shift 2 ;;
      --ssh-key)   [[ $# -ge 2 ]] || die "$1 needs a value."; sshkey="$2"; shift 2 ;;
      -h|--help)   cmd_doctor_usage; return 0 ;;
      -*) die "Unknown option for doctor: $1." ;;
      *)  die "doctor takes no positional arguments." ;;
    esac
  done

  resolve_paths
  printf '\n%saartool doctor%s\n' "$BOLD" "$RESET"
  printf '%s\n' "────────────────────────────────────────────────────────────────────"

  # ── Which aartool is actually running ──────────────────────────────────────
  #
  # `aartool install` symlinks into /usr/local/bin, which precedes /usr/bin on
  # every default PATH. Install the package afterwards and the old symlink wins
  # silently: you get the clone's version, with none of the newer commands, and
  # nothing says so. The symptom is a documented flag reported as unknown, and
  # the reasonable conclusion is that the tool is broken rather than shadowed.
  #
  # Reported by someone whose --target localhost failed on 3.3.1 because a
  # 3.2.0 clone symlink was ahead of the package.
  local _running _first _other
  _running="$(_self_dir)/$(basename "${BASH_SOURCE[0]}")"
  [[ -f "$_running" ]] || _running="$(_self_dir)/aartool"
  _running="$(readlink -f "$_running" 2>/dev/null || printf '%s' "$_running")"

  _first="$(command -v aartool 2>/dev/null || true)"
  if [[ -n "$_first" ]]; then
    _first="$(readlink -f "$_first" 2>/dev/null || printf '%s' "$_first")"
    if [[ "$_first" != "$_running" ]]; then
      _doc_warn "another aartool is ahead on PATH" "$(command -v aartool)" \
        "That one runs when you type 'aartool'. This one is $_running"
    else
      _doc_pass "aartool on PATH" "$_first"
    fi
  fi

  # A packaged install being shadowed is worth naming outright, because the fix
  # is to delete one symlink and there is no way to guess that.
  #
  # The comparison is against what typing 'aartool' resolves to, NOT against the
  # file currently executing. Running a checkout copy directly is normal during
  # development and shadows nothing. Getting that wrong made this check advise
  # `sudo rm /usr/bin/aartool`, which is the package's own binary: the one file
  # here that must never be deleted by hand.
  if [[ -f /usr/share/aartool/.packaged && -n "$_first" && "$_first" != /usr/share/aartool/* ]]; then
    local _pkgver=""
    [[ -x /usr/bin/aartool ]] && _pkgver="$(/usr/bin/aartool --version 2>/dev/null || true)"
    _doc_warn "packaged aartool is shadowed" "${_pkgver:-installed} at /usr/bin/aartool" \
      "Typing 'aartool' runs $(command -v aartool) instead. Remove it: sudo rm $(command -v aartool)"
  fi

  # ── The toolkit itself ─────────────────────────────────────────────────────
  _doc_pass "toolkit located" "$ANSIBLE_BASE"
  [[ -r "$BASELINE" ]] && _doc_pass "aartool-baseline.sh" "readable" \
    || _doc_fail "aartool-baseline.sh" "missing or unreadable" "Re-clone, or run: bash scripts/build.sh"
  [[ -r "$HARDEN" ]] && _doc_pass "run-hardening.sh" "readable" \
    || _doc_fail "run-hardening.sh" "missing or unreadable" "Re-clone the repository"

  # ── Ansible ────────────────────────────────────────────────────────────────
  if command -v ansible-playbook >/dev/null 2>&1; then
    local av; av="$(ansible-playbook --version 2>/dev/null | head -1)"
    _doc_pass "ansible-playbook" "${av:-present}"
  else
    _doc_fail "ansible-playbook" "not on PATH" "pip install ansible   (or use the container: see execution-environment/)"
  fi

  # Named individually. "install the collections" is not actionable when one of
  # the two is already there and the other is not.
  local req="$ANSIBLE_BASE/requirements.yml" c
  if command -v ansible-galaxy >/dev/null 2>&1; then
    for c in ansible.posix community.general; do
      if ansible-galaxy collection list 2>/dev/null | grep -q "^${c} "; then
        _doc_pass "collection ${c}" "installed"
      else
        _doc_fail "collection ${c}" "missing" "ansible-galaxy collection install -r ${req}"
      fi
    done
  else
    _doc_fail "ansible-galaxy" "not on PATH" "pip install ansible"
  fi

  # ── Inventory ──────────────────────────────────────────────────────────────
  if [[ -f "$INVENTORY" ]]; then
    local hosts; hosts="$(grep -cE '^[a-zA-Z0-9][a-zA-Z0-9._-]*' "$INVENTORY" 2>/dev/null || echo 0)"
    _doc_pass "inventory" "$INVENTORY ($hosts entries)"
  elif [[ -f "$INVENTORY_EXAMPLE" ]]; then
    _doc_fail "inventory" "not created yet" "cp $INVENTORY_EXAMPLE $INVENTORY"
  else
    _doc_fail "inventory" "not found" "Create $INVENTORY in INI format"
  fi

  # ── The machine this is running on ─────────────────────────────────────────
  local osname="unknown"
  [[ -r /etc/os-release ]] && osname="$(. /etc/os-release 2>/dev/null; printf '%s %s' "${NAME:-?}" "${VERSION_ID:-}")"
  _doc_pass "control node OS" "$osname"
  _doc_pass "kernel" "$(uname -r)"

  # ── Optional: can we actually reach the target ─────────────────────────────
  if [[ -n "$target" ]]; then
    if [[ ! -f "$INVENTORY" ]]; then
      _doc_warn "target $target" "skipped" "No inventory to resolve it against"
    elif ! target_in_inventory "$target"; then
      _doc_fail "target $target" "not in inventory" "Add it to $INVENTORY"
    elif ! command -v ansible >/dev/null 2>&1; then
      _doc_warn "target $target" "skipped" "ansible not on PATH"
    else
      # Without -u, ansible connects as whoever is running this, which on a
      # real estate is never the admin account. doctor reported "unreachable"
      # for a host that was perfectly reachable, and the fix line it printed
      # reproduced its own mistake. plan and apply have always taken --user;
      # the check that exists to catch connection problems did not.
      local -a probe=(-i "$INVENTORY" "$target" -m ping)
      [[ -n "$user"   ]] && probe+=(-u "$user")
      [[ -n "$sshkey" ]] && probe+=(--private-key "$sshkey")
      vlog "probe: ansible ${probe[*]}"
      if ansible "${probe[@]}" >/dev/null 2>&1; then
        _doc_pass "target $target" "reachable$([[ -n "$user" ]] && printf ' as %s' "$user")"
        # Reachable is not the same as able to change anything. plan is a dry
        # run, but apply needs root, and finding that out at apply time means
        # finding out halfway through a hardening run.
        if ansible -i "$INVENTORY" "$target" -m raw -a 'sudo -n true' \
             ${user:+-u "$user"} ${sshkey:+--private-key "$sshkey"} >/dev/null 2>&1; then
          _doc_pass "sudo on $target" "passwordless"
        else
          _doc_warn "sudo on $target" "needs a password" \
            "apply will stall unless you pass -K, or grant NOPASSWD to the automation account"
        fi
      else
        local hint="ansible -i $INVENTORY $target -m ping"
        [[ -n "$user"   ]] && hint+=" -u $user"
        [[ -n "$sshkey" ]] && hint+=" --private-key $sshkey"
        [[ -z "$user"   ]] && hint+="   (no --user given, so it tried as $(id -un))"
        _doc_fail "target $target" "unreachable" "$hint"
      fi
    fi
  fi

  printf '%s\n' "────────────────────────────────────────────────────────────────────"
  if [[ "$_doc_bad" -eq 0 ]]; then
    printf '  %s%d checks passed. Ready.%s\n\n' "$GREEN" "$_doc_ok" "$RESET"
    return 0
  fi
  printf '  %s%d problem(s)%s, %d fine. Fix the above and run doctor again.\n\n' "$RED" "$_doc_bad" "$RESET" "$_doc_ok"
  return 1
}
