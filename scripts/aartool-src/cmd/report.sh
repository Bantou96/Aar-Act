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
      --empty       The dashboard with no reports in it. Drag them on yourself
      --anonymise   Replace every hostname with server-01, server-02, ... and
                    every IP address with ip-01, ip-02, ... consistently across
                    all reports, so the file can be shared outside the estate
                    it came from. Prints the mapping and what it changed.
      --redact PAT  Also replace this literal string everywhere. Repeatable.
                    For the things only you know are identifying: a client name,
                    a project codename, an admin account.
  -h, --help        Show this help

With no arguments it uses the most recent report it can find in the current
directory, ./reports/ and /var/log/cyberaar/, the same places advise looks.
Pass --empty for the dashboard with nothing in it, to drag reports onto
yourself.

  sudo aartool inspect --out /tmp/audit
  aartool report /tmp/audit/*.json --out fleet.html

  # A version you can hand to someone outside the estate
  aartool report /tmp/audit/*.json --anonymise --redact acme-corp --out share.html
EOF
}

# Embedding JSON inside <script> is a breakout waiting to happen: a hostname
# containing </script> would end the block and everything after it becomes
# markup. < and > only ever appear inside strings in JSON, so escaping them to
# their \u form keeps the document valid and closes the hole.
_report_js_safe() { sed -e 's|<|\\u003c|g' -e 's|>|\\u003e|g'; }

# ── Anonymising ───────────────────────────────────────────────────────────────
# An audit report is a list of a machine's weaknesses with its name attached.
# There are good reasons to show one to somebody: a client, a conference talk, a
# post explaining the tool. There is no good reason to hand over the hostnames
# while doing it.
#
# The substitution is literal and global, not a field rewrite. A hostname does
# not only live in the "host" key; it turns up in evidence strings, in
# remediation hints, in whatever a check happened to capture. Replacing the key
# alone produces a document that looks anonymised and is not, which is worse
# than not trying.
#
# It builds one mapping across every input file, so the same machine is the same
# server-NN in all of them and a before/after pair still lines up.
_report_anon_sed=""
_report_anon_map=""

_report_build_anon() {
  local -n _files_ref="$1"; shift
  local -a extra=("$@")
  local f name ip n=0 script="" map=""

  # Longest first. Replacing "web-01" before "web-01.example.com" would leave
  # "server-04.example.com" behind, which still names the domain.
  local hosts
  hosts=$(grep -ho '"host":[[:space:]]*"[^"]*"' "${_files_ref[@]}" 2>/dev/null \
          | sed 's/.*"host":[[:space:]]*"//; s/"$//' | sort -u \
          | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- || true)
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    n=$((n+1))
    local alias; alias=$(printf 'server-%02d' "$n")
    script+="s|$(_report_sed_escape "$name")|${alias}|g;"
    map+="  ${name}  ->  ${alias}"$'\n'
  done <<<"$hosts"

  # Addresses, in the order they first appear so the numbering is stable.
  local ips
  ips=$(grep -hoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "${_files_ref[@]}" 2>/dev/null | sort -u || true)
  local m=0
  while IFS= read -r ip; do
    [[ -z "$ip" ]] && continue
    m=$((m+1))
    script+="s|$(_report_sed_escape "$ip")|$(printf 'ip-%02d' "$m")|g;"
  done <<<"$ips"
  [[ "$m" -gt 0 ]] && map+="  ${m} IP address(es)  ->  ip-01 .. $(printf 'ip-%02d' "$m")"$'\n'

  # --redact is a literal global substitution, which is what makes it useful and
  # also what makes it dangerous: the report's own structural keys are just
  # strings in the same document. `--redact cyberaar` rewrote every
  # "cyberaar_baseline" key to "REDACTED_baseline", the dashboard's bootstrap
  # found no reports to load, and the output was a perfectly valid HTML file
  # showing an empty page. Refuse instead, and say why.
  local schema="cyberaar_baseline host os date score summary results id category status check detail remediation ansible_remediation remediation_tags version fail_ids warn_ids playbook inventory pass warn fail total"
  local e k
  for e in ${extra[@]+"${extra[@]}"}; do
    for k in $schema; do
      if [[ "$k" == *"$e"* ]]; then
        die "--redact '$e' would also rewrite the report's own '$k' field, and the
        output would render an empty dashboard. Pick a more specific string, or
        drop it: hostnames and addresses are already handled by --anonymise."
      fi
    done
    script+="s|$(_report_sed_escape "$e")|REDACTED|g;"
    map+="  ${e}  ->  REDACTED"$'\n'
  done

  _report_anon_sed="$script"
  _report_anon_map="$map"
}

# A hostname can legitimately contain characters sed treats as syntax, and the
# pipe has to be escaped too because it is also the s||| delimiter here. The
# first version of this used a sed bracket expression containing a pipe, which
# sed read as the end of the pattern, so it silently produced a broken script
# and the whole command exited 1 with no message. Parameter expansion has no
# delimiter to collide with.
_report_sed_escape() {
  local t="$1"
  t="${t//\\/\\\\}"          # backslash first, or it doubles the others
  t="${t//|/\\|}"
  t="${t//./\\.}"
  t="${t//\*/\\*}"
  t="${t//\[/\\[}"
  t="${t//\]/\\]}"
  t="${t//^/\\^}"
  t="${t//\$/\\$}"
  t="${t//&/\\&}"
  t="${t//\//\\/}"
  printf '%s' "$t"
}

# What a reader would still be able to identify. Printed after the fact rather
# than silently trusted, because the operator knows things this cannot: a client
# name, an internal codename, a person.
_report_anon_warn() {
  local file="$1" leaks="" data
  # Only the injected data. The dashboard above it contains example commands
  # with an example address in them, so scanning the whole file warned on every
  # single run, and a warning that always fires is one people stop reading.
  data=$(sed -n '/Injected by aartool/,$p' "$file" 2>/dev/null || true)
  [[ -n "$data" ]] || return 0
  grep -qE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' <<<"$data" && leaks+=" an IP address,"
  # Any host value that is not one of ours. Written as a positive match on what
  # a real hostname looks like, because grep -E has no negative lookahead and
  # the version that pretended otherwise checked nothing at all.
  grep -o '"host":[[:space:]]*"[^"]*"' <<<"$data" 2>/dev/null \
    | grep -qv '"server-[0-9]' && leaks+=" a hostname,"
  if [[ -n "$leaks" ]]; then
    warn "After anonymising, the output still contains:${leaks%,}"
    warn "Read it before you publish it."
  fi
}

# The same three locations advise looks in, newest first.
_report_find_newest() {
  local f
  f=$(find . ./reports /var/log/cyberaar -maxdepth 1 -name 'cyberaar-*.json' -type f -print0 2>/dev/null \
      | xargs -0 -r ls -t 2>/dev/null | head -1) || true
  [[ -n "$f" ]] && printf '%s' "$f"
  return 0
}

cmd_report() {
  local out="" serve="" do_open=false anon=false want_empty=false
  local -a files=() redact=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--out)  [[ $# -ge 2 ]] || die "$1 needs a file path."; out="$2"; shift 2 ;;
      --serve)   [[ $# -ge 2 ]] || die "--serve needs a port."; serve="$2"; shift 2 ;;
      --open)    do_open=true; shift ;;
      --empty)   want_empty=true; shift ;;
      --anonymise|--anonymize) anon=true; shift ;;
      --redact)  [[ $# -ge 2 ]] || die "--redact needs a string."; redact+=("$2"); shift 2 ;;
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

  # ── no reports named: use the newest one, as advise does ───────────────────
  #
  # `advise` with no argument reads the most recent report. `report` used to
  # write an EMPTY dashboard instead, so someone who had just run inspect and
  # typed `aartool report --out audit.html` got a file with nothing in it, and
  # nothing said so plainly. Two commands, the same absent argument, opposite
  # meanings. The empty dashboard is still available, now as --empty.
  if [[ "${#files[@]}" -eq 0 && "$want_empty" == false ]]; then
    local newest; newest="$(_report_find_newest || true)"
    if [[ -n "$newest" ]]; then
      info "Using the most recent report found: $newest"
      files=("$newest")
    fi
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

  if [[ "$anon" == true ]]; then
    _report_build_anon files ${redact[@]+"${redact[@]}"}
    info "Anonymised. The mapping is printed once, here, and stored nowhere:"
    printf '%s' "$_report_anon_map"
  fi

  {
    printf '\n<script>\n'
    printf '// Injected by aartool %s. The dashboard is unmodified above this line.\n' "$AARTOOL_VERSION"
    printf '(function () {\n  var PRELOAD = [\n'
    local first=true
    for f in "${files[@]}"; do
      [[ "$first" == true ]] || printf ',\n'
      first=false
      if [[ "$anon" == true ]]; then
        sed "$_report_anon_sed" < "$f" | _report_js_safe
      else
        _report_js_safe < "$f"
      fi
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

  # Verify the artefact rather than trusting the transformation that produced
  # it. Anonymising rewrites the document with a generated sed script; if that
  # script touches something structural the file is still valid HTML and still
  # opens, and shows nothing at all.
  local embedded
  embedded=$(grep -c '"cyberaar_baseline"' "$target" || true)
  if [[ "$embedded" -lt "${#files[@]}" ]]; then
    die "Only ${embedded} of ${#files[@]} reports survived into $target with an intact
        structure, so it would open empty. This is a bug in aartool, not in your
        input; please report it with the flags you used."
  fi

  [[ "$anon" == true ]] && _report_anon_warn "$target"

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
