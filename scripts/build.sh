#!/usr/bin/env bash
# =============================================================================
#  CyberAar Baseline — Build Script
#  Concatenates src/ files in order to produce cyberaar-baseline.sh.
#
#  Usage: bash scripts/build.sh
#  Output: scripts/cyberaar-baseline.sh (do not edit directly)
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${SCRIPT_DIR}/cyberaar-baseline.sh"

# Concatenation order is critical: shebang must come first, run.sh last.
PARTS=(
  src/main.sh
  src/lib/ansible_map.sh
  src/lib/remote.sh
  src/lib/core.sh
  src/checks/sys.sh
  src/checks/kernel.sh
  src/checks/auth.sh
  src/checks/ssh.sh
  src/checks/fs.sh
  src/checks/net.sh
  src/checks/log.sh
  src/checks/integrity.sh
  src/checks/compliance.sh
  src/renderers/terminal.sh
  src/renderers/json.sh
  src/renderers/html.sh
  src/run.sh
)

# Build
cat "${SCRIPT_DIR}/${PARTS[0]}" > "$OUT"
for f in "${PARTS[@]:1}"; do
  printf '\n' >> "$OUT"
  cat "${SCRIPT_DIR}/${f}" >> "$OUT"
done

# Validate
if bash -n "$OUT"; then
  printf "✅  Bundle OK: %s (%d lines)\n" "$OUT" "$(wc -l < "$OUT")"
else
  printf "❌  Syntax error in bundle — check src/ files\n"
  exit 1
fi
