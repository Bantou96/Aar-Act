# =============================================================================
#  TERMINAL RENDERERS
#  _render_summary  — score box + Ansible remediation plan (terminal)
#  _ansible_terminal_plan — detailed per-check plan (called by _render_summary)
# =============================================================================

_ansible_terminal_plan() {
  declare -A seen_plan=()
  local -a plan_keys=()
  local -a plan_vals=()

  for _id in "${FAIL_IDS[@]}" "${WARN_IDS[@]}"; do
    [[ -z "${ANSIBLE_MAP[$_id]+x}" ]] && continue
    local _entry="${ANSIBLE_MAP[$_id]}"
    IFS='|' read -r _tags _role_r _role_u _desc <<< "$_entry"
    local _key
    _key=$(echo "$_tags" | tr ',' '_')
    [[ -n "${seen_plan[$_key]+x}" ]] && continue
    seen_plan["$_key"]=1
    plan_keys+=("$_key")
    plan_vals+=("$_entry")
  done

  if [[ ${#plan_keys[@]} -eq 0 ]]; then
    printf "  ${GREEN}✅  All checks passed — no Ansible remediation needed.${NC}\n\n"
    return
  fi

  # The target is not known here: this script audits a machine, it does not read
  # an inventory. A placeholder is honest; a path relative to a git checkout is
  # not, and that is what used to be printed.
  local _tgt="<host>"
  [[ -n "$AARTOOL_TARGET" ]] && _tgt="$AARTOOL_TARGET"

  # Detect OS family for role name hint
  local _os_hint="(RHEL9 / Ubuntu — auto-detected per host)"
  grep -qi 'rhel\|centos\|almalinux\|rocky' /etc/os-release 2>/dev/null && \
    _os_hint="(RHEL9 / AlmaLinux / Rocky)"
  grep -qi 'ubuntu\|debian' /etc/os-release 2>/dev/null && \
    _os_hint="(Ubuntu / Debian)"

  printf "\n${BOLD}${CYAN}━━━  REMEDIATION  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "  Platform: ${BOLD}%s${NC}\n\n" "$_os_hint"

  local _idx=1
  local _all_tags=""
  for _key in "${plan_keys[@]}"; do
    local _i=$(( _idx - 1 ))
    IFS='|' read -r _tags _role_r _role_u _desc <<< "${plan_vals[$_i]}"
    local _role_hint="$_role_r / $_role_u"
    grep -qi 'rhel\|centos\|almalinux\|rocky' /etc/os-release 2>/dev/null && _role_hint="$_role_r"
    grep -qi 'ubuntu\|debian' /etc/os-release 2>/dev/null && _role_hint="$_role_u"
    printf "  ${YELLOW}[%02d]${NC} ${BOLD}%-42s${NC}  tags: ${CYAN}%s${NC}\n" \
      "$_idx" "$_desc" "$_tags"
    printf "       Role  : %s\n" "$_role_hint"
    printf "       ${GREEN}aartool apply --target %s --only %s${NC}\n\n" \
      "$_tgt" "$_tags"
    # collect unique tags
    IFS=',' read -ra _t <<< "$_tags"
    for t in "${_t[@]}"; do
      [[ "$_all_tags" != *"$t"* ]] && _all_tags="${_all_tags:+$_all_tags,}$t"
    done
    (( _idx++ ))
  done

  printf "  ${BOLD}── Everything above, in one command: ────────────────────────────────────────${NC}\n"
  printf "  ${GREEN}aartool apply --target %s --only %s${NC}\n" \
    "$_tgt" "$_all_tags"
  printf "\n  ${CYAN}   Preview first. It changes nothing:${NC}\n"
  printf "  ${GREEN}aartool plan --target %s --only %s${NC}\n" \
    "$_tgt" "$_all_tags"
  printf "\n  ${CYAN}   %s is a host or group in your inventory.${NC}\n" "$_tgt"
  printf "  ${CYAN}   aartool advise orders these by what an attacker reaches first,${NC}\n"
  printf "  ${CYAN}   and says what each fix costs before you run it.${NC}\n"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

_render_summary() {
  printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "${BOLD}  aartool security score: ${NC}"
  if   [[ "$SCORE" -ge 80 ]]; then printf "${GREEN}${BOLD}%s%%${NC}\n" "$SCORE"
  elif [[ "$SCORE" -ge 60 ]]; then printf "${YELLOW}${BOLD}%s%%${NC}\n" "$SCORE"
  else printf "${RED}${BOLD}%s%%${NC}\n" "$SCORE"; fi
  # Failures lead. They are the only line that means "this is wrong" rather
  # than "this could not be verified", and putting PASS first buried them.
  printf "  ${RED}%-4s failed${NC}   ${YELLOW}%-4s warnings${NC}   ${GREEN}%-4s passed${NC}   of %s checks\n" \
    "$FAIL" "$WARN" "$PASS" "$TOTAL"
  printf "  ${DIM}A warning counts as half a failure in the score.${NC}\n"
  printf "  %s  ·  %s\n" "$HOSTNAME_VAL" "$DATE_VAL"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

  # The remediation plan used to print here, after the score, which put the one
  # number anybody looks for in the middle of the output with 117 lines below
  # it. `aartool advise` does that job properly: ordered by what an attacker
  # reaches first, with the cost of each fix, rather than grouped by Ansible
  # tag. Duplicating it worse, in the way of the score, helped nobody.
  #
  # _ansible_terminal_plan is still defined and still used by the HTML report.
  printf "\n  ${CYAN}Next:${NC}  aartool advise   what to fix first, and what each fix costs\n"
  if [[ "${AARTOOL_HINTS:-0}" != "1" ]]; then
    printf "         ${DIM}aartool inspect --hints   to see a one-line fix under each finding${NC}\n"
  fi
  printf "\n"
}
