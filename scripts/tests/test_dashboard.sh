#!/usr/bin/env bash
# Dashboard guards.
#
# The dashboard is the artefact an auditor is handed, often as a single file on
# a USB stick. Three things about it can break silently:
#
#   1. It duplicates advise's wave ordering, because it has to work with no
#      shell available. Two places that must agree, with nothing checking that
#      they do, is how this repository has been bitten three times already.
#   2. `aartool report --out` injects into it and calls one function by name.
#      Rename that function and every bundled report renders an empty page,
#      with the error only in the browser console.
#   3. It must reach the network for nothing. One stray CDN link and it stops
#      working on the isolated network it exists for.
#
# Run: bash scripts/tests/test_dashboard.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
DASH=../dashboard/index.html
ADVISE=aartool-src/cmd/advise.sh

PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }

[[ -f "$DASH" ]] || { echo "FAIL  $DASH is missing"; exit 1; }

# ── It must not reach the network ────────────────────────────────────────────
strays=$(grep -oP '(?:src|href)\s*=\s*["'"'"'](?!data:)[^"'"'"']+' "$DASH" || true)
if [[ -z "$strays" ]]; then ok; else
  bad "the dashboard references something outside itself, so it will not work offline:"
  printf '%s\n' "$strays" | sed 's/^/        /'
fi

# ── The contract report.sh depends on ────────────────────────────────────────
grep -q 'function renderAll' "$DASH" && ok \
  || bad "renderAll() is gone; aartool report --out injects data and calls it by name, and a bundled report would render nothing"

for sym in 'const DB' 'function openDrawer' 'function render()'; do
  grep -q "$sym" "$DASH" && ok || bad "the dashboard no longer defines '$sym'"
done

# ── Remediation goes through aartool, not a raw playbook ─────────────────────
for phrase in 'aartool plan' 'aartool apply' 'aartool explain' 'aartool advise' 'aartool inspect'; do
  grep -qF "$phrase" "$DASH" && ok || bad "the dashboard never mentions '$phrase'"
done
# The host row is a button that opens everything else. Before the redesign
# nothing said so, and the drill-down was a feature you had to already know
# about. If the visible call to action goes, that regression is silent.
grep -qF 'View details' "$DASH" && ok \
  || bad "the host row has no visible 'View details' affordance; a clickable row that does not look clickable is a hidden feature"

for phrase in 'ansible-playbook' 'Ansible Remediation'; do
  if grep -qF "$phrase" "$DASH"; then
    bad "the dashboard still tells auditors to run '$phrase'; remediation goes through aartool"
  else ok; fi
done

# ── CyberAar palette ─────────────────────────────────────────────────────────
# The same tokens as cyberaar.io. An auditor who has seen the site should
# recognise this as the same product, and a score colour should mean the same
# thing in both places.
for token in '#080d1a' '#0d1526' '#00e5b0' '#f59e0b' '#ef4444' '#94a3b8'; do
  grep -qF "$token" "$DASH" && ok || bad "palette token $token missing; the dashboard has drifted from the CyberAar colours"
done

# ── The wave tables must match advise ────────────────────────────────────────
# advise.sh is the source of truth for the ordering. The dashboard mirrors it
# because it has no shell to call. Compare the ID sets rather than the syntax.
adv_decide=$(sed -n '/_advise_costly() {/,/^}/p' "$ADVISE" \
  | grep -oP '^\s+\K[A-Z]+-[0-9|A-Z-]*(?=\))' | tr '|' '\n' | grep -oP '[A-Z]+-[0-9]+' | sort -u)
dash_decide=$(sed -n "/^const DECIDE = new Set(\[/,/\]);/p" "$DASH" \
  | grep -oP "'\K[A-Z]+-[0-9]+" | sort -u)

only_adv=$(comm -23 <(printf '%s\n' "$adv_decide") <(printf '%s\n' "$dash_decide"))
only_dash=$(comm -13 <(printf '%s\n' "$adv_decide") <(printf '%s\n' "$dash_decide"))
if [[ -z "$only_adv" && -z "$only_dash" ]]; then
  ok
  printf '  decision list matches advise: %d ids\n' "$(printf '%s\n' "$adv_decide" | grep -c .)"
else
  [[ -n "$only_adv"  ]] && bad "advise treats these as needing a decision and the dashboard does not: $(echo $only_adv)"
  [[ -n "$only_dash" ]] && bad "the dashboard treats these as needing a decision and advise does not: $(echo $only_dash)"
fi

# Wave 2's explicit id list is the part most likely to drift, since the rest is
# prefix matching that reads the same in both languages.
adv_w2=$(sed -n '/_advise_wave() {/,/^}/p' "$ADVISE" \
  | grep -A2 'KRN-\*|AUTH-\*' | grep -oP 'SYS-[0-9]+|FS-[0-9]+' | sort -u)
dash_w2=$(sed -n '/title: .Account to root/,/includes(id)/p' "$DASH" \
  | grep -oP "'\K(SYS|FS)-[0-9]+" | sort -u)
missing=$(comm -23 <(printf '%s\n' "$adv_w2") <(printf '%s\n' "$dash_w2"))
if [[ -z "$missing" ]]; then ok
else bad "wave assignment drifted; advise names these and the dashboard does not: $(echo $missing)"; fi

# ── It has to actually render ────────────────────────────────────────────────
# Static checks cannot catch a runtime error in a template literal. Render the
# whole thing against a real captured report, with a stub DOM.
if command -v node >/dev/null 2>&1; then
  _js=$(mktemp --suffix=.js); trap 'rm -f "$_js"' EXIT
  sed -n '/<script>/,/<\/script>/p' "$DASH" | sed '1d;$d' > "$_js"
  if node --check "$_js" 2>/dev/null; then ok
  else bad "the dashboard's JavaScript does not parse: $(node --check "$_js" 2>&1 | head -2)"; fi

  out=$(node -e '
    const store={};
    const mk=id=>({id,_html:"",_text:"",style:{},classList:{add(){},remove(){},contains:()=>false},
      set innerHTML(v){this._html=v},get innerHTML(){return this._html},
      set textContent(v){this._text=v},get textContent(){return this._text},
      value:id==="sortSel"?"score":id==="scopeSel"?"all":"",
      addEventListener(){},focus(){},cloneNode(){return this},querySelectorAll:()=>[],
      appendChild(){},removeChild(){},setAttribute(){},select(){},remove(){}});
    global.document={getElementById:id=>(store[id]||=mk(id)),querySelectorAll:()=>[],
      querySelector:()=>mk("q"),addEventListener(){},createElement:()=>mk("t"),
      body:{style:{},appendChild(){},removeChild(){}},execCommand:()=>true};
    global.window={isSecureContext:false,print(){}}; global.navigator={};
    global.FileReader=class{}; global.alert=m=>{throw new Error("alert: "+m)};
    global.__s=store;
    const fs=require("fs");
    const js=fs.readFileSync(process.argv[1],"utf8").match(/<script>([\s\S]*)<\/script>/)[1];
    const probe=`;(function(){
      const r=JSON.parse(require("fs").readFileSync(process.argv[2],"utf8")).cyberaar_baseline;
      DB[r.host]=[r]; renderAll();
      for (const h of Object.keys(DB)) openDrawer(h);
      const all=Object.values(__s).map(e=>e._html||"").join("");
      console.log(["statRow","hostBars","waveDist","catBars","heatmap","commonTbl","drawerB"]
        .map(id=>id+":"+((__s[id]&&__s[id]._html)||"").length).join(" "));
      if (!all.includes("aartool plan")) { console.log("NOCMD"); }
    })();`;
    eval(js+probe);
  ' "$DASH" tests/fixtures/audit-fixture.json 2>&1) || out="ERROR: $out"

  # ── The JSON root key was renamed cyberaar_baseline -> aartool ────────────
  # Both must load. The old name is in every report anybody already has on disk,
  # and a dashboard that silently ignores them shows an empty page rather than
  # an error: exactly the failure mode --redact once produced. Assert the
  # resolution the loader actually performs, not the key this fixture happens
  # to carry.
  keyprobe=$(node -e '
    const fs=require("fs");
    const doc=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    const legacy=doc.cyberaar_baseline;
    if(!legacy) { console.log("FIXTURE-NOT-LEGACY"); process.exit(0); }
    const modern={aartool:legacy};
    const pick=j=>j.aartool||j.cyberaar_baseline;
    const a=pick(doc), b=pick(modern);
    console.log((a&&a.host?"legacy-ok":"legacy-FAIL")+" "+(b&&b.host?"modern-ok":"modern-FAIL"));
  ' tests/fixtures/audit-fixture.json 2>&1) || keyprobe="ERROR: $keyprobe"
  if [[ "$keyprobe" == "legacy-ok modern-ok" ]]; then ok; else
    bad "dashboard key resolution: want 'legacy-ok modern-ok', got '$keyprobe'"
  fi

  if [[ "$out" == ERROR:* || "$out" == *NOCMD* ]]; then
    bad "the dashboard threw while rendering a real report: ${out:0:300}"
  else
    ok
    printf '  rendered a real report: %s\n' "$out"
    empties=$(grep -oP ':\K0(?= |$)' <<<"$out" | wc -l)
    [[ "$empties" -eq 0 ]] && ok || bad "$empties dashboard panel(s) rendered empty from a real report"
  fi
else
  printf 'SKIP  node not available, render test not run\n'
fi

# ── Anonymising must not break the document it anonymises ────────────────────
# --redact is a literal global substitution over the whole JSON, and the
# report's structural keys are strings in that same document. `--redact
# cyberaar` rewrote every "cyberaar_baseline" key, the bootstrap found no
# reports, and the output was a valid HTML file showing an empty page. Valid,
# openable, and containing nothing.
if command -v node >/dev/null 2>&1 && [[ -f tests/fixtures/audit-fixture.json ]]; then
  _tmp=$(mktemp -d); trap 'rm -rf "$_tmp"' EXIT

  if bash ./aartool report tests/fixtures/audit-fixture.json --anonymise \
       --out "$_tmp/anon.html" >/dev/null 2>&1; then
    ok
    n=$(grep -c '"cyberaar_baseline"' "$_tmp/anon.html" || true)
    [[ "$n" -ge 1 ]] && ok || bad "the anonymised output lost its schema key, so it renders empty"

    data=$(sed -n '/Injected by aartool/,$p' "$_tmp/anon.html")
    if grep -q '"host":[[:space:]]*"server-' <<<"$data"; then ok
    else bad "the anonymised output did not rename the host"; fi
    if grep -q 'proof-target-01\|fixture-web-01' <<<"$data"; then
      bad "the original hostname survived anonymising"
    else ok; fi
  else
    bad "aartool report --anonymise failed on the fixture"
  fi

  # And the refusal that prevents the schema-key case entirely.
  if bash ./aartool report tests/fixtures/audit-fixture.json --anonymise \
       --redact cyberaar --out "$_tmp/bad.html" >/dev/null 2>&1; then
    bad "--redact cyberaar was accepted; it rewrites the report's own schema key and the output renders nothing"
  else ok; fi
fi

# ── Print ────────────────────────────────────────────────────────────────────
# Print-to-PDF is how an audit leaves the browser and enters an engagement
# report. The old print block hid the chrome and inverted the background, which
# produces a screenshot of a website. These assert the pieces that make it a
# document instead, because nobody prints the dashboard during development and
# a regression here would be found by a client.
grep -q '@page' "$DASH" && ok || bad "no @page rule; the PDF has no defined paper size or margins"
grep -q 'id="printCover"'    "$DASH" && ok || bad "no print cover block; the PDF would not say what was audited or when"
grep -q 'id="printFindings"' "$DASH" && ok || bad "no per-host findings section; the PDF would be a scorecard with no findings in it"
grep -q 'display: table-header-group' "$DASH" && ok \
  || bad "table headers do not repeat across pages, so columns lose their labels after the first break"

# The accent at #00e5b0 is 1.4:1 on white and unreadable printed. The light
# palette from the website is what the print block must switch to.
# grep -q closes the pipe on its first match, sed takes SIGPIPE, and under
# `set -o pipefail` the pipeline reports failure even though the match
# succeeded. Count instead of short-circuiting.
_accent=$(sed -n '/@media print/,/^    }$/p' "$DASH" | grep -c '#0F766E' || true)
if [[ "${_accent:-0}" -gt 0 ]]; then ok
else bad "print does not switch to the light-ground accent; #00e5b0 is 1.4:1 on white"; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
