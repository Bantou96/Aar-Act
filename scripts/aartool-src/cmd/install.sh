# ── install ──────────────────────────────────────────────────────────────────
# A SYMLINK, not a copy, and that is not a detail.
#
# aartool locates everything it wraps by walking up from its own file until it
# finds ansible-hardening/. Copied to /usr/local/bin there is nothing above it
# but /usr and /, so a copied aartool finds no playbooks, no baseline script and
# no dashboard, and every command fails with a message about six directories.
#
# A symlink is resolved back to the repository first, so the walk starts where
# the toolkit actually is. Anyone who still wants a copy sets AARTOOL_HOME, and
# the error message says so rather than leaving them to work it out.

cmd_install_usage() {
  cat <<'EOF'
aartool install: put aartool on your PATH.

Usage:
  sudo aartool install [options]
  sudo aartool install --uninstall

Options:
      --prefix DIR   Install into DIR/bin instead of /usr/local/bin.
                     Use ~/.local for a per-user install with no root.
      --uninstall    Remove the symlink
  -h, --help         Show this help

It installs a SYMLINK to this file, not a copy. aartool finds the playbooks, the
baseline script and the dashboard by walking up from its own location, so a copy
sitting alone in /usr/local/bin would find none of them. Keep the repository
where it is, or move it and re-run install.

Per-user, no root:

  aartool install --prefix ~/.local
  # then ensure ~/.local/bin is on your PATH
EOF
}

cmd_install() {
  local prefix="/usr/local" uninstall=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)    [[ $# -ge 2 ]] || die "--prefix needs a directory."; prefix="${2%/}"; shift 2 ;;
      --uninstall) uninstall=true; shift ;;
      -h|--help)   cmd_install_usage; return 0 ;;
      -*) die "Unknown option for install: $1." ;;
      *)  die "install takes no positional arguments." ;;
    esac
  done

  local bindir="$prefix/bin" link="$prefix/bin/aartool"

  if [[ "$uninstall" == true ]]; then
    if [[ -L "$link" || -e "$link" ]]; then
      rm -f "$link" || die "Cannot remove $link. Try with sudo."
      success "Removed $link"
    else
      info "Nothing installed at $link"
    fi
    return 0
  fi

  # Resolve the real path of this script, following the symlink chain, so
  # re-running install after a move repoints rather than creating a loop.
  local self; self="$(_self_dir)/$(basename "${BASH_SOURCE[0]}")"
  [[ -f "$self" ]] || self="$(_self_dir)/aartool"
  [[ -f "$self" ]] || die "Cannot determine where aartool lives on disk."

  resolve_paths   # fail here, before installing, if the toolkit is incomplete

  mkdir -p "$bindir" 2>/dev/null || die "Cannot create $bindir. Try sudo, or --prefix ~/.local for a per-user install."
  [[ -w "$bindir" ]] || die "$bindir is not writable. Try sudo, or --prefix ~/.local for a per-user install."

  if [[ -e "$link" && ! -L "$link" ]]; then
    die "$link exists and is not a symlink. Remove it yourself if you are sure; refusing to overwrite a real file."
  fi

  ln -sfn "$self" "$link" || die "Cannot link $link"
  success "Installed: $link -> $self"

  case ":${PATH}:" in
    *":$bindir:"*) info "Run: aartool doctor" ;;
    *) warn "$bindir is not on your PATH."
       info "Add it: echo 'export PATH=\"$bindir:\$PATH\"' >> ~/.bashrc && . ~/.bashrc" ;;
  esac
}
