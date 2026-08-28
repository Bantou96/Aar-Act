# ── diff ─────────────────────────────────────────────────────────────────────
# What changed between two audits of the same machine.
#
# This is the command that belongs in cron, and the reason is the exit code. A
# weekly audit that mails you 109 results teaches you to filter the mail. One
# that stays silent unless something REGRESSED is a thing you actually read.
#
#   aartool diff last-week.json today.json || mail -s "drift on $(hostname)" soc@
#
# Regressions and improvements are not symmetric here. A check going PASS to FAIL
# is an alert; going FAIL to PASS is a note. Treating them the same is how a
# report becomes wallpaper.

cmd_diff_usage() {
  cat <<'EOF'
aartool diff: what changed between two audits. Changes nothing.

Usage:
  aartool diff BEFORE.json AFTER.json [options]

Options:
      --quiet     Print only regressions. Nothing at all when there are none,
                  which is what you want in cron.
  -h, --help      Show this help

Exit codes:
  0   nothing regressed
  1   at least one check regressed
  2   the reports could not be compared

Built for cron:

  aartool diff /var/log/cyberaar/last.json /var/log/cyberaar/today.json --quiet \
    || mail -s "config drift on $(hostname)" soc@example.com
EOF
}

cmd_diff() {
  local quiet=false
  local -a pos=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet)   quiet=true; shift ;;
      -h|--help) cmd_diff_usage; return 0 ;;
      --) shift; while [[ $# -gt 0 ]]; do pos+=("$1"); shift; done ;;
      -*) die "Unknown option for diff: $1. Try 'aartool diff --help'." ;;
      *)  pos+=("$1"); shift ;;
    esac
  done

  [[ "${#pos[@]}" -eq 2 ]] || die "diff needs exactly two reports: aartool diff BEFORE.json AFTER.json"
  local before="${pos[0]}" after="${pos[1]}"
  [[ -f "$before" ]] || die "No such report: $before"
  [[ -f "$after"  ]] || die "No such report: $after"

  command -v python3 >/dev/null 2>&1 \
    || die "diff needs python3 to parse the reports. It is present on any machine that can run Ansible."

  # Kept in python rather than jq: jq is not installed by default on RHEL,
  # Ubuntu server or Alpine, and requiring it would put a package install between
  # an operator and their own audit results.
  python3 - "$before" "$after" "$quiet" <<'PY'
import json, sys

before_path, after_path, quiet = sys.argv[1], sys.argv[2], sys.argv[3] == "true"

def load(p):
    try:
        with open(p, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"[ERROR] Cannot read {p}: {e}\n"); sys.exit(2)
    b = doc.get("aartool") or doc.get("cyberaar_baseline")
    if not b:
        sys.stderr.write(f"[ERROR] {p} is not a aartool-baseline report.\n"); sys.exit(2)
    return b

a, b = load(before_path), load(after_path)

# Comparing two different machines silently would produce a diff that looks
# real and means nothing.
if a.get("host") and b.get("host") and a["host"] != b["host"]:
    sys.stderr.write(
        f"[ERROR] These are different hosts: '{a['host']}' and '{b['host']}'.\n"
        f"        Comparing them would produce a difference that is not drift.\n")
    sys.exit(2)

RANK = {"PASS": 0, "WARN": 1, "FAIL": 2}
def index(rep):
    return {r["id"]: r for r in rep.get("results", []) if isinstance(r, dict) and "id" in r}

ai, bi = index(a), index(b)

regressed, improved, appeared, vanished = [], [], [], []
for cid, br in bi.items():
    ar = ai.get(cid)
    if ar is None:
        # A new check counts as drift only if it is already failing; a new
        # passing check is just this tool having learned something.
        if RANK.get(br.get("status"), 1) > 0:
            appeared.append((cid, br))
        continue
    was, now = ar.get("status"), br.get("status")
    if RANK.get(now, 1) > RANK.get(was, 1):
        regressed.append((cid, was, now, br))
    elif RANK.get(now, 1) < RANK.get(was, 1):
        improved.append((cid, was, now, br))
for cid, ar in ai.items():
    if cid not in bi:
        vanished.append((cid, ar))

C = sys.stdout.isatty()
RED    = "\033[0;31m" if C else ""
GREEN  = "\033[0;32m" if C else ""
YELLOW = "\033[1;33m" if C else ""
CYAN   = "\033[0;36m" if C else ""
BOLD   = "\033[1m"    if C else ""
DIM    = "\033[2m"    if C else ""
RST    = "\033[0m"    if C else ""

def line(sym, colour, cid, text, extra=""):
    print(f"  {colour}{sym}{RST}  {cid:<9} {text}")
    if extra:
        print(f"       {CYAN}{extra}{RST}")

if quiet and not regressed:
    sys.exit(0)

if not quiet:
    print()
    print(f"{BOLD}{a.get('host','?')}{RST}   {a.get('date','?')}  →  {b.get('date','?')}")
    sa, sb = a.get("score"), b.get("score")
    if isinstance(sa, (int, float)) and isinstance(sb, (int, float)):
        delta = sb - sa
        col = GREEN if delta > 0 else (RED if delta < 0 else "")
        print(f"{BOLD}score{RST}    {sa} → {sb}   {col}{delta:+d}{RST}")
        # The scoring formula changed once already: a warning used to cost as
        # much as a failure, and stopped doing so. Diffing across that change
        # showed +27 on a machine where nothing whatsoever had happened, which
        # is exactly the kind of number somebody pastes into a status report.
        # The per-check verdicts below are always comparable; the score is only
        # comparable within one engine version.
        va, vb = a.get("version"), b.get("version")
        if va and vb and va != vb:
            print(f"{DIM}         engine {va} → {vb}: the score is not comparable "
                  f"across versions, the findings below are.{RST}")
    print("─" * 68)

if regressed:
    print(f"\n  {RED}{BOLD}Regressed{RST}  ({len(regressed)})")
    for cid, was, now, r in sorted(regressed, key=lambda x: -RANK.get(x[2], 0)):
        line("✗", RED, cid, f"{was} → {now}   {r.get('check','')}", r.get("detail", ""))
        if r.get("remediation"):
            print(f"       {CYAN}fix{RST}  {r['remediation']}")

if not quiet:
    if appeared:
        print(f"\n  {YELLOW}New and not passing{RST}  ({len(appeared)})")
        for cid, r in appeared:
            line("+", YELLOW, cid, f"{r.get('status')}   {r.get('check','')}", r.get("detail", ""))
    if improved:
        print(f"\n  {GREEN}Improved{RST}  ({len(improved)})")
        for cid, was, now, r in improved:
            line("✔", GREEN, cid, f"{was} → {now}   {r.get('check','')}")
    if vanished:
        print(f"\n  {CYAN}No longer reported{RST}  ({len(vanished)})")
        for cid, r in vanished:
            line("·", CYAN, cid, r.get("check", ""))
    print("\n" + "─" * 68)
    if regressed:
        print(f"  {RED}{len(regressed)} regression(s){RST}, {len(improved)} improvement(s)\n")
    else:
        print(f"  {GREEN}Nothing regressed{RST}, {len(improved)} improvement(s)\n")

sys.exit(1 if regressed else 0)
PY
}
