# =============================================================================
#  REMOTE SCAN ENGINE
#  When --host / --host-file / --inventory is given, SSH into each target,
#  copy the script, run it, collect HTML/JSON, then remove it.
# =============================================================================

# ── Parse Ansible INI/YAML inventory into a plain IP/host list ───────────────
_parse_inventory() {
  local inv="$1"
  # Strip comments, blank lines, group headers, vars lines, [*:vars] sections
  # Works for simple INI inventories (the common case)
  grep -vE '^\s*(#|$|\[.*:vars\]|\[.*:children\])' "$inv" 2>/dev/null \
    | grep -vE '^\s*\[' \
    | grep -vE '^\s*[a-zA-Z_]+=.*' \
    | awk '{print $1}' \
    | grep -vE '^$' \
    | sort -u
}

# ── Build the host list from all sources ─────────────────────────────────────
_build_host_list() {
  local -a hosts=()
  [[ -n "$REMOTE_HOST" ]] && hosts+=("$REMOTE_HOST")
  if [[ -n "$REMOTE_HOST_FILE" ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"; line="${line// /}"   # strip comments and spaces
      [[ -n "$line" ]] && hosts+=("$line")
    done < "$REMOTE_HOST_FILE"
  fi
  if [[ -n "$ANSIBLE_INVENTORY" ]]; then
    while IFS= read -r h; do
      [[ -n "$h" ]] && hosts+=("$h")
    done < <(_parse_inventory "$ANSIBLE_INVENTORY")
  fi
  # deduplicate preserving order
  local seen=(); local out=()
  for h in "${hosts[@]}"; do
    [[ " ${seen[*]} " == *" $h "* ]] && continue
    seen+=("$h"); out+=("$h")
  done
  printf '%s\n' "${out[@]}"
}

# Shared directory for the ssh control sockets, private to this run. Removed on
# exit along with any master connections still persisting, so a scan leaves no
# open sessions behind on the operator's machine.
_CYBERAAR_SSH_CTL_DIR=""
_cyberaar_ssh_ctl_init() {
  _CYBERAAR_SSH_CTL_DIR="$(mktemp -d -t aartool-ssh-XXXXXX 2>/dev/null)" || _CYBERAAR_SSH_CTL_DIR=""
  [[ -n "$_CYBERAAR_SSH_CTL_DIR" ]] && chmod 700 "$_CYBERAAR_SSH_CTL_DIR" 2>/dev/null || true
}
_cyberaar_ssh_ctl_cleanup() {
  [[ -n "$_CYBERAAR_SSH_CTL_DIR" && -d "$_CYBERAAR_SSH_CTL_DIR" ]] || return 0
  local sock
  for sock in "$_CYBERAAR_SSH_CTL_DIR"/*; do
    [[ -S "$sock" ]] && ssh -o ControlPath="$sock" -O exit placeholder &>/dev/null || true
  done
  rm -rf "$_CYBERAAR_SSH_CTL_DIR"
  _CYBERAAR_SSH_CTL_DIR=""
}
trap _cyberaar_ssh_ctl_cleanup EXIT INT TERM

# ── Run scan on a single remote host via SSH ──────────────────────────────────
#
# TRANSPORT: ssh with the file on stdin, not scp.
#
# scp in OpenSSH 9 and later speaks the SFTP protocol by default, and a hardened
# host frequently has no sftp subsystem at all: removing it is a normal CIS and
# STIG hardening step, and this toolkit's own ssh role is the kind of thing that
# does it. The result was that the remote scan failed on exactly the hosts most
# likely to be running a security tool, with
#
#     scp: Connection closed
#
# swallowed by 2>/dev/null, then "bash: /tmp/.aartool-baseline-xxx.sh: No such
# file or directory" from the run that followed, and a cheerful "1 succeeded" at
# the end. Found on a live bastion, not in review.
#
# Piping over an ssh session needs no subsystem, no scp binary and no sftp, so it
# works wherever an interactive command works. `cat > file` is also the only
# transport available when a host allows command execution but no file transfer.
#
# EVERY STEP IS CHECKED. The previous version returned success unless the initial
# connectivity probe failed, so a scan that copied nothing, ran nothing and
# fetched nothing still counted as a success in the fleet summary. A scanner that
# cannot tell you it failed is worse than one that is simply absent.
_remote_scan() {
  local host="$1"
  local html_out="$2"
  local json_out="$3"

  local ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes)
  if [[ -n "$REMOTE_KEY" ]]; then
    # IdentitiesOnly matters more than it looks. Without it ssh offers every key
    # in the agent before the one that was named, each offer counts against
    # sshd's MaxAuthTries, and on a host running fail2ban a fleet scan from a
    # workstation with several keys loaded gets that workstation banned across
    # the estate. If the operator named a key, use that key and nothing else.
    ssh_opts+=(-i "$REMOTE_KEY" -o IdentitiesOnly=yes)
  fi

  # ── Bastion ────────────────────────────────────────────────────────────────
  # -J looks like the obvious way to do this and quietly does not work here.
  # ssh does NOT pass the outer connection's options to the jump hop: not -i,
  # not StrictHostKeyChecking, not BatchMode. So `--ssh-opt '-J admin@bastion'`
  # alongside `--ssh-key ~/.ssh/estate` authenticates hop 2 with the named key
  # and hop 1 with whatever the defaults happen to be, which on a machine with
  # no agent and no known_hosts entry fails as
  #
  #     ssh_askpass: exec(/usr/bin/ssh-askpass): No such file or directory
  #     Host key verification failed.
  #
  # ...a message about the bastion that never names the bastion. This is the
  # normal shape of a real estate, not an edge case: private nodes with no
  # public address, reached through one jump host, with a dedicated key.
  #
  # --jump therefore builds the ProxyCommand explicitly and carries the same
  # key and the same connection options onto hop 1.
  if [[ -n "${REMOTE_JUMP:-}" ]]; then
    local _jhost="$REMOTE_JUMP" _jport=22
    if [[ "$_jhost" == *:* ]]; then _jport="${_jhost##*:}"; _jhost="${_jhost%:*}"; fi
    local _pc="ssh -W %h:%p -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes -p ${_jport}"
    [[ -n "$REMOTE_KEY" ]] && _pc+=" -o IdentitiesOnly=yes -i $(printf '%q' "$REMOTE_KEY")"
    _pc+=" $(printf '%q' "$_jhost")"
    ssh_opts+=(-o "ProxyCommand=${_pc}")
  fi

  # One TCP connection per host, reused for all seven operations below.
  #
  # A scan opens a connection to probe, to push the script, to check it landed,
  # to run it, to fetch each report and to clean up. Without multiplexing that is
  # seven full handshakes per host, so a fifty-host fleet performs three hundred
  # and fifty. That is slow, it pushes against sshd's MaxStartups (10:30:100 by
  # default, past which it refuses roughly a third of new connections at random),
  # and on a host running fail2ban it looks like exactly the thing fail2ban is
  # there to stop.
  #
  # Found the hard way: scanning one host repeatedly during development got this
  # workstation banned by the estate's own fail2ban.
  #
  # %C hashes host, port, user and local host into a short filename, which keeps
  # the socket path under the 104-byte sun_path limit that longer schemes hit.
  if [[ -n "$_CYBERAAR_SSH_CTL_DIR" ]]; then
    ssh_opts+=(-o ControlMaster=auto -o "ControlPath=${_CYBERAAR_SSH_CTL_DIR}/%C" -o ControlPersist=30s)
  fi
  # Anything the operator passed with --ssh-opt, most usefully -J for a bastion.
  # Estates that matter put their hosts behind a jump host, and without this the
  # scanner could only reach machines that were already reachable directly.
  local _o
  for _o in ${REMOTE_SSH_OPTS[@]+"${REMOTE_SSH_OPTS[@]}"}; do ssh_opts+=("$_o"); done

  local target="${REMOTE_USER}@${host}"
  local _rand
  _rand=$(openssl rand -hex 8 2>/dev/null || tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 16)
  local remote_script="/tmp/.aartool-baseline-${_rand}.sh"
  local remote_html="/tmp/.aartool-report-${_rand}.html"
  local remote_json="/tmp/.aartool-report-${_rand}.json"

  printf "\n${BOLD}${CYAN}━━━  Remote scan: %s  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" "$host"

  # ── 1. Reachability ────────────────────────────────────────────────────────
  local _probe
  if ! _probe=$(ssh "${ssh_opts[@]}" "$target" "echo ok" 2>&1); then
    printf "  ${RED}❌  SSH connection failed: %s@%s${NC}\n" "$REMOTE_USER" "$host"
    printf "     %s\n" "${_probe%%$'\n'*}"
    printf "     Check: host reachable, user exists, key auth works without a passphrase.\n"
    printf "     Behind a bastion? Pass it through: --ssh-opt '-J user@bastion'\n"
    return 1
  fi

  # ── 2. Push the script ─────────────────────────────────────────────────────
  local _err
  if ! _err=$(ssh "${ssh_opts[@]}" "$target" \
        "cat > '${remote_script}' && chmod 700 '${remote_script}'" < "$SCRIPT_PATH" 2>&1); then
    printf "  ${RED}❌  Could not copy the audit script to %s${NC}\n" "$host"
    printf "     %s\n" "${_err%%$'\n'*}"
    printf "     The remote /tmp may be full, noexec, or read-only.\n"
    return 1
  fi

  # Landed and non-empty. A truncated copy runs and produces nonsense.
  local _size
  _size=$(ssh "${ssh_opts[@]}" "$target" "wc -c < '${remote_script}' 2>/dev/null || echo 0" 2>/dev/null | tr -dc '0-9')
  if [[ -z "$_size" || "$_size" -lt 1000 ]]; then
    printf "  ${RED}❌  The audit script did not arrive intact on %s (%s bytes)${NC}\n" "$host" "${_size:-0}"
    ssh "${ssh_opts[@]}" "$target" "rm -f '${remote_script}'" &>/dev/null || true
    return 1
  fi

  # ── 3. Run it ──────────────────────────────────────────────────────────────
  local rflags=""
  [[ -n "$html_out" ]] && rflags="$rflags --html-out ${remote_html}"
  [[ -n "$json_out" ]] && rflags="$rflags --json-out ${remote_json}"

  local _rc=0
  if [[ "$REMOTE_USER" == "root" ]]; then
    ssh "${ssh_opts[@]}" "$target" "bash '${remote_script}'${rflags:+ $rflags}" || _rc=$?
  else
    # -n so the remote sudo cannot silently wait for a password nobody can type.
    ssh "${ssh_opts[@]}" "$target" "sudo -n bash '${remote_script}'${rflags:+ $rflags}" || _rc=$?
  fi
  if [[ "$_rc" -ne 0 ]]; then
    printf "  ${RED}❌  The audit did not complete on %s (exit %d)${NC}\n" "$host" "$_rc"
    printf "     If this is a sudo prompt: %s needs passwordless sudo, or scan as root.\n" "$REMOTE_USER"
    ssh "${ssh_opts[@]}" "$target" "rm -f '${remote_script}' '${remote_html}' '${remote_json}'" &>/dev/null || true
    return 1
  fi

  # ── 4. Fetch the reports ───────────────────────────────────────────────────
  # Same reasoning as the push: cat over ssh needs no sftp. An empty file counts
  # as a failure, because a zero-byte report reads as a successful scan of a
  # machine with no findings.
  #
  # Read back through sudo when the scan ran through sudo. The audit runs as root
  # and writes its reports as root, so an unprivileged login cannot read the
  # files it just asked for. That failed silently on a live host: the audit
  # completed, printed its findings to the terminal, and then could not retrieve
  # a single one of them.
  local _cat="cat"
  [[ "$REMOTE_USER" != "root" ]] && _cat="sudo -n cat"
  local fetch_failed=0
  if [[ -n "$html_out" ]]; then
    if ssh "${ssh_opts[@]}" "$target" "$_cat '${remote_html}'" > "$html_out" 2>/dev/null && [[ -s "$html_out" ]]; then
      printf "  🌐 HTML fetched → %s\n" "$html_out"
    else
      rm -f "$html_out"
      printf "  ${YELLOW}⚠️   Could not fetch the HTML report from %s${NC}\n" "$host"
      fetch_failed=1
    fi
  fi
  if [[ -n "$json_out" ]]; then
    if ssh "${ssh_opts[@]}" "$target" "$_cat '${remote_json}'" > "$json_out" 2>/dev/null && [[ -s "$json_out" ]]; then
      printf "  📄 JSON fetched → %s\n" "$json_out"
    else
      rm -f "$json_out"
      printf "  ${YELLOW}⚠️   Could not fetch the JSON report from %s${NC}\n" "$host"
      fetch_failed=1
    fi
  fi

  # ── 5. Clean up after ourselves ────────────────────────────────────────────
  # Root-owned reports need root to remove. Leaving an audit of the machine in
  # world-readable /tmp is not acceptable housekeeping for a security tool.
  local _rm="rm -f"
  [[ "$REMOTE_USER" != "root" ]] && _rm="sudo -n rm -f"
  ssh "${ssh_opts[@]}" "$target" "$_rm '${remote_script}' '${remote_html}' '${remote_json}'" &>/dev/null || true

  [[ "$fetch_failed" -eq 0 ]] || return 1
  return 0
}

# ── Fleet scan dispatcher ─────────────────────────────────────────────────────
FLEET_HOSTS=()
if [[ -n "$REMOTE_HOST" || -n "$REMOTE_HOST_FILE" || -n "$ANSIBLE_INVENTORY" ]]; then
  while IFS= read -r h; do
    [[ -n "$h" ]] && FLEET_HOSTS+=("$h")
  done < <(_build_host_list)

  if [[ ${#FLEET_HOSTS[@]} -eq 0 ]]; then
    printf "${RED}❌  No hosts found from the specified source(s).${NC}\n"
    exit 1
  fi

  printf "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
  printf "${BOLD}${CYAN}║  aartool fleet scan: %d host(s)%-28s║${NC}\n" "${#FLEET_HOSTS[@]}" ""
  printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

  _cyberaar_ssh_ctl_init
  FLEET_OK=0; FLEET_FAIL=0
  for host in "${FLEET_HOSTS[@]}"; do
    # Build output paths for this host
    local_html=""; local_json=""
    HOST_SLUG=$(echo "$host" | tr -cd 'a-zA-Z0-9.-')
    DATESTR=$(date '+%Y%m%d-%H%M%S')

    if [[ -n "$OUTPUT_DIR" ]]; then
      local_html="${OUTPUT_DIR}/aartool-${HOST_SLUG}-${DATESTR}.html"
      local_json="${OUTPUT_DIR}/aartool-${HOST_SLUG}-${DATESTR}.json"
    elif [[ -n "$HTML_OUT" ]]; then
      local_html="${HTML_OUT%.html}-${HOST_SLUG}.html"
    elif [[ -n "$JSON_OUT" ]]; then
      local_json="${JSON_OUT%.json}-${HOST_SLUG}.json"
    fi

    if _remote_scan "$host" "$local_html" "$local_json"; then
      ((FLEET_OK++))
    else
      ((FLEET_FAIL++))
    fi
  done

  printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "${BOLD}  Fleet scan complete:${NC} ✅ %d succeeded   ❌ %d failed   (Total: %d)\n" \
    "$FLEET_OK" "$FLEET_FAIL" "${#FLEET_HOSTS[@]}"
  printf "  📁 Reports in: %s\n" "${OUTPUT_DIR:-current directory}"
  printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "  aartool  https://github.com/cyberaar/aartool\n\n"
  exit 0
fi
