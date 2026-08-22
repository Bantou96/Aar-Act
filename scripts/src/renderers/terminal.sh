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

  local _inv="-i inventory/hosts"
  [[ -n "$ANSIBLE_INVENTORY" ]] && _inv="-i ${ANSIBLE_INVENTORY}"
  local _pb="playbooks/2_configure_hardening.yml"
  [[ -n "$ANSIBLE_DIR" ]] && _pb="${ANSIBLE_DIR}/playbooks/2_configure_hardening.yml"

  # Detect OS family for role name hint
  local _os_hint="(RHEL9 / Ubuntu — auto-detected per host)"
  grep -qi 'rhel\|centos\|almalinux\|rocky' /etc/os-release 2>/dev/null && \
    _os_hint="(RHEL9 / AlmaLinux / Rocky)"
  grep -qi 'ubuntu\|debian' /etc/os-release 2>/dev/null && \
    _os_hint="(Ubuntu / Debian)"

  printf "\n${BOLD}${CYAN}━━━  ANSIBLE REMEDIATION PLAN  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "  Platform: ${BOLD}%s${NC}\n" "$_os_hint"
  printf "  Playbook: ${BOLD}%s${NC}\n\n" "$_pb"

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
    printf "       ${GREEN}ansible-playbook %s %s --tags %s${NC}\n\n" \
      "$_inv" "$_pb" "$_tags"
    # collect unique tags
    IFS=',' read -ra _t <<< "$_tags"
    for t in "${_t[@]}"; do
      [[ "$_all_tags" != *"$t"* ]] && _all_tags="${_all_tags:+$_all_tags,}$t"
    done
    (( _idx++ ))
  done

  printf "  ${BOLD}── Fix everything in one command: ───────────────────────────────────────────${NC}\n"
  printf "  ${GREEN}ansible-playbook %s %s --tags %s${NC}\n" \
    "$_inv" "$_pb" "$_all_tags"
  printf "\n  ${CYAN}💡 Add --check --diff for a dry run before applying.${NC}\n"
  printf "  ${CYAN}   Add -l <host_or_group> to target a specific server.${NC}\n"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

_render_summary() {
  printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "${BOLD}  CyberAar Security Score: ${NC}"
  if   [[ "$SCORE" -ge 80 ]]; then printf "${GREEN}${BOLD}%s%%${NC}\n" "$SCORE"
  elif [[ "$SCORE" -ge 60 ]]; then printf "${YELLOW}${BOLD}%s%%${NC}\n" "$SCORE"
  else printf "${RED}${BOLD}%s%%${NC}\n" "$SCORE"; fi
  printf "  ✅ PASS: %-4s  ⚠️  WARN: %-4s  ❌ FAIL: %-4s  (Total: %s)\n" "$PASS" "$WARN" "$FAIL" "$TOTAL"
  printf "  🖥  Host: %-28s  📅 %s\n" "$HOSTNAME_VAL" "$DATE_VAL"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "  CyberAar — https://github.com/cyberaar/cyberaar-toolkit\n\n"

  _ansible_terminal_plan
}
