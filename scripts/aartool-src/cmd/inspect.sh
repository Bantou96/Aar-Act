# ── inspect ──────────────────────────────────────────────────────────────────
# Wraps cyberaar-baseline.sh. Its flags are already clear and already the ones
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
  -o, --out DIR         Write reports to DIR (HTML and JSON)
  -h, --help            Show this help

With no --host, --host-file or --inventory, aartool audits the machine it is
running on, which needs root:

  sudo aartool inspect

Reports are HTML and JSON. The HTML opens offline with no external requests,
which is the point on an isolated network.
EOF
}

cmd_inspect() {
  local -a passthru=()
  local out_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host|--host-file|--inventory|--user|--ssh-key|--ssh-opt|--jump)
        [[ $# -ge 2 ]] || die "$1 needs a value."
        passthru+=("$1" "$2"); shift 2 ;;
      -o|--out)
        [[ $# -ge 2 ]] || die "$1 needs a value."
        out_dir="$2"; shift 2 ;;
      -h|--help) cmd_inspect_usage; return 0 ;;
      --) shift; break ;;
      -*) die "Unknown option for inspect: $1. Try 'aartool inspect --help'." ;;
      *)  die "inspect takes no positional arguments. Did you mean --host $1 ?" ;;
    esac
  done

  resolve_paths

  if [[ -n "$out_dir" ]]; then
    mkdir -p "$out_dir" || die "Cannot create output directory: $out_dir"
    passthru+=(--output-dir "$out_dir")
  fi

  # A local audit reads files under /etc and /proc that are root-only. Saying so
  # here beats letting the script produce a report full of unknowns.
  local remote=false
  local a
  for a in ${passthru[@]+"${passthru[@]}"}; do
    case "$a" in --host|--host-file|--inventory) remote=true ;; esac
  done
  if [[ "$remote" == false && "${EUID:-$(id -u)}" -ne 0 ]]; then
    warn "A local audit needs root to read the files it checks. Re-run with sudo, or use --host for a remote audit."
  fi

  info "Auditing with $(basename "$BASELINE")"
  bash "$BASELINE" ${passthru[@]+"${passthru[@]}"}
}
