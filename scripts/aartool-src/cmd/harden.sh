# ── plan and apply ───────────────────────────────────────────────────────────
# Both wrap run-hardening.sh. They differ in exactly one thing, which is whether
# --check is passed, and that difference is worth a whole command rather than a
# flag: the failure mode of forgetting -c is a rewritten sshd_config on a live
# machine.

cmd_harden_usage() {
  local verb="$1"
  cat <<EOF
aartool ${verb} — $( [[ "$verb" == plan ]] \
  && echo "show what hardening would change. Changes nothing." \
  || echo "apply hardening to a target." )

Usage:
  aartool ${verb} --target HOST|GROUP [options]

Options:
  -t, --target HOST|GROUP   Host or inventory group. Required.
  -u, --user USER           SSH user (default: ansible)
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
  local target="" user="" tags="" full=false become=false assume_yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--target) [[ $# -ge 2 ]] || die "$1 needs a value."; target="$2"; shift 2 ;;
      -u|--user)   [[ $# -ge 2 ]] || die "$1 needs a value."; user="$2";   shift 2 ;;
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
  require_inventory

  if ! target_in_inventory "$target"; then
    die "'$target' is not a host or group in $INVENTORY. Add it there first, or check the spelling."
  fi

  local -a args=(-t "$target" -s "$( [[ "$full" == true ]] && echo all || echo 2 )")
  [[ -n "$user" ]]      && args+=(-u "$user")
  [[ -n "$tags" ]]      && args+=(-T "$tags")
  [[ "$become" == true ]] && args+=(-K)
  [[ "$mode" == plan ]] && args+=(-c)

  echo
  printf '%sTarget%s   %s\n'  "$BOLD" "$RESET" "$target"
  printf '%sScope%s    %s\n'  "$BOLD" "$RESET" "${tags:-all hardening categories}"
  printf '%sSteps%s    %s\n'  "$BOLD" "$RESET" "$( [[ "$full" == true ]] && echo "audit, harden, audit" || echo "harden" )"
  if [[ "$mode" == plan ]]; then
    printf '%sMode%s     %spreview — nothing will be changed%s\n' "$BOLD" "$RESET" "$GREEN" "$RESET"
  else
    printf '%sMode%s     %sAPPLY — this will change the target%s\n' "$BOLD" "$RESET" "$RED" "$RESET"
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

  info "Running $(basename "$HARDEN")"
  bash "$HARDEN" "${args[@]}"
}
