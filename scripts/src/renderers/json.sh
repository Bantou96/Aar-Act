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
    JSON_ARR+="{\"id\":\"${RESULT_ID[$i]}\",\"category\":\"${RESULT_CATEGORY[$i]}\",\"status\":\"${RESULT_STATUS[$i]}\",\"wave\":$(_wave_of "${RESULT_ID[$i]}"),\"check\":\"${ne}\",\"detail\":\"${de}\",\"remediation\":\"${re}\"}"
    [[ $i -lt $((n-1)) ]] && JSON_ARR+=","
  done
  JSON_ARR+="]"

  # The tag each finding is remediated by, so a consumer of this report can
  # build a working `aartool plan --only ...` without carrying its own copy of
  # ANSIBLE_MAP. The dashboard did exactly that duplication and it is the same
  # drift that has bitten this repository three times: two places that must
  # agree, with nothing checking that they do. Only ids that appear in this
  # report are emitted, so the object stays small.
  local _j_tags="{" _j_first=1 _j_id _j_tag
  local -A _j_seen=()
  for (( i=0; i<n; i++ )); do
    _j_id="${RESULT_ID[$i]}"
    [[ -n "${_j_seen[$_j_id]:-}" ]] && continue
    _j_seen[$_j_id]=1
    _j_tag="${ANSIBLE_MAP[$_j_id]:-}"
    [[ -z "$_j_tag" ]] && continue          # deliberately unmapped, see the map
    _j_tag="${_j_tag%%|*}"                  # tags field
    _j_tag="${_j_tag%%,*}"                  # the one `--only` should use
    [[ -z "$_j_tag" ]] && continue
    [[ $_j_first -eq 0 ]] && _j_tags+=","
    _j_tags+="\"${_j_id}\":\"${_j_tag}\""
    _j_first=0
  done
  _j_tags+="}"

  # Values that come from the audited machine or from the command line. A quote
  # in any of them breaks the document or injects a key.
  local _j_host _j_os _j_inv
  _j_host=$(json_escape "$HOSTNAME_VAL")
  _j_os=$(json_escape "$OS_VAL")
  _j_inv=$(json_escape "${ANSIBLE_INVENTORY:-inventory/hosts}")

  cat > "$JSON_OUT" <<EOF
{
  "aartool": {
    "version": "${SCRIPT_VERSION}",
    "host": "${_j_host}",
    "os": "${_j_os}",
    "date": "${DATE_VAL}",
    "date_iso": "${DATE_ISO}",
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
    },
    "remediation_tags": ${_j_tags}
  }
}
EOF
  chmod 600 "$JSON_OUT"
  printf "  📄 JSON: %s\n" "$JSON_OUT"
}
