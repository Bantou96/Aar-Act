#!/usr/bin/env bash
# Version consistency guard.
#
# The audit script was at 4.2.0 while every JSON report it wrote claimed
# "version": "4.0.0", because the renderer had the number typed into it as a
# literal. Nothing failed. The reports were valid, the number was simply wrong,
# and anything keying off it (a SIEM ingest, a comparison across tool versions,
# an auditor asking which build produced the evidence) was told something untrue
# for as long as the drift lasted.
#
# Numbers that must agree, agree here or the build fails.
#
# Run: bash scripts/tests/test_versions.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }
eq() {
  local what="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then ok; else bad "$what: got '$got', want '$want'"; fi
}

semver='^[0-9]+\.[0-9]+\.[0-9]+$'

# ── The declared versions ────────────────────────────────────────────────────
BASELINE_SRC=$(grep -oP '^SCRIPT_VERSION="\K[^"]+'   src/main.sh)
BASELINE_BIN=$(grep -oP '^SCRIPT_VERSION="\K[^"]+'   cyberaar-baseline.sh)
AARTOOL_SRC=$(grep -oP '^AARTOOL_VERSION="\K[^"]+'   aartool-src/main.sh)
AARTOOL_BIN=$(grep -oP '^AARTOOL_VERSION="\K[^"]+'   aartool)
COLLECTION=$(grep -oP '^version:\s*\K\S+'            ../ansible-hardening/galaxy.yml)

for v in "$BASELINE_SRC" "$AARTOOL_SRC" "$COLLECTION"; do
  [[ "$v" =~ $semver ]] && ok || bad "not a semver: '$v'"
done

# ── A generated bundle must carry its source's version ───────────────────────
# The bundles are built, not edited. If someone bumps the source and forgets to
# rebuild, the committed script keeps shipping the old number. CI already fails
# on bundle drift; this says which number is wrong when it does.
eq "cyberaar-baseline.sh bundle version" "$BASELINE_BIN" "$BASELINE_SRC"
eq "aartool bundle version"              "$AARTOOL_BIN"  "$AARTOOL_SRC"

# ── Reports must state the version that produced them ────────────────────────
# Not a literal. This is the bug the file exists for.
if grep -qF '"version": "${SCRIPT_VERSION}"' src/renderers/json.sh; then
  ok
else
  bad "the JSON renderer hardcodes a version instead of using \$SCRIPT_VERSION"
fi
if grep -qP '"version":\s*"[0-9]+\.[0-9]+\.[0-9]+"' src/renderers/json.sh; then
  bad "the JSON renderer still contains a literal version number"
else
  ok
fi

# The HTML report shows it too, and must interpolate for the same reason.
if grep -q 'v\${SCRIPT_VERSION}' src/renderers/html.sh; then ok
else bad "the HTML renderer does not interpolate SCRIPT_VERSION"; fi

# ── The container image tag follows the collection version ───────────────────
# The EE workflow reads galaxy.yml to tag the image. If it stopped doing that,
# the published image and the collection inside it would part company.
if grep -q "grep '\^version:' ansible-hardening/galaxy.yml" ../.github/workflows/ee-build.yml; then
  ok
else
  bad "ee-build.yml no longer derives the image tag from galaxy.yml"
fi

# ── The changelog has an entry for the collection version being shipped ──────
if grep -qF "## [${COLLECTION}]" ../ansible-hardening/CHANGELOG.md; then
  ok
else
  bad "CHANGELOG.md has no '## [${COLLECTION}]' entry for the version in galaxy.yml"
fi

# ── No version written down twice ────────────────────────────────────────────
# The JSON renderer was the obvious case and the one this file was written for.
# It was not the only one: src/main.sh carried 4.2.0 in a header comment, in the
# --help banner (inside a quoted heredoc, which is precisely why it could not
# drift back), and in the output of `--version` itself. So the canonical way of
# asking the tool its version returned a number three releases stale, on a
# release where the whole point was getting the numbers right.
#
# One place per version. Anything that looks like a semver outside the single
# assignment line has to justify itself, and the only legitimate matches so far
# are example IP addresses, which are excluded by requiring a v-prefix or a
# quote/space boundary rather than a digit-dot run inside an address.
for f in src/main.sh aartool-src/main.sh; do
  strays=$(grep -nP '(?<![0-9.])v?[0-9]+\.[0-9]+\.[0-9]+(?![0-9.])' "$f" \
           | grep -vP '^\s*[0-9]+:(SCRIPT|AARTOOL)_VERSION=' \
           | grep -vP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
           | grep -vP '(--host|--ansible-dir|/tmp/report-|10\.0\.)' || true)
  if [[ -z "$strays" ]]; then
    ok
  else
    bad "$f writes a version literal outside its VERSION assignment:"
    printf '%s\n' "$strays" | sed 's/^/        /'
  fi
done

# `--version` must report the declared version, not a string that happens to
# look like one. Run the built bundles and compare.
got=$(bash cyberaar-baseline.sh --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
eq "cyberaar-baseline.sh --version output" "$got" "$BASELINE_SRC"
got=$(bash aartool --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
eq "aartool --version output" "$got" "$AARTOOL_SRC"

# The --help banner too: it is the first thing a new user reads.
got=$(bash cyberaar-baseline.sh --help 2>/dev/null | grep -oP 'Baseline Checker v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
eq "cyberaar-baseline.sh --help banner" "$got" "$BASELINE_SRC"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
