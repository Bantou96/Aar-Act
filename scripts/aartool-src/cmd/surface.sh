# ── surface ──────────────────────────────────────────────────────────────────
# The command this toolkit exists to offer that a distribution vendor does not.
#
# Red Hat and Debian ship the patch. Nothing helps you in the window before the
# patch exists, or on the machine you cannot reboot until the change window in
# three weeks. These settings close classes of local privilege escalation rather
# than individual CVEs, take effect immediately, and survive a kernel that is
# still vulnerable.

cmd_surface_usage() {
  cat <<'EOF'
aartool surface — kernel attack surface. Assess by default; changes nothing.

Usage:
  aartool surface [options]

Options:
      --strict          Include mitigations that break real workloads.
                        Read the cost column first.
      --fix             Print the sysctl drop-in that would close the gaps.
                        Writes nothing.
      --write FILE      Write that drop-in to FILE instead of printing it.
      --apply           Write to /etc/sysctl.d/60-aartool-surface.conf and load
                        it. Needs root. Asks for confirmation.
  -y, --yes             Skip the confirmation on --apply.
  -h, --help            Show this help

Two tiers, because a mitigation that breaks the workload gets reverted and
teaches people to ignore the tool:

  safe      no mainstream workload is known to depend on it
  strict    will break something real for somebody, and the cost is printed

Without --strict, only the safe tier is considered.

Every setting here is a sysctl. Nothing is compiled, nothing is rebooted, and
anything applied can be undone by deleting the drop-in file and rebooting, or by
setting the value back.
EOF
}

cmd_surface() {
  local strict=false emit="" out_file="" do_apply=false assume_yes=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict) strict=true; shift ;;
      --fix)    emit="print"; shift ;;
      --write)  [[ $# -ge 2 ]] || die "--write needs a file path."; emit="file"; out_file="$2"; shift 2 ;;
      --apply)  do_apply=true; shift ;;
      -y|--yes) assume_yes=true; shift ;;
      -h|--help) cmd_surface_usage; return 0 ;;
      --) shift; break ;;
      -*) die "Unknown option for surface: $1. Try 'aartool surface --help'." ;;
      *)  die "surface takes no positional arguments." ;;
    esac
  done

  local tiers="safe"
  [[ "$strict" == true ]] && tiers="safe strict"

  local -a gap_key=() gap_val=() gap_id=() gap_cost=()
  local n_ok=0 n_na=0

  printf '\n%sKernel attack surface%s   %s\n' "$BOLD" "$RESET" "$(uname -r)"
  printf '%s\n' "────────────────────────────────────────────────────────────────────"

  local id key want tier closes cost have status
  while IFS=$'\t' read -r id key want tier closes cost; do
    [[ -n "$id" ]] || continue
    case " $tiers " in *" $tier "*) ;; *) continue ;; esac

    # The user namespace switch lives under a different key per distribution.
    [[ "$id" == "KRN-01" ]] && key="$(surface_userns_key)"

    have="$(surface_read "$key")"
    if surface_ok "$key" "$want" "$have"; then
      status="closed";  n_ok=$((n_ok+1))
    elif [[ "$have" == "?" ]]; then
      status="absent";  n_na=$((n_na+1))
    else
      status="OPEN"
      gap_key+=("$key"); gap_val+=("$want"); gap_id+=("$id"); gap_cost+=("$cost")
    fi

    # A closed door is one line; an open one earns three, because the operator
    # has a decision to make and needs the cost in front of them to make it.
    case "$status" in
      closed) printf '  %s✔%s  %-7s %s\n' "$GREEN" "$RESET" "$id" "$closes" ;;
      absent) printf '  %s·%s  %-7s %s %s(not present on this kernel)%s\n' "$CYAN" "$RESET" "$id" "$closes" "$CYAN" "$RESET" ;;
      OPEN)
        printf '\n  %s✗%s  %-7s %s%s = %s%s\n' "$RED" "$RESET" "$id" "$BOLD" "$key" "$have" "$RESET"
        printf '     %scloses%s  %s\n' "$CYAN" "$RESET" "$closes"
        printf '     %scost%s    %s\n' "$CYAN" "$RESET" "$cost"
        printf '     %sfix%s     %s = %s\n\n' "$CYAN" "$RESET" "$key" "$want" ;;
    esac
  done < <(surface_catalogue)

  local n_gap="${#gap_key[@]}"
  printf '%s\n' "────────────────────────────────────────────────────────────────────"
  printf '  %d closed, %d open, %d not applicable' "$n_ok" "$n_gap" "$n_na"
  [[ "$strict" == false ]] && printf '   %s(safe tier only; --strict for the rest)%s' "$CYAN" "$RESET"
  printf '\n\n'

  if [[ "$n_gap" -eq 0 ]]; then
    success "Nothing to close in this tier."
    return 0
  fi

  # Nothing below this point runs unless the operator asked for it.
  [[ -z "$emit" && "$do_apply" == false ]] && {
    info "Run 'aartool surface --fix' to see the drop-in that closes these, or --apply to apply it."
    return 0
  }

  local dropin
  dropin="$(surface_render_dropin gap_key gap_val gap_id)"

  if [[ "$emit" == "print" ]]; then
    printf '%s\n' "$dropin"
    return 0
  fi
  if [[ "$emit" == "file" ]]; then
    printf '%s\n' "$dropin" > "$out_file" || die "Cannot write $out_file"
    success "Written: $out_file"
    info "Apply with: sudo sysctl --system"
    return 0
  fi

  # ── apply ──────────────────────────────────────────────────────────────────
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "--apply needs root. Re-run with sudo, or use --write and apply it yourself."

  local target="/etc/sysctl.d/60-aartool-surface.conf"
  printf '%sWill write%s %s and run sysctl --system\n' "$BOLD" "$RESET" "$target"
  printf '%sClosing%s   %d setting(s)\n\n' "$BOLD" "$RESET" "$n_gap"

  if [[ "$assume_yes" == false ]]; then
    [[ -t 0 ]] || die "--apply needs confirmation and there is no terminal. Pass --yes if you meant it."
    local answer=""
    printf 'Apply these to this machine? Type yes to confirm: '
    read -r answer
    [[ "$answer" == "yes" ]] || die "Not confirmed. Nothing was changed."
    echo
  fi

  printf '%s\n' "$dropin" > "$target" || die "Cannot write $target"
  success "Wrote $target"
  if sysctl --system >/dev/null 2>&1; then
    success "Loaded. Verify with: aartool surface$( [[ "$strict" == true ]] && printf ' --strict' )"
  else
    warn "Wrote the file but 'sysctl --system' reported an error. Check: sysctl --system"
  fi
  info "To undo: rm $target && reboot (or set the values back by hand)."
}

# Rendered as a drop-in rather than applied with `sysctl -w`, so the change
# survives a reboot and is visible in one file that can be deleted to revert.
surface_render_dropin() {
  local -n _k="$1" _v="$2" _i="$3"
  printf '# Written by aartool %s on %s\n' "$AARTOOL_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '#\n'
  printf '# Kernel attack surface reduction. Each line closes a class of local\n'
  printf '# privilege escalation rather than a single CVE, and takes effect without\n'
  printf '# a reboot once loaded with: sysctl --system\n'
  printf '#\n'
  printf '# To revert: delete this file and reboot, or set the values back by hand.\n'
  printf '\n'
  local n="${#_k[@]}" idx
  for (( idx=0; idx<n; idx++ )); do
    printf '# %s\n%s = %s\n' "${_i[$idx]}" "${_k[$idx]}" "${_v[$idx]}"
  done
}
