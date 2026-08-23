# ── report ───────────────────────────────────────────────────────────────────
# The toolkit already ships a dashboard: one HTML file, no server, no internet,
# drag your JSON reports onto it. The friction is everything around that. You run
# an audit, find the JSON, find the dashboard, open a browser, drag files in.
#
# This collapses those into one command, and adds the thing a consultancy
# actually needs: a single self-contained file with the results already inside,
# which can be attached to an email and opened offline by someone who has never
# heard of this toolkit.
#
# The dashboard itself is never modified. A copy is made and a small bootstrap
# appended that feeds its own DB structure, so the two cannot fall out of step
# through anything except a deliberate change to the dashboard's data model.

cmd_report_usage() {
  cat <<'EOF'
aartool report: visualise baseline JSON reports.

Usage:
  aartool report [REPORT.json ...] [options]

Options:
  -o, --out FILE    Write a self-contained HTML file with the reports embedded.
                    Opens offline, anywhere, with no other files. Send it.
      --serve PORT  Serve the dashboard on 127.0.0.1:PORT. For a headless
                    server: run it there, then tunnel with
                      ssh -L PORT:127.0.0.1:PORT user@host
      --open        Try to open the result in a browser
  -h, --help        Show this help

With no arguments it opens the empty dashboard, where you can drag reports in
yourself.

  sudo aartool inspect --out /tmp/audit
  aartool report /tmp/audit/*.json --out fleet.html
EOF
}

# Embedding JSON inside <script> is a breakout waiting to happen: a hostname
# containing </script> would end the block and everything after it becomes
# markup. < and > only ever appear inside strings in JSON, so escaping them to
# their \u form keeps the document valid and closes the hole.
_report_js_safe() { sed -e 's|<|\\u003c|g' -e 's|>|\\u003e|g'; }

cmd_report() {
  local out="" serve="" do_open=false
  local -a files=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--out)  [[ $# -ge 2 ]] || die "$1 needs a file path."; out="$2"; shift 2 ;;
      --serve)   [[ $# -ge 2 ]] || die "--serve needs a port."; serve="$2"; shift 2 ;;
      --open)    do_open=true; shift ;;
      -h|--help) cmd_report_usage; return 0 ;;
      --) shift; while [[ $# -gt 0 ]]; do files+=("$1"); shift; done ;;
      -*) die "Unknown option for report: $1. Try 'aartool report --help'." ;;
      *)  files+=("$1"); shift ;;
    esac
  done

  resolve_paths
  local dash="$TOOLKIT_DASHBOARD"
  [[ -f "$dash" ]] || die "Dashboard not found: $dash"

  local f
  for f in ${files[@]+"${files[@]}"}; do
    [[ -f "$f" ]] || die "No such report: $f"
  done

  # ── serve ──────────────────────────────────────────────────────────────────
  if [[ -n "$serve" ]]; then
    [[ "$serve" =~ ^[0-9]+$ ]] || die "--serve needs a port number, got '$serve'."
    command -v python3 >/dev/null 2>&1 || die "--serve needs python3. Without it, copy dashboard/index.html to your workstation and open it there."
    local dir; dir="$(dirname "$dash")"
    info "Serving $dir on http://127.0.0.1:${serve}/"
    # Bound to the loopback deliberately. This renders audit results for a whole
    # estate; it has no authentication and must not be reachable from the network.
    info "Bound to 127.0.0.1 only. From your workstation: ssh -L ${serve}:127.0.0.1:${serve} $(id -un)@$(hostname)"
    info "Ctrl-C to stop."
    ( cd "$dir" && exec python3 -m http.server "$serve" --bind 127.0.0.1 )
    return 0
  fi

  # ── no reports: just the dashboard as it ships ─────────────────────────────
  if [[ "${#files[@]}" -eq 0 ]]; then
    if [[ -n "$out" ]]; then
      cp "$dash" "$out" || die "Cannot write $out"
      success "Written: $out (empty dashboard, drag reports onto it)"
    else
      info "Dashboard: $dash"
      info "Open it in a browser and drag your JSON reports onto it, or pass them: aartool report *.json"
      [[ "$do_open" == true ]] && _report_open "$dash"
    fi
    return 0
  fi

  # ── build a preloaded copy ─────────────────────────────────────────────────
  local target="${out:-$(mktemp -t aartool-report-XXXXXX.html)}"
  cp "$dash" "$target" || die "Cannot write $target"

  {
    printf '\n<script>\n'
    printf '// Injected by aartool %s. The dashboard is unmodified above this line.\n' "$AARTOOL_VERSION"
    printf '(function () {\n  var PRELOAD = [\n'
    local first=true
    for f in "${files[@]}"; do
      [[ "$first" == true ]] || printf ',\n'
      first=false
      _report_js_safe < "$f"
    done
    printf '\n  ];\n'
    cat <<'JS'
  // Feed the dashboard's own store rather than re-implementing its parsing, so
  // a change to its data model breaks loudly here instead of rendering wrongly.
  if (typeof DB === 'undefined' || typeof renderAll !== 'function') {
    console.error('aartool: dashboard data model not found; open the file and drag reports in instead.');
    return;
  }
  PRELOAD.forEach(function (raw) {
    var r = raw && raw.cyberaar_baseline;
    if (!r || !r.host) { console.warn('aartool: skipped a report with no host'); return; }
    if (!DB[r.host]) DB[r.host] = [];
    DB[r.host].push(r);
    DB[r.host].sort(function (a, b) { return String(a.date).localeCompare(String(b.date)); });
  });
  renderAll();
})();
JS
    printf '</script>\n'
  } >> "$target"

  local n="${#files[@]}"
  if [[ -n "$out" ]]; then
    success "Written: $out"
    info "$n report(s) embedded. Self-contained: no server, no internet, no other files."
  else
    success "Built: $target ($n report(s) embedded)"
  fi
  [[ "$do_open" == true ]] && _report_open "$target"
  return 0
}

_report_open() {
  local f="$1" opener
  for opener in xdg-open open wslview; do
    if command -v "$opener" >/dev/null 2>&1; then
      "$opener" "$f" >/dev/null 2>&1 &
      return 0
    fi
  done
  warn "No browser opener found (xdg-open, open, wslview). Open it yourself: $f"
}
