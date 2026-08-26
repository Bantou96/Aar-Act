# ── plan and apply ───────────────────────────────────────────────────────────
# Both wrap run-hardening.sh. They differ in exactly one thing, which is whether
# --check is passed, and that difference is worth a whole command rather than a
# flag: the failure mode of forgetting -c is a rewritten sshd_config on a live
# machine.

cmd_harden_usage() {
  local verb="$1"
  cat <<EOF
aartool ${verb}: $( [[ "$verb" == plan ]] \
  && echo "show what hardening would change. Changes nothing." \
  || echo "apply hardening to a target." )

Usage:
  aartool ${verb} --target HOST|GROUP [options]

Options:
  -t, --target HOST|GROUP   Host or inventory group. Required.
                            Use 'localhost' for this machine: no inventory
                            needed, and nothing goes over SSH.
  -u, --user USER           SSH user (default: ansible)
      --ssh-key FILE        SSH private key. inspect has always taken one;
                            plan and apply did not, so on an estate with a
                            dedicated key they failed with a permission error
                            that pointed at the target rather than at the
                            missing flag.
      --only TAGS           Limit to categories, comma separated.
                            e.g. ssh, firewall, audit, kernel, users
      --full                Run the three-step pipeline: audit, harden, audit.
                            Default is the hardening step alone.
  -K, --ask-become-pass     Prompt for the sudo password on the target
$( [[ "$verb" == apply ]] && printf '  -y, --yes                 Skip the confirmation prompt\n' )
  -h, --help                Show this help

--target is required and has no default. run-hardening.sh defaults to the group
'linux_servers', which is every machine in the inventory, so a bare invocation
hardens the whole estate. That is not a default worth having.
EOF
}

cmd_harden() {
  local mode="$1"; shift          # plan | apply
  local target="" user="" sshkey="" tags="" full=false become=false assume_yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target) [[ $# -ge 2 ]] || die "$1 needs a value."; target="$2"; shift 2 ;;
      -u|--user)   [[ $# -ge 2 ]] || die "$1 needs a value."; user="$2";   shift 2 ;;
      --ssh-key)   [[ $# -ge 2 ]] || die "$1 needs a value."
                   [[ -r "$2" ]] || die "SSH key not readable: $2"
                   sshkey="$2"; shift 2 ;;
      --only)      [[ $# -ge 2 ]] || die "$1 needs a value."; tags="$2";   shift 2 ;;
      --full)      full=true;       shift ;;
      -K|--ask-become-pass) become=true; shift ;;
      -y|--yes)
        [[ "$mode" == apply ]] || die "--yes only applies to 'apply'. 'plan' changes nothing, so there is nothing to confirm."
        assume_yes=true; shift ;;
      -h|--help)   cmd_harden_usage "$mode"; return 0 ;;
      --) shift; break ;;
      -*) die "Unknown option for ${mode}: $1. Try 'aartool ${mode} --help'." ;;
      *)  die "Unexpected argument: $1. The target goes after --target." ;;
    esac
  done

  [[ -n "$target" ]] || die "--target is required. Name a host or an inventory group, e.g. 'aartool ${mode} --target web-01'."

  resolve_paths

  # localhost is the one target that needs no inventory: it is the machine you
  # are already on, which is also the machine `inspect` just audited. Requiring
  # an inventory entry to harden it made the obvious first thing anyone tries
  # fail on a package install, where there is no inventory at all and nowhere
  # writable to put one.
  #
  # The temporary inventory carries ansible_connection=local, so nothing is
  # attempted over SSH. Without it Ansible would try to ssh to "localhost",
  # which needs a key and a running sshd for no reason.
  local _local_inv=""
  if [[ "$target" == "localhost" || "$target" == "127.0.0.1" ]]; then
    target="localhost"
    _local_inv="$(mktemp)"
    printf 'localhost ansible_connection=local ansible_python_interpreter=%s\n' \
      "$(command -v python3 || echo /usr/bin/python3)" > "$_local_inv"
    export AARTOOL_INVENTORY="$_local_inv"
    INVENTORY="$_local_inv"
    # shellcheck disable=SC2064
    trap "rm -f '$_local_inv'" RETURN
  else
    require_inventory
    if ! target_in_inventory "$target"; then
      die "'$target' is not a host or group in $INVENTORY. Add it there first, or check the spelling.
        To harden the machine you are on instead, no inventory needed:
          aartool ${mode} --target localhost"
    fi
  fi

  local -a args=(-t "$target" -s "$( [[ "$full" == true ]] && echo all || echo 2 )")
  [[ -n "$user" ]]      && args+=(-u "$user")
  [[ -n "$sshkey" ]]    && args+=(-i "$sshkey")
  [[ -n "$tags" ]]      && args+=(-T "$tags")
  [[ "$become" == true ]] && args+=(-K)
  [[ "$mode" == plan ]] && args+=(-c)

  echo
  printf '%sTarget%s   %s\n'  "$BOLD" "$RESET" "$target"
  printf '%sScope%s    %s\n'  "$BOLD" "$RESET" "${tags:-all hardening categories}"
  printf '%sSteps%s    %s\n'  "$BOLD" "$RESET" "$( [[ "$full" == true ]] && echo "audit, harden, audit" || echo "harden" )"
  if [[ "$mode" == plan ]]; then
    printf '%sMode%s     %spreview: nothing will be changed%s\n' "$BOLD" "$RESET" "$GREEN" "$RESET"
  else
    printf '%sMode%s     %sAPPLY: this will change the target%s\n' "$BOLD" "$RESET" "$RED" "$RESET"
  fi
  echo

  if [[ "$mode" == apply && "$assume_yes" == false ]]; then
    if [[ ! -t 0 ]]; then
      die "apply needs confirmation and there is no terminal to ask on. Pass --yes if you meant it, or use 'aartool plan' first."
    fi
    # Typing the name, rather than y/N, because the dangerous mistake here is
    # applying to the right kind of thing with the wrong name: a group instead
    # of the one host you meant.
    local answer=""
    printf 'Type the target name to confirm: '
    read -r answer
    [[ "$answer" == "$target" ]] || die "Confirmation did not match. Nothing was changed."
    echo
  fi

  # Both modes need root on localhost, and plan needs it for a reason that is
  # not obvious: it changes nothing, but the playbook still reads sshd_config,
  # audit rules and sysctls to decide what it WOULD change. Without this the
  # first thing anyone tries fails with "Premature end of stream waiting for
  # become success", which names neither sudo nor the fix.
  if [[ -n "$_local_inv" && "$EUID" -ne 0 && "$become" == false ]]; then
    if [[ "$mode" == plan ]]; then
      die "Previewing localhost needs root: the playbook reads sshd_config, audit
        rules and sysctls to work out what it would change. It changes nothing.
          sudo aartool plan --target localhost
        Or be asked for the sudo password instead:
          aartool plan --target localhost -K"
    fi
    die "Applying to localhost changes this machine and needs root.
          sudo aartool apply --target localhost
        Or be asked for the sudo password instead:
          aartool apply --target localhost -K"
  fi

  info "Running $(basename "$HARDEN")"
  bash "$HARDEN" "${args[@]}"
}
