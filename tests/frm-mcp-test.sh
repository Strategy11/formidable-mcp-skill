#!/bin/bash
# Offline test for the frm-mcp helper: the request body must reach curl over
# stdin, byte-for-byte, and never ride on a command line (Windows re-encodes
# non-ASCII arguments before curl and jq see them). Uses shims for curl and jq
# that record what they receive, so no site or credentials are needed.
#
# Usage: ./frm-mcp-test.sh        Requires: bash, jq. Exit code 0 = all pass.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FRM_MCP="$HERE/../skills/formidable-mcp/scripts/frm-mcp"
REAL_JQ="$(command -v jq)" || { echo "FATAL: jq not found" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/bin" "$WORK/log"

# curl shim: logs argv, captures stdin when asked to read it, and answers
# like the MCP endpoint (a session header, then a canned result).
cat > "$WORK/bin/curl" <<SHIM
#!/bin/bash
n=\$(ls "$WORK/log" | grep -c '^curl\.argv\.')
printf '%s\n' "\$@" > "$WORK/log/curl.argv.\$n"
case " \$* " in *" @- "*) cat > "$WORK/log/curl.stdin.\$n" ;; esac
case " \$* " in
  *" -i "*) printf 'HTTP/1.1 200 OK\r\nmcp-session-id: test-session\r\n\r\n' ;;
  *) printf '{"jsonrpc":"2.0","id":2,"result":{"structuredContent":{"success":true}}}' ;;
esac
SHIM

# jq shim: logs argv, then runs the real jq.
cat > "$WORK/bin/jq" <<SHIM
#!/bin/bash
printf '%s\n' "\$@" >> "$WORK/log/jq.argv"
exec "$REAL_JQ" "\$@"
SHIM
chmod +x "$WORK/bin/curl" "$WORK/bin/jq"

PASS=0; FAIL=0
check() { # check <name> <command...>
  local name="$1"; shift
  if "$@"; then PASS=$((PASS+1)); echo "  ✓ $name"
  else FAIL=$((FAIL+1)); echo "  ✗ $name"; fi
}

NEEDLE='prüfung'
BODY='{"form_id":"prüfung"}'

out=$(PATH="$WORK/bin:$PATH" SITE_URL="https://example.test" WP_USERNAME="u" \
  APPLICATION_PASSWORD="p" FRM_MCP_ENV=/dev/null FRM_MCP_CLIENT="test" \
  "$FRM_MCP" formidable-forms/list-fields "$BODY" 2>&1)
rc=$?

check "exits 0 with the canned result" test "$rc" -eq 0 -a "$(printf '%s' "$out" | jq -r '.success')" = "true"
check "no curl argument carries the body" bash -c '! grep -q "$1" "$2"/curl.argv.*' _ "$NEEDLE" "$WORK/log"
check "no jq argument carries the body" bash -c '! grep -qs "$1" "$2"/jq.argv' _ "$NEEDLE" "$WORK/log"
check "body reaches curl over stdin, UTF-8 intact" bash -c \
  'grep -q "\"form_id\":\"$1\"" "$2"/curl.stdin.*' _ "$NEEDLE" "$WORK/log"
check "stdin body is valid JSON wrapping the ability call" bash -c \
  '"$1" -e ".params.arguments.ability_name == \"formidable-forms/list-fields\" and .params.arguments.parameters.form_id == \"$2\"" "$3"/curl.stdin.* >/dev/null' _ "$REAL_JQ" "$NEEDLE" "$WORK/log"

echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
