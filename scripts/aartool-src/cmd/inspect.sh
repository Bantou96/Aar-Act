# ── inspect ──────────────────────────────────────────────────────────────────
# Wraps aartool-baseline.sh. Its flags are already clear and already the ones
# in the published docs, so they are passed through rather than renamed: the
# gain from a second spelling would not repay teaching people two.

cmd_inspect_usage() {
  cat <<'EOF'
aartool inspect: audit a machine. Changes nothing.

Usage:
  aartool inspect [options]

Options:
  --host HOST           Audit one remote host over SSH
  --host-file FILE      Audit every host listed in FILE, one per line
  --inventory FILE      Audit every host in an Ansible inventory
  --user USER           SSH user for a remote audit
  --ssh-key FILE        SSH private key for a remote audit
  --jump USER@HOST[:PORT]
                        Reach the target through this bastion, which is how
                        most estates are shaped. Use this rather than
                        --ssh-opt '-J ...': ssh does not pass --ssh-key or the
                        connection options to the jump hop, so -J fails on hop
                        one with a host key error that never names the bastion.
  --ssh-opt OPT         Extra ssh option, repeatable
  -o, --out DIR         Write reports to DIR. Default: ./reports
  --no-save             Print to the terminal and write nothing
  --hints               Print a one-line fix under each finding
  -h, --help            Show this help

With no --host, --host-file or --inventory, aartool audits the machine it is
running on, which needs root:

  sudo aartool inspect

Reports are written to ./reports unless -o says otherwise. HTML and JSON: the
HTML opens offline with no external requests, which is the point on an isolated
network, and the JSON is what advise, diff and report read.

Under sudo the reports are handed back to the user who invoked it, so the very
next command does not need root as well.

  sudo aartool inspect       # audit, reports land in ./reports
  aartool advise             # the ordered plan, from what inspect just wrote
EOF
}

cmd_inspect() {
  local -a passthru=()
  # Reports are written by default. The previous behaviour was to write nothing
  # unless -o was given, which meant the three-command loop taught in the README
  # (inspect, then advise) failed on the second command for every first-time
  # user, with an error about a missing report rather than about the flag they
  # were never told to pass. A tool whose documented first run does not work is
  # the one thing worse than a tool with no documentation.
  local out_dir="./reports" save=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host|--host-file|--inventory|--user|--ssh-key|--ssh-opt|--jump)
        [[ $# -ge 2 ]] || die "$1 needs a value."
        passthru+=("$1" "$2"); shift 2 ;;
      -o|--out)
        [[ $# -ge 2 ]] || die "$1 needs a value."
        out_dir="$2"; save=true; shift 2 ;;
      --no-save) save=false; shift ;;
      # Off by default: printing a fix under every non-PASS check doubled the
      # length of a 109-check run. `aartool explain <ID>` gives the same thing
      # in full, plus what closing the finding costs.
      --hints)   export AARTOOL_HINTS=1; shift ;;
      -h|--help) cmd_inspect_usage; return 0 ;;
      --) shift; break ;;
      -*) die "Unknown option for inspect: $1. Try 'aartool inspect --help'." ;;
      *)  die "inspect takes no positional arguments. Did you mean --host $1 ?" ;;
    esac
  done

  resolve_paths

  # A local audit reads files under /etc and /proc that are root-only. Saying so
  # here beats letting the script produce a report full of unknowns.
  local remote=false
  local a
  for a in ${passthru[@]+"${passthru[@]}"}; do
    case "$a" in --host|--host-file|--inventory) remote=true ;; esac
  done
  if [[ "$remote" == false && "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "A local audit needs root: it reads sshd_config, /etc/shadow, audit
        rules and sysctls that are not readable otherwise.
          sudo aartool inspect
        To audit another machine instead, and not need root here:
          aartool inspect --host HOST --user USER"
  fi

  if [[ "$save" == true ]]; then
    mkdir -p "$out_dir" || die "Cannot create the report directory: $out_dir
        Pass somewhere writable with -o DIR, or --no-save to write nothing."
    passthru+=(--output-dir "$out_dir")
  fi


  info "Auditing with $(basename "$BASELINE")"
  local rc=0
  bash "$BASELINE" ${passthru[@]+"${passthru[@]}"} || rc=$?

  local wrote=0
  if [[ "$save" == true && -d "$out_dir" ]]; then
    wrote=$(find "$out_dir" -maxdepth 1 \( -name 'aartool-*.json' -o -name 'cyberaar-*.json' \) -newermt '-10 minutes' 2>/dev/null | wc -l)
    # Leave no empty directory behind from a run that produced nothing.
    [[ "$wrote" -eq 0 ]] && rmdir "$out_dir" 2>/dev/null || true
  fi
  if [[ "$wrote" -gt 0 ]]; then
    # sudo aartool inspect writes root-owned, mode 600 reports into the caller's
    # own directory, and the next command they were told to run cannot read
    # them. Hand the files back to whoever invoked sudo.
    if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
      chown -R "${SUDO_UID}:${SUDO_GID}" "$out_dir" 2>/dev/null || true
      vlog "reports handed back to uid ${SUDO_UID}"
    fi
    printf '\n  Reports:  %s  (%s)\n' "$out_dir" \
      "$( [[ "$wrote" -eq 1 ]] && printf '1 host' || printf '%s hosts' "$wrote" )"
    printf '  Next:     %saartool advise%s   what to fix first, and what each fix costs\n\n' \
      "$CYAN" "$RESET"
  fi
  return "$rc"
}
