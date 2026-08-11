#!/bin/bash
# Formidable MCP smoke test — verifies a site's formidable-api plugin supports
# everything the formidable skill documents. Creates scratch objects, asserts,
# and deletes them (also on abort).
#
# Usage:
#   ./smoke-test.sh
#
# Configuration comes from the skill's scripts/frm-mcp.env (SITE_URL,
# WP_USERNAME, APPLICATION_PASSWORD) — the same file the frm-mcp helper reads,
# so credentials stay out of the command line and shell history. FRM_MCP_URL and
# FRM_MCP_AUTH still override it for CI, where the values come from a secret
# store rather than being typed.
#
# Run this against a DEVELOPMENT site — it creates and deletes real objects.
#
# TLS is verified by default. For a local self-signed certificate, trust the
# environment's CA, or set FRM_MCP_CACERT=/path/to/ca.pem. FRM_MCP_INSECURE=1
# skips verification altogether — local hosts only.
#
# Requires: curl, jq. Exit code 0 = all pass.

set -u

# Fall back to the skill's local config file when the env vars aren't set.
ENV_FILE="$(cd "$(dirname "$0")" && pwd)/../skills/formidable-mcp/scripts/frm-mcp.env"
if [ -z "${FRM_MCP_URL:-}" ] || [ -z "${FRM_MCP_AUTH:-}" ]; then
  if [ -f "$ENV_FILE" ]; then
    SITE_URL=""; WP_USERNAME=""; APPLICATION_PASSWORD=""
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    [ -n "$SITE_URL" ] && FRM_MCP_URL="${FRM_MCP_URL:-${SITE_URL%/}/wp-json/mcp/formidable-mcp}"
    [ -n "$WP_USERNAME" ] && FRM_MCP_AUTH="${FRM_MCP_AUTH:-$WP_USERNAME:$APPLICATION_PASSWORD}"
  fi
fi

: "${FRM_MCP_URL:?Set SITE_URL in skills/formidable-mcp/scripts/frm-mcp.env (or FRM_MCP_URL)}"
: "${FRM_MCP_AUTH:?Set WP_USERNAME + APPLICATION_PASSWORD in frm-mcp.env (or FRM_MCP_AUTH)}"

# TLS options for every curl below. Expanded with the ${arr[@]+...} guard because
# bash 3.2 (stock on macOS) errors on a bare "${arr[@]}" for an empty array under `set -u`.
TLS_OPTS=()
if [ -n "${FRM_MCP_CACERT:-}" ]; then
  TLS_OPTS+=(--cacert "$FRM_MCP_CACERT")
elif [ "${FRM_MCP_INSECURE:-0}" = "1" ]; then
  case "$FRM_MCP_URL" in
    https://*.local/*|https://*.test/*|https://localhost*|https://127.0.0.1*)
      TLS_OPTS+=(-k) ;;
    *)
      echo "FATAL: refusing FRM_MCP_INSECURE=1 for a non-local host." >&2
      echo "       Trust the site's CA or set FRM_MCP_CACERT instead." >&2
      exit 2 ;;
  esac
fi

PASS=0; FAIL=0; FAILED_NAMES=()
FORM_ID=""; CHILD_ID=""; VIEW_ID=""; STYLE_ID=""; ACTION_ID=""; APP_ID=""; ENTRY_ID=""

SESSION=$(curl -s -i -X POST "$FRM_MCP_URL" -u "$FRM_MCP_AUTH" -H 'Content-Type: application/json' \
  --data-binary '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}},"id":1}' \
  ${TLS_OPTS[@]+"${TLS_OPTS[@]}"} 2>&1 | grep -i "mcp-session-id" | cut -d' ' -f2 | tr -d '\r')
[ -n "$SESSION" ] || { echo "FATAL: could not initialize MCP session"; exit 2; }

mcp() { # mcp <ability> <params-json> -> structuredContent JSON on stdout
  curl -s -X POST "$FRM_MCP_URL" -H "Content-Type: application/json" -H "Mcp-Session-Id: $SESSION" -u "$FRM_MCP_AUTH" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"mcp-adapter-execute-ability\",\"arguments\":{\"ability_name\":\"formidable-forms/$1\",\"parameters\":$2}},\"id\":2}" \
    ${TLS_OPTS[@]+"${TLS_OPTS[@]}"} | jq -c '.result.structuredContent // {success:false,error:(.result.content[0].text // .error.message // "unknown")}'
}

check() { # check <name> <actual> <expected-substring-or-value>
  if [[ "$2" == *"$3"* ]]; then PASS=$((PASS+1)); echo "  ✓ $1"
  else FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); echo "  ✗ $1  (got: ${2:0:160})"; fi
}

cleanup() {
  echo "--- cleanup ---"
  [ -n "$APP_ID" ]    && mcp delete-application "{\"application_id\":$APP_ID}" >/dev/null
  [ -n "$ACTION_ID" ] && mcp delete-form-action "{\"id\":\"$ACTION_ID\"}" >/dev/null
  [ -n "$VIEW_ID" ]   && mcp delete-view "{\"id\":\"$VIEW_ID\"}" >/dev/null
  [ -n "$STYLE_ID" ]  && mcp delete-style "{\"id\":\"$STYLE_ID\"}" >/dev/null
  [ -n "$CHILD_ID" ]  && mcp delete-form "{\"id\":\"$CHILD_ID\"}" >/dev/null
  [ -n "$FORM_ID" ]   && mcp delete-form "{\"id\":\"$FORM_ID\"}" >/dev/null
  echo "scratch objects removed"
}
trap cleanup EXIT

echo "=== Forms ==="
R=$(mcp create-form '{"name":"Smoke Test Form"}')
FORM_ID=$(jq -r '.data.id // empty' <<<"$R"); check "create-form" "$R" '"success":true'
R=$(mcp create-form "{\"name\":\"Smoke Child\",\"parent_form_id\":$FORM_ID}")
CHILD_ID=$(jq -r '.data.id // empty' <<<"$R")
check "create-form with parent_form_id" "$(jq -r '.data.parent_form_id' <<<"$R")" "$FORM_ID"
R=$(mcp update-form "{\"id\":\"$CHILD_ID\",\"name\":\"Smoke Child v2\",\"parent_form_id\":0}")
check "update-form rename+detach" "$(jq -r '[.data.name, (.data.parent_form_id|tostring)] | join("/")' <<<"$R")" "Smoke Child v2/0"
R=$(mcp get-form "{\"id\":\"$FORM_ID\"}"); check "get-form" "$R" '"success":true'
R=$(mcp list-forms '{"search":"Smoke Test Form"}'); check "list-forms" "$R" '"success":true'

echo "=== Fields ==="
R=$(mcp create-field "{\"form_id\":\"$FORM_ID\",\"type\":\"radio\",\"name\":\"Priority\",\"options\":[{\"label\":\"Low\",\"value\":\"low\"},{\"label\":\"High\",\"value\":\"high\"}]}")
check "create-field object options" "$R" '"success":true'
FIELD_ID=$(mcp list-fields "{\"form_id\":\"$FORM_ID\"}" | jq -r '[.data[]][0].id')
check "list-fields returns field" "$FIELD_ID" "$FIELD_ID"
R=$(mcp update-field "{\"id\":\"$FIELD_ID\",\"options\":[{\"label\":\"Low\",\"value\":\"low\"},{\"label\":\"Mid\",\"value\":\"mid\"},{\"label\":\"High\",\"value\":\"high\"}]}")
check "update-field without form_id" "$R" '"success":true'
R=$(mcp list-fields "{\"form_id\":\"$FORM_ID\"}" | jq -c '[.data[]][0].options')
check "update-field options persisted" "$R" '"Mid"'

echo "=== Entries & Stats ==="
R=$(mcp create-entry "{\"form_id\":\"$FORM_ID\",\"$FIELD_ID\":\"high\"}")
ENTRY_ID=$(jq -r '.data.id // empty' <<<"$R"); check "create-entry" "$R" '"success":true'
R=$(mcp get-entry "{\"id\":\"$ENTRY_ID\"}"); check "get-entry" "$R" '"success":true'
R=$(mcp list-entries "{\"form_id\":\"$FORM_ID\"}"); check "list-entries" "$R" '"success":true'
R=$(mcp get-stats "{\"field_id\":\"$FIELD_ID\",\"type\":\"count\"}")
check "get-stats count=1" "$(jq -r ".data.\"$FIELD_ID\" // .data | tostring" <<<"$R")" "1"

echo "=== Views ==="
# status is passed explicitly — create-view defaults to "private" (matching the
# product), so asserting "publish" without sending it tests nothing but the default.
R=$(mcp create-view "{\"form_id\":\"$FORM_ID\",\"name\":\"Smoke View\",\"content\":\"<tr><td>[$FIELD_ID]</td></tr>\",\"before_content\":\"<table><tbody>\",\"after_content\":\"</tbody></table>\",\"limit\":1,\"status\":\"publish\",\"options\":{\"empty_msg\":\"None found\"}}")
VIEW_ID=$(jq -r '.data.id // empty' <<<"$R")
check "create-view one-call" "$(jq -r '[.data.status, (.data.limit|tostring)] | join("/")' <<<"$R")" "publish/1"
R=$(mcp update-view "{\"id\":\"$VIEW_ID\",\"content\":\"<p>updated [$FIELD_ID]</p>\",\"limit\":2}")
check "update-view content+limit" "$(jq -r '[.data.content, (.data.limit|tostring)] | join("/")' <<<"$R")" "updated [$FIELD_ID]</p>/2"
R=$(mcp get-view "{\"id\":\"$VIEW_ID\"}")
check "get-view roundtrip" "$(jq -r '.data.content' <<<"$R")" "updated"
R=$(mcp list-views '{}'); check "list-views" "$R" '"success":true'

echo "=== Styles ==="
R=$(mcp create-style '{"name":"Smoke Style","post_content":{"submit_bg_color":"D67B9F"}}')
STYLE_ID=$(jq -r '.data.id // empty' <<<"$R")
check "create-style with properties" "$(jq -r '.data.post_content.submit_bg_color // .data.submit_bg_color' <<<"$R")" "D67B9F"
R=$(mcp update-style "{\"id\":\"$STYLE_ID\",\"post_content\":{\"submit_bg_color\":\"00FF00\"}}")
check "update-style" "$R" '"success":true'
R=$(mcp get-style "{\"id\":\"$STYLE_ID\"}")
check "update-style persisted" "$(jq -r '.data.post_content.submit_bg_color // .data.submit_bg_color' <<<"$R")" "00FF00"
R=$(mcp assign-style-to-form "{\"form_id\":\"$FORM_ID\",\"style_id\":\"$STYLE_ID\"}")
check "assign-style-to-form" "$R" '"success":true'

echo "=== Form Actions ==="
R=$(mcp create-form-action "{\"form_id\":\"$FORM_ID\",\"type\":\"email\",\"post_content\":{\"email_to\":\"[default-email]\",\"email_message\":\"Original\",\"event\":[\"create\"]}}")
ACTION_ID=$(jq -r '.data.id // .data.ID // empty' <<<"$R"); check "create-form-action" "$R" '"success":true'
R=$(mcp update-form-action "{\"id\":\"$ACTION_ID\",\"post_content\":{\"email_message\":\"Updated\"}}")
check "update-form-action merges" "$(jq -r '[.data.post_content.email_message, .data.post_content.email_to] | join("/")' <<<"$R")" "Updated/[default-email]"
R=$(mcp get-form-action "{\"id\":\"$ACTION_ID\"}"); check "get-form-action (action survives)" "$R" '"success":true'
R=$(mcp list-form-actions "{\"form_id\":\"$FORM_ID\"}")
check "list-form-actions finds it" "$R" "$ACTION_ID"

echo "=== Applications (Pro) ==="
R=$(mcp create-application '{"name":"Smoke App"}')
APP_ID=$(jq -r '.data.id // empty' <<<"$R")
if [ -n "$APP_ID" ]; then
  check "create-application" "$R" '"success":true'
  R=$(mcp add-item-to-application "{\"application_id\":$APP_ID,\"item_id\":$FORM_ID,\"item_type\":\"form\"}")
  check "add form to application" "$R" '"success":true'
  R=$(mcp add-item-to-application "{\"application_id\":$APP_ID,\"item_id\":$VIEW_ID,\"item_type\":\"view\"}")
  check "add view to application" "$R" '"success":true'
  R=$(mcp list-application-items "{\"application_id\":$APP_ID}")
  check "list-application-items" "$(jq -r '[.data.items[].type] | sort | join(",")' <<<"$R")" "form,view"
  R=$(mcp remove-item-from-application "{\"application_id\":$APP_ID,\"item_id\":$VIEW_ID,\"item_type\":\"view\"}")
  check "remove-item-from-application" "$R" '"success":true'
else
  echo "  - applications skipped (Pro not active or ability unavailable)"
fi

echo
echo "=============================="
echo "PASS: $PASS   FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'failed: %s\n' "${FAILED_NAMES[@]}"
  trap - EXIT; cleanup; exit 1
fi
