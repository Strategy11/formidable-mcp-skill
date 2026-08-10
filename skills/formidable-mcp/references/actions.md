# Form Actions (Email, Confirmations, Webhooks)

Read this when: creating, listing, or deleting form actions (email notifications, confirmation messages, post creation, webhooks) via the Formidable MCP adapter.

## Overview

Form actions define what happens when a form is submitted. Common actions include sending emails, showing confirmation messages, creating posts, and triggering webhooks. This reference covers creating, updating, listing, and deleting form actions via the Formidable MCP.

## Database Structure

Form actions are stored as **WordPress posts** with specific requirements:
- **Table:** `wp_posts`
- **post_type:** `'frm_form_actions'` (MUST be set correctly)
- **post_status:** `'publish'`
- **post_parent:** Form ID (links action to form)
- **post_excerpt:** Action type ("email", "on_submit", "confirmation", "wppost", etc.)
- **post_content:** JSON serialized object with action-specific settings

### Example: Email Action Record

```sql
ID: 10435
post_type: 'frm_form_actions'
post_parent: 1429          ← Linked to form 1429
post_excerpt: 'email'      ← Action type
post_content: {
  "email_to": "[default-email]",
  "email_message": "Test email content",
  "event": ["create"],
  "conditions": {...}
}
```

## Invoking the abilities

The examples in this file use the WP-CLI stdio bridge, but the same `arguments` objects (`ability_name` + `parameters`) work verbatim over the HTTP curl transport — pick whichever transport fits your access level and see `mcp-protocol.md` for session setup and a reusable curl helper script. Stdio example:

```bash
cat > /tmp/action.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-form-action","parameters":{"form_id":"1429","type":"email","post_content":{"email_to":"[default-email]","email_message":"Test","event":["create"]}}}}}
JSON

cat /tmp/action.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data'
```

## Updating Actions

`update-form-action` takes `id` plus a partial `post_content` and merges it with the action's existing settings — fields you omit are preserved (e.g., updating `email_message` keeps the existing recipients).

**Best practice:** after creating an action, verify it with `get-form-action` using the ID returned from create.

## Conditional logic (works on every action type)

Add a `conditions` object inside `post_content`. Verified end-to-end with a `wppost` action that ran for a matching entry and was skipped for a non-matching one, on MCP-created entries:

```json
"conditions": {
  "send_stop": "send",
  "any_all": "any",
  "0": {"hide_field": "13426", "hide_field_cond": "==", "hide_opt": "Pro"}
}
```

- Rules are numeric keys (`"0"`, `"1"`, …), each `{hide_field: <field id>, hide_field_cond: <operator>, hide_opt: <compare value>}`.
- `send_stop`: `"send"` = run the action only when conditions match; `"stop"` = skip it when they match.
- `any_all`: `"any"` or `"all"` — how multiple rules combine.
- Evaluation is `FrmProFormActionsController::action_conditions_met()` (Pro must be active; without Pro, core returns "not met" for any action with conditions).
- Operators are the `value_meets_condition` set: `==`, `!=`, `>`, `>=`, `<`, `<=`, `LIKE` (contains, case-insensitive), `not LIKE`, `LIKE%` (starts with), `%LIKE` (ends with). `hide_opt` values pass through `prepare_logic_value`, so entry-based shortcodes work.

## Creating Actions

### Email Action

```bash
cat > /tmp/create_email_action.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-form-action","parameters":{"form_id":"1429","type":"email","post_content":{"email_to":"[default-email]","email_message":"Your message here","event":["create"]}}}}}
JSON

cat /tmp/create_email_action.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data | {id, type}'
```

Canonical create payload:

```json
{
  "form_id": "1429",
  "type": "email",
  "post_content": {
    "email_to": "[default-email]",
    "email_message": "Your message here",
    "event": ["create"]
  }
}
```

**Email Action Properties:**
- `email_to` — Recipient email (use `[default-email]`, `[user_email]`, or specific email)
- `email_message` — Email body (supports shortcodes: `[field_id]`/`[field_key]`, `[default-message]` — never field names). For **readable, editable** HTML bodies: write clean multi-line indented HTML (HTML emails are `wpautop`'d at send, so blank lines become paragraphs — no manual `<br>`/`<p>` needed), use **inline `style=` attributes only** (email clients strip `<style>`/external CSS), and add `wpautop=0` to any rich-text/paragraph field placed inside a block tag to avoid invalid nested `<p>`. Full treatment: `shortcodes.md` §4 "Writing readable HTML email bodies".
- `email_subject` — Subject line (optional, defaults to form title)
- `from` — From address (optional, defaults to `[sitename] <[default-from-email]>`)
- `event` — When to send (array: `["create"]`, `["create", "update"]`, etc.)
- `plain_text` — Send as plain text instead of HTML (optional)
- `inc_user_info` — Include WordPress user info in email (optional)

**Available email placeholders:**
- `[default-email]` — Site admin email
- `[default-from-email]` — Site from email
- `[sitename]` — Site name
- `[user_email]` — Submitting user's email
- Field values via `[field_id]` or `[field_key]`

For the complete catalog — `[default-message]` parameters, conditionals (`[if x]`), formatting options, recipient formats, confirmation/redirect shortcodes — see `shortcodes.md`.

### Confirmation Action (Success Message)

```bash
cat > /tmp/create_confirmation_action.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-form-action","parameters":{"form_id":"1429","type":"confirmation","post_content":{"success_action":"message","success_msg":"Your message here","event":["create"]}}}}}
JSON

cat /tmp/create_confirmation_action.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data | {id, type}'
```

Canonical create payload:

```json
{
  "form_id": "1429",
  "type": "confirmation",
  "post_content": {
    "success_action": "message",
    "success_msg": "Your message here",
    "event": ["create"]
  }
}
```

**Confirmation Action Properties:**
- `success_action` — Action type: `"message"` (display message), `"redirect"` (redirect to URL), or `"page"` (show page)
- `success_msg` — Message to display (when `success_action` is "message"). The confirmation message lives at `post_content.success_msg`, NOT `confirmation_message`
- `success_url` — URL to redirect to (when `success_action` is "redirect")
- `success_page_id` — WordPress page ID to display (when `success_action` is "page")
- `event` — When to trigger (array: `["create"]`, `["create", "update"]`, etc.)
- `redirect_delay_time` — Delay before redirect in seconds (optional, default 8)

### Create Post Action

Verified working payload — note that post-field settings are **numeric field IDs**, not shortcode templates:

```json
{"form_id": "1606", "type": "wppost", "post_content": {
  "post_type": "post", "post_status": "publish",
  "post_title": "13425", "post_content": "13426",
  "event": ["create"]}}
```

**Create Post Action Properties:**
- `post_type` — WordPress post type to create (e.g., "post", "page", custom type)
- `post_title` / `post_content` / `post_excerpt` / `post_name` / `post_date` / `post_password` — **numeric field ID whose entry value fills that post field.** `FrmProPost::populate_post_fields()` skips any non-numeric setting, so a shortcode template like `"Post for [field_key]"` is silently ignored — and if title and content both end up empty, `wp_insert_post` rejects the post with **no PHP warning and no log entry**; the action just appears to do nothing (verified). For composed content, map a field here and build the text in the form, or use the `display_id` setting to render a View as the post body.
- `post_status` — only `"publish"` and `"pending"` are honored from the action; anything else (including `"draft"`) falls back to WP's default. A field ID also works via the post-field mapping.
- `event` — When to trigger (array: `["create"]`, `["update"]`, etc.)

Runtime behaviors (verified via MCP entries):

- **`create-entry` triggers the action** — the created post's ID is written back to the entry's `post_id`.
- **A field mapped to a post field stops storing its value as entry meta** — the value lives on the post afterward, so `get-entry` returns an empty string for that field. Expected, not data loss.

### Gated Content Action

Restricts private/password-protected content behind a form submission: when the action fires, a per-entry access token is generated and `[frm_gated_content]` shortcodes (in confirmation/email actions on the same form) render access links. KB: `/knowledgebase/gated-content/`. Action type string (post_excerpt): **`gated_content`**. Max 99 per form. Fires at priority 8 — before On Submit (9) and Send Email (10) — so the token is already stored when those actions render the shortcodes.

Canonical create payload (verified end-to-end via MCP):

```json
{
  "form_id": "1592",
  "type": "gated_content",
  "post_content": {
    "items": [ {"type": "page", "id": "10915"} ],
    "expired_hours": 2,
    "event": ["create"]
  }
}
```

**post_content properties:**

| Key | Type | Notes |
|---|---|---|
| `items` | array | The gatable items; **one token unlocks all items in the action**. Each item is `{"type": ..., "id": ...}` (+ type-specific keys below). Items with empty `id` are dropped on save |
| `expired_hours` | int or null | Hours until tokens expire, counted **from token creation** (not first open). Whole numbers ≥ 1; null/absent = never expires. Setting the UI field is Pro, but the key lives in Lite's defaults |
| `event` | array | `["create"]` (Lite), plus `"payment-success"` (payment forms), `"update"` (Pro), user-registration event (Registration add-on) |
| `access_page_id` | int | **Pro.** Page to redirect token-less visitors to, instead of the default 404 (verified: redirect happens with HTTP 200 at the target) |
| `keep_token_on_update` | 0/1 | **Pro**, only relevant with the `update` event. Default (0): updating the entry **deletes all of that entry's old tokens** for the action and issues a fresh one. 1: old tokens stay valid alongside the new one |

**Item types** (`items[].type`):

| Type | Plugin | Item keys |
|---|---|---|
| `page` / `post` | Lite | `id` = post ID. Only **private or password-protected** pages/posts are valid gated targets (published ones are publicly accessible; the admin UI filters the dropdown accordingly) |
| `frm_file` | Pro | `id` = attachment ID, plus `form_id` = form whose file-upload field produced it. The candidate list is files uploaded through Formidable file fields, not the whole media library |
| `frm_pdf` | PDFs add-on | `id` = a literal `[frm-pdf ...]` shortcode string (parsed for `view`/`entry` atts). Without a pinned entry, each token's link generates the PDF for its own entry |
| `frm_display` | Views | `id` = View ID (View must be private/password-protected), plus `entry_id`: `0` = listing view, `-1` = the token's own entry (resolved at link-build time), `N` = pinned entry for all users |

`update-form-action` with a partial `post_content` merges as usual — e.g. sending only `{"expired_hours": 48}` preserves `items` (verified).

**Token lifecycle (verified end-to-end):**

- Tokens live in the dedicated **`wp_frm_gated_tokens`** table: `token_hash` (SHA-256), `action_id`, `entry_id`, `user_id` (NULL for guests), `ip_address`, `created_at`, `expired_at` (NULL = never). **The raw 32-char token is never stored in the DB** — only in the emailed/rendered URL. So read-only SQL can verify a token *exists* (count, entry_id, TTL) but can never recover the link; don't try.
- Access URL: `{content-url}?access_code={raw_token}`. On a valid visit Formidable sets an **HttpOnly cookie `frm_gc_{type}_{id}`** (SameSite=Lax, expiry = token expiry or 1 year) and **redirects to strip `access_code` from the URL**; subsequent visits use the cookie. Links are reusable until expiry/revocation, but only in the browser that opened them (cookie-bound) unless the original link is used again.
- Without a valid token: private content → 404; password-protected → the normal WP password form; with `access_page_id` set → redirect to that page instead.
- **MCP `create-entry` and `update-entry` DO trigger the action** (verified: token rows appear with the correct TTL). Over the wp-cli stdio bridge the token's `user_id` is the `--user` admin, and the raw token lands in a transient scoped to that user — so an MCP-created entry's access link is not retrievable afterward. To capture a real access link end-to-end, submit through the frontend (Playwright) and read it from the confirmation message.
- Deleting the action deletes all its token rows (verified); deleting/updating items also clears the action-item membership transients (`frm_gc_ac_*`).

Verify via read-only SQL (never the raw token — it isn't there anyway):

```sql
SELECT id, entry_id, user_id, FROM_UNIXTIME(created_at), (expired_at - created_at) AS ttl
FROM wp_frm_gated_tokens WHERE action_id = 10916;
```

For the `[frm_gated_content]` shortcode (rendering the links in confirmation/email content, `show=` values, the ~5-minute rendering window) see `shortcodes.md` §5. Developer hooks: `frm_gated_content_item_types`, `frm_gated_content_sanitize_item`, `frm_gated_content_token_data`, `frm_obtain_gated_token`, `frm_gated_content_shortcode_custom_output`, `frm_gated_content_shortcodes`.

## Listing Form Actions

By default the list includes both published (active) and draft (disabled) actions — each item carries its `post_status`. Pass `post_status` (`publish` or `draft`) to filter to one.

List all actions for a specific form:

```bash
cat > /tmp/list_actions.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/list-form-actions","parameters":{"form_id":"1429"}}}}
JSON

cat /tmp/list_actions.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data'
```

To inspect a specific action, use `get-form-action` with the action ID (e.g., the ID returned from create).

Get a specific action by ID:

```bash
cat > /tmp/get_action.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/get-form-action","parameters":{"id":"10435"}}}}
JSON

cat /tmp/get_action.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data'
```

## Deleting Form Actions

To change an action, use `update-form-action` with `id` and a partial `post_content` — it merges with the action's existing settings. Use `delete-form-action` only to remove an action entirely.

```bash
cat > /tmp/delete_action.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/delete-form-action","parameters":{"id":"10435"}}}}
JSON

cat /tmp/delete_action.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent'
```

## Action Types

Types documented with working MCP payloads in this file: **email**, **confirmation** (success message/redirect/page — modern forms store this as the `on_submit` action; both type strings appear on real sites), **wppost** (create post), **gated_content** (access-token-gated content).

Other types that exist as `post_excerpt` values (settings-level keys for several are in `templates.md` — payment, quiz, quiz_outcome):
- **on_submit** — modern confirmation/redirect action (`on_submit_migrated: "1"` form option)
- **payment** — Stripe/Square/Authorize.net (gateway, amount, recurring settings)
- **register** — WordPress user registration (Registration add-on)
- **quiz** / **quiz_outcome** — quiz scoring and outcomes
- **twilio** — SMS (Twilio add-on)
- **paypal** — PayPal (separate from the `payment` gateways)
- **api** — webhooks (Form Webhooks API add-on)
- **zapier** — Zapier workflows

This list is assembled from multiple sources, not a verified registry — when working with an unfamiliar type, read an existing action of that type first (`list-form-actions` on a form that has one) rather than guessing its `post_content` keys.

### Registered action types (verified on a fully-loaded install)

`FrmFormActionsController::get_form_actions()` is the authoritative registry. On a site with Pro + Registration + Quizzes + API add-ons active it returns these as **active** (usable): `on_submit`, `email`, `gated_content`, `wppost`, `register`, `quiz`, `quiz_outcome`, `api`, plus the payment types `stripe`, `square`, `paypal`, `payment`. Types registered but **inactive** (upsell placeholders until their add-on is installed) include `mailchimp`, `activecampaign`, `constantcontact`, `getresponse`, `mailpoet`, `convertkit`, `aweber`, `twilio`, `salesforce`, `hubspot`, `zapier`, `googlespreadsheet`, `n8n` — these carry `active => false` and `limit => 0`, so don't try to create them.

Read the live registry rather than trusting this list:

```bash
wp --path="/path/to/site" eval '
foreach ( FrmFormActionsController::get_form_actions() as $slug => $a ) {
  echo $slug, " active=", ! empty( $a->action_options["active"] ) ? 1 : 0,
       " limit=", $a->action_options["limit"] ?? "", "\n";
}'
```

Per-form limits matter: `wppost`, `register`, `quiz` and each payment type are `limit => 1` (one per form); `on_submit`, `email`, `gated_content`, `quiz_outcome` and `api` allow 99.

### Verified working payloads for add-on actions

**`register`** (Registration add-on) — map field IDs to user properties; `reg_role` defaults to `subscriber`:

```json
{"form_id": "1597", "type": "register", "post_content": {
  "reg_username": "13395", "reg_email": "13396", "reg_password": "13397",
  "reg_first_name": "13398", "reg_role": "subscriber", "event": ["create"]}}
```

Runtime behaviors (verified via MCP entries):

- **`create-entry` triggers registration** — the WP user is created with the mapped login/email/first name and the entry's `user_id` is set to the new user.
- **Duplicate usernames are NOT rejected on the API path.** Frontend submissions get the add-on's validation ("username taken"), but API entries bypass form validation, and the add-on auto-uniquifies the login instead (submitting `mcp_test_user1` twice produced a second user `mcp_test_user11`). Don't rely on the register action to dedupe API-driven signups — check `wp_users` first if uniqueness matters.
- Registration creates real WP users — flag them for cleanup when testing.

**`api`** (webhook, Form Webhooks API add-on) — `data_fields` is a list of `{key, value}` pairs where `value` accepts shortcodes; delivered as a real JSON POST:

```json
{"form_id": "1593", "type": "api", "post_content": {
  "url": "https://example.com/hook", "method": "POST", "format": "json",
  "data_fields": [{"key": "sender_email", "value": "[13389]"}, {"key": "entry_id", "value": "[id]"}],
  "event": ["create"]}}
```

**`quiz`** (Quizzes add-on) — `quiz` is keyed by an arbitrary row key; what matters is each row's `id` (the question field) and `enable` (list of scored field IDs). `show_result: "correct_answers"` reveals answers after submit:

```json
{"form_id": "1598", "type": "quiz", "post_content": {
  "quiz_type": "scored", "show_result": "correct_answers", "enable": ["13399", "13400"],
  "quiz": {"13399": {"id": "13399", "score": "1", "compare_method": "equal", "corrects": ["Paris"], "max_score": "1"}},
  "event": ["create"]}}
```

Verified quiz-action behaviors (5-question scored quiz):

- **MCP `create-entry` triggers quiz scoring** — an API-submitted entry gets its score computed and stored exactly like a frontend submission (a deliberately 2-of-5-correct entry came back with `2/5`). No browser needed to generate scored entries.
- **Where the score lives:** once the form has a `quiz_score` field (see the `create-form-action`/`update-form-action` gotcha in `gotchas.md`), each entry stores the display value under that field's key (`"5/5"`) plus a numeric companion meta `"<field_key>-value"` (`"5"`).
- **`get-stats` works on the `quiz_score` field ID** — `average`/`maximum` etc. compute from the numeric value (verified: avg 2.67 / max 5 across scores 5, 3, 0, 2).
- With `show_result: "correct_answers"`, the confirmation shows a per-question results table, revealing "Correct answer: X" only on missed questions.

**`quiz_outcome`** — one action per outcome, selected by the action's own `conditions`; needs a `quiz_score` field on the form (see the `create-form-action` caveat in `gotchas.md`):

How the winner is picked (`FrmQuizzesOutcomeHelper::get_outcome()`, verified with a 4-outcome quiz): each outcome scores **the number of its conditions the entry matches**, and the highest score wins. `any_all` is irrelevant to that scoring — it is a plain match count, so the natural design for an N-result personality quiz is one condition per question on each outcome, letting the majority answer decide. **Ties break alphabetically by outcome title**, not by creation order or menu order, because `FrmFormAction::action_args()` queries actions with `orderby => 'title', order => 'ASC'` (confirmed: a 2-2 tie went to "Hufflepuff" over the earlier-created "Slytherin", and a 4-way tie went to "Gryffindor"). An outcome with **no** conditions becomes the fallback used when nothing else scores, and outcomes with empty content are skipped so users never land on a blank result.

Set the outcome's display name with the **top-level `post_title`** parameter. A `post_title` inside `post_content` is ignored, and the action is left named "Quiz Outcome".

```json
{"form_id": "1598", "type": "quiz_outcome", "post_content": {
  "quiz_type": "outcome", "post_title": "Geography Buff", "description": "You know your capitals!",
  "conditions": {"send_stop": "send", "any_all": "any",
                 "0": {"hide_field": "13399", "hide_field_cond": "==", "hide_opt": "Paris"}},
  "event": ["create"]}}
```

**Form Action Automation** (add-on slug `formidable-autoresponder`) — schedules an action to run on a delay instead of immediately. Not a separate action type: it's an `autoresponder` object nested inside an existing action's `post_content`, and `create-form-action` accepts it directly (verified):

```json
{"form_id": "1606", "type": "email", "post_content": {
  "email_to": "[admin_email]", "email_subject": "Follow-up", "email_message": "...",
  "event": ["create"],
  "autoresponder": {
    "is_active": true, "do_default_trigger": "no",
    "send_date": "create", "send_before_after": "after",
    "send_unit": "minutes", "send_interval": 10}}}
```

- Key settings (full list in `FrmAutoresponder::get_default_autoresponder()`): `do_default_trigger` `"yes"`/`"no"` — whether the action ALSO fires immediately; `send_date` — reference date: `"create"`, `"update"`, or a date-field ID; `send_before_after` + `send_unit` (`minutes`/`hours`/`days`/`months`/`years`) + `send_interval` (int); optional repeats via `send_after`/`send_after_limit`/`send_after_count`/`send_after_unit`/`send_after_interval`.
- **How to verify scheduling without waiting:** entry creation (MCP `create-entry` included) queues a single WP-cron event, hook `formidable_send_autoresponder`, args `[entry_id, action_id]`, timestamp = reference date ± interval (verified: +10 minutes landed at +601s). Read the `cron` option (read-only SQL) or `wp cron event list`. `wp cron event run formidable_send_autoresponder` fires it early; the event is consumed from the queue after running.
- Deleting an entry unschedules its pending events (`frm_before_destroy_entry` hook).

Payment actions (`stripe`, `square`, `paypal`, `payment`) need live gateway credentials to exercise; don't submit test payments against a connected merchant account.

## Workflow: Create Form with Multiple Actions

1. Create email action with form_id
2. Create confirmation action with form_id
3. Verify actions attached to form with list-form-actions (or get-form-action by the returned IDs)

```bash
FORM_ID=1429

# Create email action
EMAIL_ID=$(cat > /tmp/email.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-form-action","parameters":{"form_id":"$FORM_ID","type":"email","post_content":{"email_to":"[default-email]","email_message":"Test email","event":["create"]}}}}}
JSON
cat /tmp/email.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq -r '.result.structuredContent.data.id')

# Create confirmation action
CONFIRM_ID=$(cat > /tmp/confirm.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-form-action","parameters":{"form_id":"$FORM_ID","type":"confirmation","post_content":{"success_action":"message","success_msg":"Thanks for submitting!","event":["create"]}}}}}
JSON
cat /tmp/confirm.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq -r '.result.structuredContent.data.id')

echo "Created email action: $EMAIL_ID"
echo "Created confirmation action: $CONFIRM_ID"
```

## Event Triggers

The `event` field determines when an action fires:
- `["create"]` — When form is first submitted
- `["update"]` — When entry is updated
- `["create", "update"]` — On both
