# Entries, Views & Stats

Read this when: querying or managing form submissions (entries), creating or fixing views that display entries, or computing field statistics via the Formidable MCP adapter.

## MCP Session Setup

All examples below use the Formidable MCP HTTP endpoint. Initialize a session once, then reuse the session ID. Replace `https://your-site.local` with your site URL and `admin:APP_PASSWORD` with your WordPress username and application password.

```bash
SESSION=$(curl -s -i -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -u "admin:APP_PASSWORD" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}},"id":1}' \
  -k 2>&1 | grep -i "mcp-session-id" | cut -d' ' -f2 | tr -d '\r')
```

All abilities are invoked through the `mcp-adapter-execute-ability` tool with an `ability_name` and `parameters`.

## Querying Entries

### List All Entries for a Form

Ability: `formidable-forms/list-entries`

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-entries",
        "parameters": {
          "form_id": "1429"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data[] | {id, form_id, created_at, user_id}'
```

### Get a Specific Entry

Ability: `formidable-forms/get-entry`

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/get-entry",
        "parameters": {
          "id": "5678"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data'
```

The response's `meta` object is keyed by **field_key**, not field ID (`"meta": {"9qiak": "Paris", ...}`) — even though `create-entry`/`update-entry` accept IDs. Map keys via `list-fields` before asserting on values. Some field types add derived companion metas: a `quiz_score` field stores its display value under its own key (`"fnzkj": "3/5"`) plus a numeric copy under `"<field_key>-value"` (`"fnzkj-value": "3"`) — use the `-value` meta (or `get-stats` on the field ID) for numeric comparisons.

### List with Filters (Pagination and Sorting)

`list-entries` accepts `per_page`, `page`, `sort_by`, `sort`, and `is_draft` (0 = submitted only, 1 = drafts only; drafts are included when omitted):

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-entries",
        "parameters": {
          "form_id": "1429",
          "per_page": 10,
          "page": 1,
          "sort_by": "id",
          "sort": "desc"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data'
```

## Entry Management

### Create an Entry (Submit Form Programmatically)

Ability: `formidable-forms/create-entry`. Field values are passed with **numeric field IDs or field keys** as parameter keys — either top-level (as below) or inside an `item_meta` object; when a field appears under both its id and its key, the id-keyed value wins. Get ids/keys from the `list-fields` ability.

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/create-entry",
        "parameters": {
          "form_id": "1429",
          "12345": "John Doe",
          "12346": "john@example.com"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data'
```

### Update an Entry

Ability: `formidable-forms/update-entry`. Pass the entry `id` plus field-ID-keyed values to change.

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/update-entry",
        "parameters": {
          "id": "5678",
          "12345": "Jane Doe"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data'
```

### Delete an Entry

Ability: `formidable-forms/delete-entry`

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/delete-entry",
        "parameters": {
          "id": "5678"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent'
```

## Creating Views

Views display form entries in different formats (table, list, grid). They are stored as WordPress posts of type `frm_display`.

Ability: `formidable-forms/create-view`

Parameters:

| Param | Notes |
|---|---|
| `form_id` | **Required.** The form whose entries the view displays |
| `name` | View title |
| `type` | `all`, `grid`, `table`, `map`, `timeline`, or `calendar` |
| `content` | String — raw HTML for classic views, JSON box array for layout views (see formats below) |
| `limit` | Integer — max entries to display |
| `before_content` / `after_content` | Classic views: HTML rendered once before/after the repeating content (table open/close, headers) |
| `table_options` | Table views: array of numeric field IDs to use as columns — box content and header names are generated automatically from the fields |
| `timeline_options` | Timeline views: array of `{"name": ..., "value": ...}` pairs. Useful names: `title`, `description`, `thumbnail`, `date` (field IDs as string values), `date_format` (`year`/`date`/custom), `card_content_order`, `show_details_popup`, `add_divider` (see `FrmViewsTimelineController::$default_settings`). Content is generated at render time; the view's `content` stays empty |
| `calendar_options` | Calendar views: array of `{"name": ..., "value": field_id}` pairs — names `start_date`, `end_date`, `title` |
| `map_address_fields` | Map views: array of address field IDs |
| `options` | Object merged into `frm_options`: `where`/`where_is`/`where_val` filter arrays, `empty_msg`, `page_size`, `order_by` (array), `order` (array), `listing_page_custom_css` / `detail_page_custom_css` (the View Custom CSS setting — see "Styling views" below), etc. **Note:** `order_by` and `order` must be **arrays**, not strings — the API validates and normalizes them automatically. **`order_by` values must be field IDs, not field keys** (a key produces an invalid `ORDER BY it.<key>` column and the view silently shows "No Entries Found" — see the gotcha below). |
| `detail_content` | Detail Page content, rendered when an entry is opened via `[detaillink]`. Raw HTML for classic views; JSON box array for layout views — see "Detail pages" below |
| `status` | `publish`, `private`, or `draft` (default `private`, matching the product). Draft only affects the standalone permalink (404 for visitors); draft and private views still render wherever they are embedded |

View responses (create/update/get/list) include `slug` and `url` — `url` is the direct front-end permalink (`https://site/frm_display/<slug>/`), ready to open in a browser to preview the view. Calendar view responses also include `date_field_id` (read from the view's options).

**Grid views auto-create a default 1-column listing layout.** To use more boxes/columns, call `create-view-layout` afterwards — it upserts (replaces the auto-created layout of the same type rather than adding a duplicate). `list-view-layouts` takes an optional `type` filter (`listing` or `detail` only — other values are rejected); a filter with no matching layout returns an empty array.

A complete view can be created in **one MCP call** — content, limit, and name included; `create-view` sets all required postmeta automatically (see next section):

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/create-view",
        "parameters": {
          "form_id": "1429",
          "name": "All Submissions",
          "type": "table",
          "content": "<table><tr><th>Name</th><th>Email</th></tr><tr><td>[v8lk9]</td><td>[em41l]</td></tr></table>",
          "limit": 25,
          "status": "publish"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data | {id, name, form_id, content, limit}'
```

The create/update responses (and `get-view`) include `content` and `limit` — verify with `get-view`.

### View Postmeta: Set Automatically by `create-view`

`create-view` sets ALL required postmeta automatically. The requirements are worth understanding, because BOTH form-link metas matter:

1. **`frm_form_id`** — Configures the view's datasource (which form to pull entries from)
2. **`frm_form`** — Links the view to the form in the admin views list

Why both are required:

- Without `frm_form_id`: the view editor shows "No form is selected" and the datasource shows "Select datasource"
- Without `frm_form`: the view doesn't appear at `/wp-admin/edit.php?post_type=frm_display&form=X`. Formidable queries `get_posts()` with `meta_key: "frm_form"` and `meta_value: FORM_ID` to retrieve views for a form; without this metadata the post is invisible to the form editor — even if the view's JSON content contains a `form_id` and the view is linked to an application via `term_relationships`.

Full postmeta set by `create-view`:

- `frm_form_id` AND `frm_form` — both set to the form ID
- `frm_param` — `"entry"`
- `frm_type` — `"id"`
- `frm_active_preview_filter` — `"limited"`
- `frm_dyncontent` — empty string
- `frm_grid_view` — `1` for `type: grid`, else `0`

Views missing `frm_form` (e.g., created by other means) are backfilled automatically when touched with `update-view`.

### Updating Views

Ability: `formidable-forms/update-view`

Parameters:

| Param | Notes |
|---|---|
| `id` | **Required.** View (post) ID |
| `title` | New view title |
| `post_status` | `publish`, `private`, or `draft` |
| `content` | Replacement view content (raw HTML or JSON box array) |
| `limit` | Integer — max entries to display |
| `menu_order` | Integer — ordering in listings |

`update-view` also backfills a missing `frm_form` postmeta on legacy views, and its response includes `content` and `limit`.

`update-view` accepts more than the table above — the same `apply_view_options()` path as `create-view` runs, so `before_content`, `after_content`, `detail_content`, and `options` all work on update.

**`before_content`/`after_content` are accepted both as top-level parameters and nested inside `options`**, and either spelling now updates the `frm_before_content` / `frm_after_content` postmeta that the front end actually renders from (`FrmViewsDisplaysController` reads `$view->frm_before_content`; the `frm_options` copy alone is inert). When both are sent, the top-level value wins. An `options` update that doesn't mention them leaves them untouched. Nesting them in `options` used to be a silent no-op that looked like a caching bug; fixed in `FrmAPIViewsController::apply_view_options()`, covered by `test_before_after_content_nested_in_options_updates_postmeta` and `test_top_level_before_content_takes_precedence_over_options`.

**`get-view` returns the persisted filters and before/after content.** View responses (get/create/update/list) include `before_content`, `after_content`, and `options` — the stored `frm_options` with the `where`/`where_is`/`where_val` filter arrays, `empty_msg`, ordering, etc. — alongside the earlier keys (`content`, `created_at`, `date_field_id`, `detail_content`, `form_id`, `id`, `limit`, `slug`, `status`, `title`, `updated_at`, `url`, `view_type`). A view with no stored options returns `options` as an empty object. Verify filters straight from the API response; fixed in `FrmAPIViewsController::prepare_item_for_response()`, covered by `test_get_view_returns_options_and_before_after_content` and `test_get_view_without_options_returns_object`. On older formidable-api builds `get-view` returned none of these three keys — there, verify in the view editor instead.

Filters are set through `options`: `where` (array of field IDs), `where_is` (array of operators), `where_val` (array of values, which may contain shortcodes such as `[get param=name]`). These parallel arrays are positional — index 0 of each belongs to the same rule. Example child-view filter for nested views:

```json
{
  "options": {
    "where": ["13408"],
    "where_is": ["="],
    "where_val": ["[get param=pass_code]"],
    "empty_msg": "No matching entries"
  }
}
```

Note that a `where_val` shortcode resolving to an empty string **drops the rule** instead of matching nothing, so such a view shows all entries when its param is absent — see the nested-views section in `shortcodes.md` before publishing one.

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/update-view",
        "parameters": {
          "id": "10637",
          "title": "High Scores (Top 10)",
          "limit": 10
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data | {id, title, content, limit}'
```

### CSV export button on a view (Export View add-on)

Requires the `formidable-export-view` add-on. Everything is driven by view `options`, so a full setup works in one MCP `create-view` call (verified end-to-end):

```json
{
  "form_id": 1604, "name": "Attempts Table", "type": "all", "status": "publish",
  "before_content": "<table><thead><tr><th>Entry</th><th>Team</th><th>Score</th></tr></thead><tbody>",
  "content": "<tr><td>[id]</td><td>[q3zqm]</td><td>[fnzkj]</td></tr>",
  "after_content": "</tbody></table>",
  "options": {
    "show_export_view": "1",
    "export_link_text": "Export as CSV",
    "filename": "quiz-attempts",
    "export_with_params": "0",
    "view_export_possible": "1"
  }
}
```

- **Only table-shaped All-Entries/Dynamic views export.** In the editor, `view_export_possible` is auto-computed by `FrmViewsDisplaysHelper::check_view_data_for_table_type()` (show_count `all`/`dynamic` AND `before_content` containing `<table`…`</table>`). MCP writes bypass that auto-compute, so set `view_export_possible: "1"` yourself — but keep the view genuinely table-shaped; the CSV is parsed from the rendered table.
- With `show_export_view: "1"`, the link (labeled by `export_link_text`) auto-appends when the full view renders — the view's own `/frm_display/` permalink works. There is also a `[frm-export-view view=<id-or-key> label="..."]` shortcode to place the link elsewhere; it errors visibly only for users with `frm_edit_displays` and renders nothing for visitors when misconfigured, and renders nothing when the view has no entries.
- The link is a signed `?frmdata=<blob>` URL (secret in the `frm_export_view_key` option, ~24h expiry via the `frm_export_view_link_expiration` filter). It works **without cookies** — anyone with the URL can download until it expires.
- The download is `text/csv` named `<timestamp>-<filename>.csv`; header row comes from the `<th>` cells, data rows from the body rows (verified byte-for-byte against the table).

### View Content Formats: Classic vs Layout

**Classic views** — post content is **raw HTML only** (no JSON, no boxes). Set `frm_grid_view` = 0.

```html
<table style="width:100%;">
  <tr><th>Field 1</th><th>Field 2</th></tr>
  <tr>
    <td>[field_key_1]</td>
    <td>[field_key_2]</td>
  </tr>
</table>
```

**Layout views** — post content is a **JSON array of boxes**, each containing HTML. Used for grid layouts, card layouts, and custom box structures.

```json
[
  {"box": 0, "content": ""},
  {"box": 1, "content": "<h2>Title</h2><p>[field_key]</p>"}
]
```

Field shortcodes like `[game2]` display individual field values; the view template repeats for each entry. The full shortcode catalog for view content — formatting parameters (`show=`, `sep=`, `truncate=`, …), conditionals (`[if x]`), `[editlink]`/`[deletelink]`/`[detaillink]`, `[foreach]`, `[evenodd]`, stats and graphs — is in `shortcodes.md`.

Full classic example (a styled high-scores table). **Prefer semantic class names + the View Custom CSS setting over inline `style=` attributes** (see "Styling views" below) — the content stays readable and easy for a non-developer to edit, and the CSS lives in one place:

```html
<!-- before_content -->
<table class="scores">
  <thead>
    <tr><th>Game</th><th>Player</th><th>Score</th></tr>
  </thead>
  <tbody>

<!-- content (repeats per entry) -->
    <tr>
      <td>[game2]</td>
      <td>[player2]</td>
      <td>[score2]</td>
    </tr>

<!-- after_content -->
  </tbody>
</table>
```

```css
/* options.listing_page_custom_css — auto-scoped to this view */
.scores {
  width: 100%;
  border-collapse: collapse;
}
.scores th {
  background: #ff006e;
  color: #000;
  padding: 10px;
  border: 2px solid #00f5ff;
}
.scores td {
  color: #00f5ff;
  padding: 10px;
  border: 2px solid #00f5ff;
}
```

### Styling views: prefer the View Custom CSS setting over inline styles

**Default to semantic class names in the HTML plus rules in the View Custom CSS setting — not inline `style=` attributes and not `<style>` tags inside the content.** Inline styles repeated on every `<td>`/`<div>` make the content unreadable and painful for a non-developer to update; a `<style>` block dumped into `content` is unscoped (it can restyle the whole page) and clutters the markup. The Custom CSS setting keeps the HTML clean and the styling in one editable place — the ability schema itself recommends this ("Prefer class attributes over inline style attributes, and put the rules in the `listing_page_custom_css` option").

The View Custom CSS lives in `frm_options`, set through the `options` parameter of `create-view`/`update-view`:

| Option key | Applies to |
|---|---|
| `listing_page_custom_css` | The main listing content (`content` + `before_content` + `after_content`). This is the one to use in almost every case. |
| `detail_page_custom_css` | The Detail Page (`detail_content`), rendered when an entry is opened via `[detaillink]`. |
| `custom_css` | Legacy single field. Bypasses kses like the two above but is **not** auto-scoped, and at render time `frm_custom_css` *overrides* `listing_page_custom_css` for the listing page. Prefer `listing_page_custom_css`; don't set both. |

Verified behavior (formidable-api + formidable-views):

- **The API auto-scopes `listing_page_custom_css` and `detail_page_custom_css` to the view.** Write plain selectors (`.scores td { ... }`); on save each rule is nested under `.frm-view-content-<view_id>` (and a `.scores.frm-view-content-<view_id>` variant, for when the class sits on the view container itself). So your CSS **cannot leak to the rest of the page**, and you never write the scope selector yourself. Re-sending stored CSS is idempotent — the scope isn't doubled (`FrmAPIViewsController::scope_css_options()` unnests then re-nests).
- **CSS options bypass kses** (`is_css_option()`), so child combinators (`>`), `url("img%20one.png")`, and entities survive intact — unlike ordinary HTML options, where kses would rewrite `>` to `&gt;`. Tags *are* stripped, so don't try to smuggle markup through a CSS option.
- **`get-view` returns all three keys** inside `options` (`listing_page_custom_css`, `detail_page_custom_css`, `custom_css`) — verify the round trip straight from the API response. The stored value comes back already scoped.
- The rendered view is wrapped in `<div class="frm-view-content-<id>">…</div>`, and Views prints the CSS inline on the page (`FrmViewsInlineStyleController`). Handy for confirming in the browser which view a rule belongs to.

Worked pattern (a card grid built with readable HTML and zero inline styles — verified rendering end-to-end):

```json
{
  "form_id": 1616, "name": "Species Cards", "type": "all", "status": "publish",
  "before_content": "<div class=\"species-grid\">",
  "content": "<article class=\"species-card\">\n  <h3 class=\"species-card__name\">[9mrji]</h3>\n  <em class=\"species-card__sci\">[zf18c]</em>\n  <p class=\"species-card__status status--[7wn98 sanitize=1]\">[7wn98]</p>\n  <p class=\"species-card__notes\">[ksir6 wpautop=0]</p>\n</article>",
  "after_content": "</div>",
  "options": {
    "order_by": ["13473"], "order": ["ASC"],
    "listing_page_custom_css": ".species-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }\n.species-card { border: 1px solid #e2e2e2; border-radius: 10px; padding: 18px; }\n.status--critically-endangered { background: #fde2e1; color: #b71c1c; }\n.status--vulnerable { background: #fff8db; color: #8a6d00; }"
  }
}
```

Two techniques in that example worth reusing:

- **Data-driven classes via `sanitize=1`**: `status--[7wn98 sanitize=1]` turns the field value "Critically Endangered" into the class `status--critically-endangered` (lowercase, spaces → dashes), so a CSS rule can color each row by its saved value with no per-entry conditionals. Combine with `remove_accents=1` if values may contain accents.
- **`wpautop=0` on rich-text/paragraph fields placed inside a block element** — a paragraph/textarea field value is itself auto-paragraphed, so `<p>… [ksir6]</p>` becomes invalid nested `<p>`. `[ksir6 wpautop=0]` keeps it inline. (Same gotcha as in emails — see actions.md / shortcodes.md §4.)

> **Gotcha — `order_by`/`order` take field IDs, not field keys.** View *content* uses field keys, but `order_by` does not: passing a key (e.g. `order_by: ["r5ovm"]`) generates `ORDER BY it.r5ovm`, an unknown column, so the entries query **errors and the view silently renders `empty_msg` ("No Entries Found")** — no MCP error, nothing in the API response, only a `WordPress database error Unknown column 'it.<key>'` line in `debug.log`. Use the numeric field ID (`order_by: ["13473"]`). `created_at`/`id` also work. Both `order_by` and `order` must be arrays. If a freshly created view shows no entries even though the form has some, suspect `order_by` first and check the debug log.

### View Shortcodes Must Use Field KEYS, Not Field Names

When writing view templates, ALWAYS use field keys (e.g., `[lwrli]`), NEVER field names (e.g., `[story_category]`).

- Field names are display labels with no consistent relationship to fields
- Field keys are the unique identifiers Formidable uses to retrieve field values
- Using field names results in blank/empty output in the rendered view

Get the field keys for a form with `formidable-forms/list-fields` (params: `form_id`). Note: the response `data` is an **object keyed by field_key**, not an array.

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-fields",
        "parameters": {
          "form_id": "1429"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data | to_entries[] | "\(.value.name) => [\(.value.field_key)]"'
```

```html
<!-- WRONG - using field names -->
<p>[story_category] - [character_name] - [generated_story]</p>

<!-- RIGHT - using field keys -->
<p>[lwrli] - [v8lk9] - [generatedstory]</p>
```

Example: a template using `[maincharactername]`, `[storycategory]`, `[characterarchetypes]` renders blank values; the actual field keys `[v8lk9]`, `[lwrli]`, `[jbpgm]` display correctly.

Alternative: field IDs also work (e.g., `[13086]`), but field keys are preferred for portability across sites.

## Detail Pages (`[detaillink]`)

`create-view`/`update-view` accept `detail_content` (stored in the `frm_dyncontent` postmeta); `get-view` returns it. Put `<a href="[detaillink]">View details</a>` in the listing content and the link resolves to the view's URL + `/entry/<id>` (or `?entry=<id>`), where the Detail Page content renders for that entry.

Per view type:

- **Classic (`all`)**: `detail_content` is raw HTML. Setting a non-empty value auto-switches `frm_show_count` to `dynamic` (required for detail routing — the API keeps it in sync; clearing the content switches it back to `all`).
- **Grid / table (layout views)**: `detail_content` is a JSON box array (same format as listing content), and a **detail layout** must exist: `create-view-layout` with `type: "detail"`, e.g. `data: [{"id":0,"layout":1,"boxes":[{"id":1}]}]`. For table views, a detail-link column needs its box added to BOTH the content JSON (`{"box":4,"name":"Details","content":"<a href=\"[detaillink]\">View</a>"}`) and the listing layout's `boxes` array — `create-view-layout` upserts, so re-send the full listing layout with the new box.
- **Timeline**: `detail_content` is raw HTML. A non-empty value makes each card an entry link automatically; for the hover **details popup** instead, set `frm_options.timeline_options.settings.show_details_popup = 1` via the `options` param — send the complete `timeline_options` structure (`{style: [], settings: {...all keys...}}`), because `options` replaces top-level keys wholesale. Note: the timeline's own `/entry/<id>` links render the listing, not a detail page (detail routing only honors `dynamic`/`calendar` views) — prefer the popup.

## Querying Views

List all views — ability: `formidable-forms/list-views`

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-views",
        "parameters": {}
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data[] | {id, title, slug, form_id}'
```

Get a specific view — ability: `formidable-forms/get-view`

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/get-view",
        "parameters": {
          "id": "42"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data'
```

## Field Statistics: `formidable-forms/get-stats`

Calculates statistics for one or more field values across entries. This single MCP ability replaces all 9 REST stats endpoints. It is idempotent and read-only.

### Parameters

**`type`** (required) — the statistical calculation to perform:

| Type | Meaning |
|---|---|
| `total` | Sum of all values |
| `count` | Number of entries/responses |
| `average` | Mean value |
| `median` | Middle value |
| `star` | Star rating average |
| `maximum` | Highest value |
| `minimum` | Lowest value |
| `unique` | Count of unique values |
| `deviation` | Standard deviation |

**`field_id`** (required) — field identifier(s):

- Single field ID: `12753`
- Single field key: `s84bj`
- Multiple fields (batch stats in one call): `12753,12754,12755` or `s84bj,abc12,def34`

### Response

Object keyed by field ID/key with the computed statistics:

```json
{
  "12753": 42.5,
  "12754": 156
}
```

### Availability and Permissions

- **Requires Formidable Pro** (`FrmProStatisticsController` must exist). The ability is not available on sites without a Pro license.
- Requires the `frm_view_entries` capability or an admin role.
