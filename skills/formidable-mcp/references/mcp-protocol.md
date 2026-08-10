# Formidable MCP Adapter: Protocol, Setup & Abilities

Read this when: you need to connect to, configure, or call the Formidable Forms MCP adapter — protocol/session details, the wp-cli stdio bridge, the full abilities catalog, error solutions, or the access policy governing MCP vs REST vs SQL.

## Access policy (mandatory)

- **Use the Formidable MCP exclusively for ALL operations** — creates, updates, deletes, and normal reads. **Never fall back to the Formidable REST API** (`/wp-json/frm/v3/` current or `/wp-json/frm/v2/` legacy endpoints). MCP is the intended abstraction layer; REST fallbacks circumvent its validation and permission model.
- Recommended: enforce this in your project by **deny-listing** the REST endpoints in `.claude/settings.json`, leaving only the MCP endpoint reachable by curl:
  ```json
  "deny": [
    "Bash(curl * /wp-json/frm*)",
    "Bash(curl * /wp-json/)"
  ]
  ```
  With those rules in place, any attempt to curl other `/wp-json/` routes is blocked by the permission system.
- **Direct SQL is acceptable for read-only verification queries only** (e.g., inspecting the raw `post_content` of a View or serialized style properties at the DB level). Never use SQL inserts/updates as a workaround when MCP fails — investigate the MCP error instead.
- If an MCP tool isn't exposing its abilities, **diagnose the MCP configuration** rather than routing around it (don't install packages manually, don't switch to REST, don't script direct DB writes). Workarounds mask the real problem and don't persist to future sessions.
- For verifying WordPress admin state programmatically, prefer MCP abilities (`list-forms`, `get-form`, etc.) over browser-based admin-page authentication — MCP bypasses the login redirect entirely.
- If MCP endpoints are unavailable or undocumented for a task, ask the user rather than switching to REST.

## Protocol overview

- **Protocol:** MCP over JSON-RPC 2.0
- **Protocol version:** `2024-11-25`
- **Transports:** HTTP POST (REST-routed MCP endpoint) or stdio via WP-CLI
- **Content-Type:** `application/json`
- **Session management (HTTP):** header-based (`mcp-session-id`); sessions expire after inactivity
- **Abilities:** registered via the WordPress Abilities API, namespaced `formidable-forms/<action>`, each marked `mcp.public => true` and `show_in_rest => true`

## Choosing a transport

| Transport | Use when | Needs |
|---|---|---|
| **HTTP endpoint (curl)** | You do NOT have shell access to the WordPress server — remote/production sites, shared hosting. **The most common case.** | An application password for an admin user; nothing but curl (+ jq) locally |
| **WP-CLI stdio bridge** | You have a shell on the machine hosting WordPress (typical for local dev sites) | wp-cli and filesystem access to the install |

Both transports expose identical abilities and accept identical `tools/call` bodies — every `ability_name`/`parameters` example in this skill's references works verbatim on either transport. Only the wrapping differs: HTTP needs Basic Auth + a session header; stdio needs neither.

## Transport 1: WP-CLI stdio bridge (server shell access)

Run the adapter as a local stdio MCP server through WP-CLI — no HTTP auth or session headers needed.

### Claude Code config (`.mcp.json`)

```json
{
  "formidable": {
    "type": "stdio",
    "command": "wp",
    "args": [
      "--path=/path/to/wordpress",
      "mcp-adapter",
      "serve",
      "--server=formidable-mcp",
      "--user=1"
    ],
    "env": {}
  }
}
```

Key points:
- `--path` — absolute path to the WordPress install root
- `--server=formidable-mcp` — the registered MCP server name
- `--user=1` — WordPress user ID to run as (an admin, for permission callbacks)
- Use the full path to the `wp` binary if it isn't on PATH (e.g., a Homebrew install)

### Ad-hoc CLI usage (piped JSON-RPC)

Pipe newline-delimited JSON-RPC requests via stdin; responses come back on stdout, one per line:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/list-forms","parameters":{}}}}' \
  | wp --path="/path/to/wordpress" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null \
  | tail -1 | jq '.'
```

- Multiple requests can be piped in one command; use `tail -N` to grab the last N responses
- `2>/dev/null` suppresses PHP deprecation warnings that would corrupt JSON parsing
- Extract data: `response['result']['content'][0]['text']`, then parse that string as JSON

## Transport 2: HTTP endpoint (curl)

**Endpoint:** `https://your-site.local/wp-json/mcp/formidable-mcp`

**Authentication:** HTTP Basic Auth with a WordPress username and an application password:

```
-u "USERNAME:APPLICATION_PASSWORD"
```

### Creating an application password

1. WP Admin → **Users → Profile** (of an **administrator** — the ability permission callbacks check real capabilities, so a low-role user's password will get 403s on most abilities)
2. Scroll to **Application Passwords**, enter a name (e.g. `formidable-mcp`), click **Add New Application Password**
3. Copy the generated password immediately (shown once). Spaces in it are fine — pass it as-is inside quotes: `-u "admin:xxxx xxxx xxxx xxxx xxxx xxxx"`

Requirements & hosting gotchas:

- **WordPress requires HTTPS** for application passwords by default (local `.local`/`.test` environments are exempted as "local"). If the Application Passwords section is missing from the profile screen, the site is plain HTTP on a non-local host.
- **Self-signed certs** (Local by Flywheel, Laravel Valet, etc.): add `-k` to every curl call.
- **Some hosts strip the `Authorization` header** before it reaches PHP (common on Apache CGI/FastCGI). Symptom: valid credentials always return `401`/`rest_not_logged_in`. Fix in `.htaccess`: `SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1` (or `CGIPassAuth On` on Apache 2.4.13+).
- The MCP endpoint is served by the Formidable API add-on's MCP adapter — if `/wp-json/mcp/formidable-mcp` 404s, confirm that plugin is active and permalinks aren't set to "Plain".

### Step 1 — Initialize a session

```bash
curl -s -i -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -u "USERNAME:APPLICATION_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-25",
      "capabilities": {},
      "clientInfo": {"name": "claude", "version": "1.0"}
    },
    "id": 1
  }' 2>&1 | grep "mcp-session-id" | cut -d' ' -f2 | tr -d '\r'
```

**Critical:** the session ID comes back in the `mcp-session-id` HTTP **response header**, not the JSON body. Extract it and reuse it.

### Step 2 — Include the session header on every subsequent call

```
-H "Mcp-Session-Id: {session-id-from-step-1}"
```

### Step 3 (recommended) — use the bundled helper script

Sessions expire after inactivity, and hand-rolling every curl call is error-prone. **This skill ships a ready-to-use wrapper at `scripts/frm-mcp`** — it caches the session, auto-re-initializes on expiry, normalizes the response envelope, and takes the ability name plus a pretty-printed JSON body (YAML also accepted), so permission prompts stay readable:

```bash
./scripts/frm-mcp formidable-forms/list-forms
./scripts/frm-mcp formidable-forms/create-entry '{"form_id": "123", "456": "value"}'
```

Site URL and credentials come from `SITE_URL`, `WP_USERNAME`, and `APPLICATION_PASSWORD` env vars, or a `frm-mcp.env` file next to the script (machine-specific — gitignored, never committed). Secrets never appear on the command line, so they never show in permission prompts either. A permissions tip for Claude Code: prefix-based Bash allow rules can permanently allow read-only calls (`frm-mcp formidable-forms/list-*`, `get-*`) while `create-*`/`update-*`/`delete-*` still prompt.

The equivalent inline recipe, if you can't use the bundled file (it is the same logic):

```bash
#!/bin/bash
# mcp.sh — usage: ./mcp.sh <ability-name> '<json-parameters>'
# e.g.:    ./mcp.sh formidable-forms/list-forms '{}'
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
URL="https://your-site.local/wp-json/mcp/formidable-mcp"
AUTH="USERNAME:APPLICATION_PASSWORD"
SESSION_FILE="$DIR/.mcp-session"

init_session() {
  curl -s -i -k -X POST "$URL" \
    -H "Content-Type: application/json" \
    -u "$AUTH" \
    -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}},"id":1}' \
    2>/dev/null | grep -i "mcp-session-id" | head -1 | cut -d' ' -f2 | tr -d '\r' > "$SESSION_FILE"
}

call() {
  local ability="$1" params="$2" body
  body=$(jq -n --arg a "$ability" --argjson p "$params" \
    '{jsonrpc:"2.0",method:"tools/call",params:{name:"mcp-adapter-execute-ability",arguments:{ability_name:$a,parameters:$p}},id:2}')
  curl -s -k -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Mcp-Session-Id: $(cat "$SESSION_FILE" 2>/dev/null || true)" \
    -u "$AUTH" -d "$body" 2>/dev/null
}

ability="$1"; params="${2:-{\}}"
out=$(call "$ability" "$params")
if echo "$out" | grep -qiE 'session not found|Missing Mcp-Session-Id|Invalid or expired'; then
  init_session
  out=$(call "$ability" "$params")
fi
echo "$out" | jq '.result.structuredContent // (.result.content[0].text | fromjson?) // .result'
# NOTE the parentheses close BEFORE the final `// .result`. Written as
# `(... | fromjson? // .result)`, jq binds the alternative inside the pipe, so on
# non-JSON text (e.g. validation errors: `Ability "…" has invalid input`) it tries
# to index the string with "result" and errors out instead of printing the envelope.
```

Notes: fill in `URL` and `AUTH`; drop `-k` on sites with real certificates. Output is the normalized `{success, data, error}` object, so calls read like `./mcp.sh formidable-forms/create-field '{"form_id":"123","type":"text","name":"My Field"}' | jq '.data.id'`. Keep `.mcp-session` out of version control.

**zsh users — never `echo "$json" | jq`.** zsh's builtin `echo` interprets backslash escapes, so JSON containing `\"` or `\n` sequences (any response carrying HTML content) gets corrupted and jq fails with `Invalid string: control characters ... must be escaped` — *after* the API call already succeeded, which reads like a phantom failure and invites a duplicate retry. Capture responses to a file and run `jq ... file.json`, or use `printf '%s\n' "$json" | jq`. (The bundled `scripts/frm-mcp` helper is unaffected — it runs under bash, whose `echo` doesn't interpret escapes.)

## Adapter tools

The MCP server exposes three generic tools; all Formidable operations go through them.

### 1. `mcp-adapter-discover-abilities`
Lists all registered WordPress abilities.
- **Input:** empty object
- **Output:** array of ability objects with name, label, description

### 2. `mcp-adapter-get-ability-info`
Get detailed info about one ability, including schemas.
- **Input:** `ability_name` (required), e.g. `"formidable-forms/create-form"`
- **Output:** ability info with `input_schema`, `output_schema`, metadata

### 3. `mcp-adapter-execute-ability`
Execute an ability.
- **Input:** `ability_name` (required) + `parameters` (object matching the ability's input_schema)
- **Output:**
  ```json
  {
    "success": boolean,
    "data": "<ability-return-value>",
    "error": "string (if success=false)"
  }
  ```

## Abilities catalog

All ability IDs are namespaced `formidable-forms/<action>`. Most `id`/`form_id` inputs accept either a numeric ID or an alphanumeric key (`form_key`, `item_key`, `field_key`).

### Forms
| Ability | Description | Notes |
|---|---|---|
| `list-forms` | List forms (id, form_key, name, description, status) — published and draft; trashed forms are excluded | readonly, idempotent |
| `get-form` | Get one form by id/form_key; return format array or html | readonly |
| `create-form` | Create a form with optional `fields[]` array; accepts `parent_form_id` for repeater child forms | not idempotent |
| `update-form` | Update name, description, status, options, or `parent_form_id` | not idempotent |
| `delete-form` | Delete a form — **cascades: the form's entries are deleted with it** (verified) | destructive |

### Entries
| Ability | Description | Notes |
|---|---|---|
| `list-entries` | List submissions; supports form_id, paging, order, search, start_date/end_date | readonly |
| `get-entry` | Get one entry by id/item_key | readonly |
| `create-entry` | Submit an entry; requires form_id + values keyed by field id/field_key | |
| `update-entry` | Update an entry's values (item_meta) | |
| `delete-entry` | Delete an entry | destructive |

### Fields
| Ability | Description | Notes |
|---|---|---|
| `list-fields` | List a form's fields (id, field_key, name, type, options); use to map values for create/update-entry | readonly |
| `delete-field` | Delete a field by id | destructive |
| `get-stats` | Field statistics across entries. Types: `total`, `count`, `average`, `median`, `star`, `maximum`, `minimum`, `unique`, `deviation`. `field_id` accepts id, key, or comma-separated list | readonly, idempotent; requires Formidable Pro |

### Form Actions
| Ability | Description | Notes |
|---|---|---|
| `list-form-actions` | List all post-submission actions for a form | readonly |
| `get-form-action` | Get single form action by id | readonly |
| `create-form-action` | Create a form action (email, webhook, etc.) | not idempotent |
| `update-form-action` | Update an existing form action | not idempotent |
| `delete-form-action` | Delete a form action | destructive |

### Styles
| Ability | Description | Notes |
|---|---|---|
| `list-styles` / `get-style` | Read styles | readonly |
| `create-style` / `update-style` | Manage styles | |
| `delete-style` | Delete a style | destructive |
| `assign-style-to-form` | Assign a style to a form | |

### Applications (Formidable Pro only)
| Ability | Description | Notes |
|---|---|---|
| `list-applications` | List all applications (id, name, form/view/page counts, dates) | readonly, idempotent |
| `get-application` | Get one application by id — same fields as the list | readonly, idempotent |
| `create-application` | Create an application | not idempotent |
| `add-item-to-application` | Add item to application | not idempotent |
| `remove-item-from-application` | Remove item from application | destructive |
| `list-application-items` | List all items in an application | readonly, idempotent |
| `delete-application` | Delete an application (requires application_id) | destructive |

### Views (requires Formidable Views plugin)
`list-views`, `get-view`, `create-view`, `update-view`, `delete-view`

### View Layouts (requires FrmAPIViewLayoutsController)
`list-view-layouts`, `get-view-layout`, `create-view-layout`, `update-view-layout`, `delete-view-layout`

### Implementation details
- Each ability has an `input_schema`, `output_schema`, `execute_callback`, and `permission_callback`
- Permission callbacks enforce per-action capability checks (e.g., `can_create_entry`)
- Ability executors call the REST controllers' methods directly — the REST routes' own arg validation and permission callbacks do NOT run for ability calls. The two layers hold separate schema and permission definitions, so when debugging, reproduce through the same layer the failure came from
- Registered via hooks: categories (`register_categories`), abilities (`register_abilities`), wired into `wp_abilities_api_init`

## Common ability parameters

### create-form
- `name` (required): form name
- `description`: form description
- `status`: `"published"` | `"draft"` (default: published). `update-form` also accepts `trash`, and normalizes the WP-style value `publish` to `published`
- `logged_in`: boolean (default: false)
- `is_template`: boolean (default: false)
- `parent_form_id`: integer (default: 0)
- `editable`: boolean (default: false)
- `fields`: array of field objects (optional)

### Field object

```json
{
  "type": "text",                    // Required. See field types below
  "name": "Field Label",             // Field display name
  "description": "Help text",        // Optional field description
  "required": true,                  // Whether field must be filled
  "field_order": 1,                  // Display order (auto if omitted)
  "field_key": "custom_key",         // Unique identifier (auto-generated if omitted)
  "placeholder": "Type here...",     // Placeholder text
  "default_value": "Default text",   // Pre-filled value
  "options": [                       // For radio/checkbox/dropdown only
    "Option 1",
    "Option 2",
    "Option 3"
  ]
}
```

Two verified behaviors of inline `fields[]`:

- **`options` takes the same shapes as `create-field`.** Plain strings (`["Paris", "Lyon"]`) or `{label, value}` objects (`[{"label": "Paris", "value": "1"}]`) both work, and separate label/values set `separate_value` on the field automatically. Fields sent inline with `create-form` go through the same creation pipeline as fields added later with `create-field`, so there is no reason to split a form build into two calls.
- **Keys are derived from names, and are unique site-wide.** A field named "Full Name" gets `field_key: "full-name"`, and a form named "Volunteer Signup 2026" gets `form_key: "volunteer-signup-2026"` — the same `sanitize_title` rule the builder uses when you rename a form. Pass an explicit `field_key`/`form_key` to override. Because uniqueness spans the whole site rather than one form, a name that collides with an existing key is silently suffixed (`full-name` → `full-name2`). **Never assume you got the key you asked for** — read the keys back (`list-fields` or the create response) before writing entry payloads or view shortcodes, or `[full-name]` in your view will silently pull from a different form's field.

### list-entries parameters
- `form_id`: filter by form
- `page`: pagination (default: 1)
- `page_size`: results per page
- `order_by`: sort field
- `search`: search query
- `start_date` / `end_date`: date range filtering
- `is_draft`: 0 = submitted only, 1 = drafts only; **drafts are included when omitted**

## Field types reference

**Basic text:** `text` (single line), `textarea` (multi-line), `email`, `url`, `phone`, `password` (masked)

**Selections:** `radio`, `checkbox`, `dropdown`, `toggle`

**Numeric:** `number`, `range` (slider), `scale` (rating scale), `star_rating` (1–5 stars)

**Date/time:** `date`, `time`

**Media:** `file` (upload), `signature`, `image`

**Special:** `html` (display), `divider`, `section`, `user_id` (current user), `captcha`, `hidden`

## Common workflows

Typical sequence: `list-forms` → find the target form → `list-fields` → get field IDs/keys → `create-entry` keyed by field ID → `list-entries`/`get-entry` to read back.

The HTTP examples below assume `SESSION` was captured from initialize (see Transport 2). The same `tools/call` bodies work verbatim over the stdio bridge.

### Create form with fields

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "USERNAME:APPLICATION_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/create-form",
        "parameters": {
          "name": "Form Name",
          "description": "Form description",
          "status": "published",
          "fields": [
            {"type": "text", "name": "Full Name", "required": true},
            {"type": "email", "name": "Email Address", "required": true},
            {"type": "textarea", "name": "Message", "required": false}
          ]
        }
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent.data'
```

Response:

```json
{
  "success": true,
  "data": {
    "id": "1408",
    "form_key": "xzj31",
    "name": "Form Name",
    "description": "<p>Form description</p>",
    "status": "published",
    "created_at": "2026-06-15 14:59:19"
  }
}
```

### List fields in a form

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "USERNAME:APPLICATION_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-fields",
        "parameters": {"form_id": "1408"}
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent.data[] | {id, name, type}'
```

### List all forms

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "USERNAME:APPLICATION_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-forms",
        "parameters": {}
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent.data'
```

### Create entry (submit form)

Field values are keyed by **numeric field ID** (or field_key) at the top level of `parameters`, alongside `form_id`. Get IDs from `list-fields` first.

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "USERNAME:APPLICATION_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/create-entry",
        "parameters": {
          "form_id": "1408",
          "12752": "John Doe",
          "12753": "john@example.com",
          "12754": "This is my message"
        }
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent'
```

## Creating grid views with layouts

Grid views display form entries in a multi-column layout with customizable content boxes. Three steps: create the view, set its `post_content` boxes, create the layout mapping.

### Step 1: Create grid view

```json
{
  "ability_name": "formidable-forms/create-view",
  "parameters": {
    "form_id": 1494,
    "name": "My Grid View",
    "type": "grid"
  }
}
```

Save the returned view ID (`.result.structuredContent.data.id`).

### Step 2: Update view with post_content

`post_content` is a JSON string defining what appears in each box:

```json
[
  {"box": 0, "content": ""},
  {"box": 1, "content": "Box 1 content"},
  {"box": 2, "content": "Box 2 content"}
]
```

```json
{
  "ability_name": "formidable-forms/update-view",
  "parameters": {
    "id": "VIEW_ID",
    "post_content": "[{\"box\":0,\"content\":\"\"},{\"box\":1,\"content\":\"Box 1\"},{\"box\":2,\"content\":\"Box 2\"}]"
  }
}
```

### Step 3: Create the view layout

The layout defines the grid structure (columns) and which boxes go where. `create-view-layout` upserts: grid views get a default 1-column layout at creation, and this call replaces it (same view_id + type) rather than adding a duplicate. Example 2-column layout:

```json
{
  "ability_name": "formidable-forms/create-view-layout",
  "parameters": {
    "view_id": "VIEW_ID",
    "type": "listing",
    "data": [
      {
        "id": 0,
        "layout": 2,
        "boxes": [
          {"id": 1},
          {"id": 2}
        ]
      }
    ]
  }
}
```

### Layout constants

The `layout` value controls column structure:

| Value | Layout |
|---|---|
| 1 | 1 column (100%) |
| 2 | 2 columns (50/50) |
| 3 | 3 columns (33 each) |
| 4 | 4 columns (25 each) |
| 5 | 1-3 split (33%–67%) |
| 6 | 3-1 split (67%–33%) |
| 7 | 1-2-1 split (33%–33%–33%) |
| 8 | 1-2 split (25%–75%) |
| 9 | 2-1 split (75%–25%) |

### Grid view requirements

For grid views to display entries:
1. The form must have **at least one entry**
2. `post_content` must be properly formatted JSON with box definitions
3. The layout must map boxes to the grid structure
4. Boxes are numbered starting from 1 (**box 0 is reserved for structure**)

Content types allowed in boxes:
- Literal text: `"content": "Plain text"`
- Field shortcode: `"content": "[12345]"` (field ID)
- HTML: `"content": "<strong>Bold</strong>"`
- Mixed: `"content": "Text and [12345] mixed"`

## Response structure

All ability responses follow this pattern:

```json
{
  "result": {
    "content": [{"type": "text", "text": "JSON string"}],
    "structuredContent": {
      "success": true,
      "data": { /* actual response data */ },
      "error": "error message if failed"
    },
    "isError": false
  }
}
```

- **Extract data from:** `.result.structuredContent.data`
- Over the stdio bridge, `structuredContent` may be absent; parse `result.content[0].text` as JSON instead
- On failure, `isError` is `true`; error details are in `result.content[0].text` or `structuredContent.error`

## Common errors and solutions

### "Missing Mcp-Session-Id header"
**Cause:** Forgot the session ID header on an HTTP request.
**Fix:** Initialize first, extract the session ID from the `mcp-session-id` response header, and include `-H "Mcp-Session-Id: $SESSION"` on every call after initialize.

### "Session not found: Invalid or expired session"
**Cause:** Session ID is invalid or expired (sessions expire after inactivity — this WILL happen during long working sessions).
**Fix:** Re-initialize to get a fresh session ID. Better: use the Step 3 helper script, which detects this and re-initializes + retries automatically.

### 401 / `rest_not_logged_in` despite correct credentials
**Cause:** The host strips the `Authorization` header before PHP sees it (common on Apache CGI/FastCGI and some shared hosts), or the application password was created for a non-admin user, or application passwords are unavailable because the site is plain HTTP on a non-local domain.
**Fix:** Add `SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1` to `.htaccess` (or `CGIPassAuth On`); use an administrator's application password; serve the site over HTTPS.

### curl: SSL certificate problem (self-signed)
**Cause:** Local dev environments (Local by Flywheel, Valet, DDEV) use self-signed certificates.
**Fix:** Add `-k` to curl calls on local sites only — don't blanket-disable verification against production sites.

### 404 on `/wp-json/mcp/formidable-mcp`
**Cause:** The Formidable API add-on (which ships the MCP adapter) isn't active, or permalinks are set to "Plain".
**Fix:** Activate the add-on; set permalinks to any non-Plain structure.

### "Ability 'formidable-forms/xyz' has invalid input"
**Cause:** Required parameter missing or wrong format.
**Fix:** Check the ability schema with `mcp-adapter-get-ability-info` and verify all required fields are present.

### "name is a required property of input"
**Cause:** Missing required `name` when creating a form.
**Fix:** Always include `name` at the top level of the parameters object.

### Wrong field ID when creating entry
**Cause:** Using a field name instead of a field ID.
**Fix:** Call `list-fields` first to get numeric field IDs; use those in `create-entry`.

## Best practices

1. **Always initialize before first use** (HTTP transport) — the session ID comes from the response header
2. **Extract the session ID from the header, not the JSON body**
3. **Use field IDs for entries** — when submitting entries, key values by numeric field ID (not label)
4. **Verify schema before executing** — use `mcp-adapter-get-ability-info` when unsure about parameters
5. **Read `.result.structuredContent.data`** — the actual payload is nested there
6. **Set `field_key` explicitly for easier reference** — auto-generated keys can change; explicit keys are stable
7. **Use `form_key` for form references** — more human-readable than numeric IDs (e.g., `"xzj31"`)
8. **Debug MCP failures, don't route around them** — no REST fallback, no SQL writes, no manual package installs

---

## Appendix: REST API reference (normally blocked — MCP is mandatory)

> **Do not use this API in this setup.** REST endpoints under `/wp-json/frm/*` are deny-listed and all Formidable operations must go through MCP (see Access policy). This appendix is retained only as background reference — e.g., for understanding field data formatting conventions that also apply to entry values, or for environments where MCP is unavailable and the user has explicitly authorized REST.

**Base URL:** `https://your-site.local/wp-json/frm/v3/` (current) or `https://your-site.local/wp-json/frm/v2/` (frozen legacy)

**Requirements:** Form Webhooks API add-on (Business license or above)

### Namespace versions (since the Abilities/MCP release)

- **`frm/v3` — current.** Full surface: everything below plus views CRUD (`GET/POST /views`, `POST/DELETE /views/{id}`), `POST/PUT/PATCH /forms/{id}` (update form), `styles`, `form-actions`, `form-styles`, `applications`, and `view-layouts`. The MCP abilities are backed by these v3 controllers. Behavior notes: entry listings **include drafts** unless `is_draft` is passed; forms/fields GETs require the `frm_view_forms` capability; `GET /views/{id}` returns view metadata (no `renderedHtml`).
- **`frm/v2` — frozen legacy, for pre-existing integrations only.** Exactly the pre-v3 route surface and behavior: entry listings always exclude drafts, forms/fields GETs are readable without capability checks, `GET /views/{id}` returns the core post envelope with the `renderedHtml` field, and none of the new endpoints exist here. Never add routes or change behavior under this namespace — `tests/test_FrmAPILegacyV2.php` in formidable-api pins this contract and also passes on pre-v3 releases.

### Authentication
- **Method:** Basic Auth
- **Format:** `API-KEY:x` (where `x` is a placeholder password)
- **Setup:** Formidable → Global Settings → API
- **Default:** requests without an API key are treated as logged-out users

### Core endpoints

Forms:
- `GET /forms` — list all forms
- `POST /forms` — create new form
- `GET /forms/{id}` — retrieve specific form
- `DELETE /forms/{id}` — delete form
- `GET /forms/{id}?return=html` — get rendered form HTML

Fields:
- `GET /forms/{id}/fields` — list form fields
- `POST /forms/{id}/fields` — add field to form
- `PATCH /forms/{id}/fields` — update form fields

Entries:
- `GET /entries` — all entries across forms
- `GET /entries/{id}` — specific entry
- `GET /forms/{id}/entries` — entries in a specific form
- `POST /entries` — create new entry
- `POST/PUT/PATCH /entries/{id}` — update entry
- `DELETE /entries/{id}` — remove entry

Views:
- `GET /views/{id}` — v2: core post envelope + `renderedHtml`; v3: view metadata (title, form_id, view_type, content, limit)
- v3 only: `GET/POST /views`, `POST /views/{id}` (update), `DELETE /views/{id}`

Statistics:
- Pattern: `/stats/{method}/{field_id}` — methods: `total`, `count`, `average`, `median`, `star`, `maximum`, `minimum`, `unique`, `deviation`

### Query parameters for entries

| Parameter | Purpose |
|-----------|---------|
| `order_by` | Sort field (default: id) |
| `order` | ASC or DESC |
| `page` | Pagination (default: 1) |
| `page_size` | Results per page (default: 25) |
| `search` | Search all fields |
| `start_date` / `end_date` | Date range filtering |

### Field data formatting

These sub-key conventions matter for compound field values:

- **Address fields:** `fieldkey|line1`, `fieldkey|city`, `fieldkey|state`, `fieldkey|zip`, `fieldkey|country`
- **Name fields:** `fieldkey|first`, `fieldkey|last`
- **Checkbox fields:** comma-separated — `"field_id": "Option 1, Option 2"`
- **File upload fields:** pass a file URL to the receiving field
- **Credit card fields:** `fieldkey|cc`, `fieldkey|month`, `fieldkey|year`

### Features
- **Repeater support:** create/update repeater rows via parent/child form relationships
- **Cross-site:** transfer entries between WordPress sites
- **Embed:** display forms on non-WordPress sites via script or `[frm-api]` shortcode
- **Integrations:** Zapier, WordPress REST API, external services

### Common REST issues
- DNS resolution errors
- 403 Basic Auth failures (verify the server supports Basic Authentication)
- 409 validation errors (missing required fields)
- Use the Logs add-on to diagnose failures
