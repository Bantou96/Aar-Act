# ── Dispatch ─────────────────────────────────────────────────────────────────
main() {
  [[ $# -gt 0 ]] || { usage; exit 1; }

  case "$1" in
    inspect)        shift; cmd_inspect "$@" ;;
    plan)           shift; cmd_harden plan  "$@" ;;
    apply)          shift; cmd_harden apply "$@" ;;
    surface)        shift; cmd_surface "$@" ;;
    doctor)         shift; cmd_doctor "$@" ;;
    -h|--help|help) usage ;;
    -V|--version|version) printf 'aartool %s\n' "$AARTOOL_VERSION" ;;
    # Named so the error can be specific rather than "unknown command".
    audit|scan)     die "There is no '$1' command. Auditing is 'aartool inspect'." ;;
    harden)         die "There is no 'harden' command. Preview with 'aartool plan', apply with 'aartool apply'." ;;
    -*)             die "Unknown option: $1. Try 'aartool --help'." ;;
    *)              die "Unknown command: $1. Try 'aartool --help'." ;;
  esac
}

main "$@"
