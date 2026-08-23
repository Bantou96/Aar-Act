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
  aartool doctor [--target HOST]

Options:
      --target HOST   Also test SSH reachability and sudo on that host
  -h, --help          Show this help

Exits non-zero if anything is missing, so it works as a CI gate.
EOF
}

cmd_doctor() {
  local target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target) [[ $# -ge 2 ]] || die "$1 needs a value."; target="$2"; shift 2 ;;
      -h|--help)   cmd_doctor_usage; return 0 ;;
      -*) die "Unknown option for doctor: $1." ;;
      *)  die "doctor takes no positional arguments." ;;
    esac
  done

  resolve_paths
  printf '\n%saartool doctor%s\n' "$BOLD" "$RESET"
  printf '%s\n' "────────────────────────────────────────────────────────────────────"

  # ── The toolkit itself ─────────────────────────────────────────────────────
  _doc_pass "toolkit located" "$ANSIBLE_BASE"
  [[ -r "$BASELINE" ]] && _doc_pass "cyberaar-baseline.sh" "readable" \
    || _doc_fail "cyberaar-baseline.sh" "missing or unreadable" "Re-clone, or run: bash scripts/build.sh"
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
      if ansible -i "$INVENTORY" "$target" -m ping >/dev/null 2>&1; then
        _doc_pass "target $target" "reachable"
      else
        _doc_fail "target $target" "unreachable" "ansible -i $INVENTORY $target -m ping   (check SSH user and keys)"
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
