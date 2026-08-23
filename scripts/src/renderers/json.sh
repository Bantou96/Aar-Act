# =============================================================================
#  JSON RENDERER
#  Iterates RESULT_* parallel arrays to build the JSON report file.
# =============================================================================
_render_json() {
  [[ -z "$JSON_OUT" ]] && return

  local n="${#RESULT_ID[@]}"
  local JSON_ARR="["
  for (( i=0; i<n; i++ )); do
    # JSON-escape: backslash first, then double-quote, then strip newlines
    local de="${RESULT_DETAIL[$i]//\\/\\\\}"
    de="${de//\"/\\\"}"; de="${de//$'\n'/ }"
    local re="${RESULT_REMEDIATION[$i]//\\/\\\\}"
    re="${re//\"/\\\"}"; re="${re//$'\n'/ }"
    local ne="${RESULT_NAME_EN[$i]//\\/\\\\}"
    ne="${ne//\"/\\\"}"
    JSON_ARR+="{\"id\":\"${RESULT_ID[$i]}\",\"category\":\"${RESULT_CATEGORY[$i]}\",\"status\":\"${RESULT_STATUS[$i]}\",\"check\":\"${ne}\",\"detail\":\"${de}\",\"remediation\":\"${re}\"}"
    [[ $i -lt $((n-1)) ]] && JSON_ARR+=","
  done
  JSON_ARR+="]"

  # Values that come from the audited machine or from the command line. A quote
  # in any of them breaks the document or injects a key.
  local _j_host _j_os _j_inv
  _j_host=$(json_escape "$HOSTNAME_VAL")
  _j_os=$(json_escape "$OS_VAL")
  _j_inv=$(json_escape "${ANSIBLE_INVENTORY:-inventory/hosts}")

  cat > "$JSON_OUT" <<EOF
{
  "cyberaar_baseline": {
    "version": "${SCRIPT_VERSION}",
    "host": "${_j_host}",
    "os": "${_j_os}",
    "date": "${DATE_VAL}",
    "score": ${SCORE},
    "summary": {
      "pass": ${PASS},
      "warn": ${WARN},
      "fail": ${FAIL},
      "total": ${TOTAL}
    },
    "results": ${JSON_ARR},
    "ansible_remediation": {
      "fail_ids": [$(printf '"%s",' "${FAIL_IDS[@]}" | sed 's/,$//')],
      "warn_ids": [$(printf '"%s",' "${WARN_IDS[@]}" | sed 's/,$//')],
      "playbook": "playbooks/2_configure_hardening.yml",
      "inventory": "${_j_inv}"
    }
  }
}
EOF
  chmod 600 "$JSON_OUT"
  printf "  📄 JSON: %s\n" "$JSON_OUT"
}
