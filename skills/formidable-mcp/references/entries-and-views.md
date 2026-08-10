# Entries, Views & Stats

Read this when: querying or managing form submissions (entries), creating or fixing views that display entries, or computing field statistics via the Formidable MCP adapter.

## MCP Session Setup

All examples below use the Formidable MCP HTTP endpoint. Initialize a session once, then reuse the session ID. Replace `https://your-site.local` with your site URL and `admin:APP_PASSWORD` with your WordPress username and application password.

```bash
SESSION=$(curl -s -i -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -u "admin:APP_PASSWORD" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}},"id":1}' \
  2>&1 | grep -i "mcp-session-id" | cut -d' ' -f2 | tr -d '\r')
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
  }' 2>&1 | jq '.result.structuredContent.data[] | {id, form_id, created_at, user_id}'
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
  }' 2>&1 | jq '.result.structuredContent.data'
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
  }' 2>&1 | jq '.result.structuredContent.data'
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
  }' 2>&1 | jq '.result.structuredContent.data'
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
  }' 2>&1 | jq '.result.structuredContent.data'
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
  }' 2>&1 | jq '.result.structuredContent'
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
  }' 2>&1 | jq '.result.structuredContent.data | {id, name, form_id, content, limit}'
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
  }' 2>&1 | jq '.result.structuredContent.data | {id, title, content, limit}'
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

### Write view content as readable HTML

**Format view content the way a person would write it — block-level tags on their own lines, indented by nesting depth.** View `content`, `before_content`, `after_content`, and grid box `content` all preserve newlines and tabs through save and `get-view`, so there is no reason to emit one unbroken line. A wall of jammed-together markup is the single clearest sign a machine wrote it, and it is what a site owner has to edit later in the Views editor.

```html
<div class="monkey-card__media"><img class="monkey-card__photo" src="[photo-url]" alt="[common-name]" /></div>
<div class="monkey-card__body">
	<h3 class="monkey-card__name">[common-name]</h3>
	<ul class="monkey-card__facts">
		<li><span>Group</span>[group]</li>
		<li><span>Status</span><em class="monkey-status monkey-status--[conservation-status sanitize=1]">[conservation-status]</em></li>
	</ul>
</div>
```

Two constraints from `wpautop`, both verified by inspecting the rendered DOM:

- **Keep an inline run on one line.** A newline *between inline elements* becomes a `<br>` — breaking `<li><span>Status</span>` and `<em>…</em>` across two lines injects a line break inside the `<li>`. Indentation *between block-level tags* is safe.
- **Make every top-level child a block element.** A bare leading `<img>` followed by a newline and a `<div>` produced a stray empty `<p>`; wrapping the image in a `<div>` removed it.

So: newlines and tabs for structure, inline content unbroken, no bare inline elements at the top level. Verified: the card above renders with **0** stray `<br>` and **0** empty `<p>`.

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
- **`options` merges on update.** Sending `options: {"grid_column_count": 2}` to `update-view` leaves `listing_page_custom_css`, `order_by`, and the rest untouched (verified) — you never need to re-send the whole options object to change one key.

> **Gotcha — don't size view CSS in `rem`.** `rem` resolves against the *theme's* root font-size, and the 62.5%-root trick is common: on Twenty Twenty `html` is **10px** while body text is 18px, so `font-size: .78rem` renders at **7.8px**, not the ~12.5px intended. Every `rem` value silently comes out at 62.5% of what you meant, and it changes per theme. Use `px` for predictable sizing (or `em`, which inherits the real body size). Check with `getComputedStyle(document.documentElement).fontSize` before trusting `rem` in a view.
- The rendered view is wrapped in `<div class="frm-view-content-<id>">…</div>`, and Views prints the CSS inline on the page (`FrmViewsInlineStyleController`). Handy for confirming in the browser which view a rule belongs to.

Worked pattern (a card gallery — verified rendering end-to-end). **Note the `type: "grid"`**: for anything laid out as cards or columns, use a grid view and its built-in column setting rather than a classic view with a hand-rolled `display:grid` container — see "Grid views" below for why.

```json
{
  "form_id": 1616, "name": "Species Cards", "type": "grid", "status": "publish",
  "content": "[{\"box\":0,\"content\":\"\",\"style\":{\"backgroundColor\":\"#ffffff\",\"borderColor\":\"#e5e7eb\",\"borderStyle\":\"solid\",\"borderWidth\":\"1px\",\"borderRadius\":\"12px\",\"padding\":\"0\"}},{\"box\":1,\"content\":\"<img class=\\\"species-card__photo\\\" src=\\\"[fxq2p]\\\" alt=\\\"[9mrji]\\\" loading=\\\"lazy\\\" /><div class=\\\"species-card__body\\\"><h3 class=\\\"species-card__name\\\">[9mrji]</h3><em class=\\\"species-card__sci\\\">[zf18c]</em><p class=\\\"species-card__status status--[7wn98 sanitize=1]\\\">[7wn98]</p><p class=\\\"species-card__notes\\\">[ksir6 wpautop=0]</p></div>\"}]",
  "options": {
    "grid_column_count": 3, "grid_row_gap": 24, "grid_column_gap": 2,
    "order_by": ["13473"], "order": ["ASC"],
    "listing_page_custom_css": ".species-card__photo { width: 100%; height: 190px; object-fit: cover; display: block; border-radius: 12px 12px 0 0; }\n.species-card__body { padding: 16px 18px 18px; }\n.status--critically-endangered { background: #fde2e1; color: #b71c1c; }\n.status--vulnerable { background: #fff8db; color: #8a6d00; }"
  }
}
```

The card frame (background, border, radius, padding) comes from **box 0's `style` object**, the column count from **`grid_column_count`**, and only the *inside* of the card needs Custom CSS. Three techniques worth reusing:

- **Data-driven classes via `sanitize=1`**: `status--[7wn98 sanitize=1]` turns the field value "Critically Endangered" into the class `status--critically-endangered` (lowercase, spaces → dashes), so a CSS rule can color each row by its saved value with no per-entry conditionals. Combine with `remove_accents=1` if values may contain accents.
- **`wpautop=0` on rich-text/paragraph fields placed inside a block element** — a paragraph/textarea field value is itself auto-paragraphed, so `<p>… [ksir6]</p>` becomes invalid nested `<p>`. `[ksir6 wpautop=0]` keeps it inline. (Same gotcha as in emails — see actions.md / shortcodes.md §4.)
- **`loading="lazy"` on card images** — good practice, but remember it when verifying: a full-page screenshot taken straight after navigation shows below-the-fold images blank. Force them (`img.removeAttribute('loading')`, scroll, wait) before judging a render or capturing a screenshot.

> **Gotcha — `order_by`/`order` take field IDs, not field keys.** View *content* uses field keys, but `order_by` does not: passing a key (e.g. `order_by: ["r5ovm"]`) generates `ORDER BY it.r5ovm`, an unknown column, so the entries query **errors and the view silently renders `empty_msg` ("No Entries Found")** — no MCP error, nothing in the API response, only a `WordPress database error Unknown column 'it.<key>'` line in `debug.log`. Use the numeric field ID (`order_by: ["13473"]`). `created_at`/`id` also work. Both `order_by` and `order` must be arrays. If a freshly created view shows no entries even though the form has some, suspect `order_by` first and check the debug log.

### Grid views: columns, card styling, and the box/layout model

**For any card- or column-based layout, create the view with `type: "grid"` rather than building a CSS grid inside a classic view.** A grid view already ships the responsive container, the per-entry card wrapper, a column setting, and a set of card style settings — reproducing that with `before_content: "<div class=grid>"` plus `display:grid` in Custom CSS re-implements what the product does natively, and skips the settings a site owner can later edit in the Views editor. Use classic (`type: "all"`) for tables, lists, and free-form HTML.

**Rendered structure** (verified in the browser):

```html
<div class="frm-view-content-<id> frm_grid_container with_frm_style frm-grid-view"
     style="--v-tl-…; --v-tl-grid-column:span 4/span 4; grid-gap: 24px 2%;">   <!-- view root: a 12-column CSS grid -->
  <div>                                                    <!-- one per entry — this is the card -->
    <div class="frm_grid_container frm_no_grid_750">        <!-- a layout row -->
      <div class="frm12">…box content…</div>                <!-- a box; frm12 = span 12 of 12 -->
    </div>
  </div>
  …
</div>
```

Boxes get `.frm{n}` classes that Formidable already styles as `grid-column: span n` on the 12-column grid — `frm12` full width, `frm9` three-quarters, `frm8` two-thirds, `frm6` half, `frm4` a third, `frm3` a quarter. You don't write any of that CSS.

**Responsive collapse.** With `grid_responsive` on (the default), Formidable adds `frm_no_grid_750` — the media rule is `@media only screen and (max-width: 750px) { .frm_grid_container.frm_no_grid_750 > div { grid-column: span 12 / span 12 } }`. **Which element gets the class depends on `grid_column_count`, and the two cases collapse different things** (verified at a 700px viewport):

| `grid_column_count` | Class lands on | Below 750px |
|---|---|---|
| 2, 3, 4, 6, 12 | the **view root** | **cards** go one per row; boxes inside a row keep their `frm{n}` spans |
| 1 or unset | the **layout row** | the row's **boxes** each go full width and stack; there is only one card per row anyway |

So a multi-column gallery becomes single-column on mobile automatically, but a multi-box row inside a card does *not* — if a card's internal columns must stack on narrow screens, write that media query yourself in Custom CSS.

**Columns and gaps — `frm_options` keys**, set via the `options` parameter:

| Option | Effect |
|---|---|
| `grid_column_count` | **Cards per row.** Only `2`, `3`, `4`, `6`, `12` are mapped (→ `span 6/4/3/2/1`); anything else, including `1` and unset, means one full-width card per row (`FrmViewsDisplaysController::get_grid_column_style_from_column_count()`). |
| `grid_row_gap` | Row gap in **px**. Default `20`. |
| `grid_column_gap` | Column gap in **%**. Default `2`. |
| `grid_responsive` | `1` (the default) adds the `frm_no_grid_750` breakpoint class — see "Responsive collapse" above. `0` disables it. |
| `grid_classes` | Extra space-separated classes appended to the view root (verified: `"my-custom-grid another-class"` both land on the root div). |

> **Gotcha — Custom CSS cannot change the column count.** Views writes `--v-tl-grid-column` as an **inline style on the view root**, so a `listing_page_custom_css` rule setting that variable (or `grid-column` on the card) always loses to it, silently: the CSS saves, scopes, and renders, and the layout simply doesn't change. Set `grid_column_count` instead. Verified by inspecting the computed style.

**Two levels of style settings.** Every box in the content JSON accepts a `style` object, and where it lands depends on which box:

| Level | Set on | Editor panel | Rendered as | Affects |
|---|---|---|---|---|
| **Container / card** | **box 0** | Grid View style settings | `--v-tl-*` custom properties on the view root | every entry card (`.frm-grid-view > div`) |
| **Cell** | any **content box** (1, 3, 5…) | **Cell Settings** | a plain `style=""` attribute on that box's `.frm{n}` div | just that cell, in every entry |

Both use the same camelCase keys. **One key differs between the levels:** `borderWidth` becomes `--v-tl-border-**thickness**` at the container level but plain `border-width` on a cell (`convert_camel_case_style()` switches on a `grid-top-level` vs `grid-cell` context — the top-level rename dodges a WP core rule that forces `border-style` on anything matching `border-width`).

Use the container level for the card frame, and cell settings when a single box needs its own treatment — a tinted header box, a bordered stat cell — instead of adding a wrapper `<div>` and a Custom CSS rule for it.

```json
{"box": 1,
 "content": "<span>[9mrji]</span>",
 "style": {"backgroundColor": "#fff8db", "borderColor": "#8a6100", "borderStyle": "dashed",
           "borderWidth": "2px", "borderRadius": "10px", "padding": "8px",
           "fontSize": "21px", "lineHeight": "1.8"}}
```

renders as `<div class="frm12" style="background-color: #fff8db;border-color: #8a6100;border-style: dashed;border-width: 2px;border-radius: 10px;padding: 8px;font-size: 21px;line-height: 1.8;">` (verified end-to-end, and the `style` object survives the `get-view` round trip unchanged).

> **Cell styles are inline too**, so — like `--v-tl-grid-column` — a `listing_page_custom_css` rule targeting the same property on that box will silently lose. Set the value in the box's `style` object, not in Custom CSS.

The eight accepted keys, at both levels (anything else passes through unconverted and won't be valid CSS):

| `style` key | Container property | Cell property | Editor control | Notes |
|---|---|---|---|---|
| `backgroundColor` | `--v-tl-background-color` | `background-color` | Background | container default `initial` |
| `borderColor` | `--v-tl-border-color` | `border-color` | Border | container default `#efefef` |
| `borderWidth` | `--v-tl-border-thickness` | `border-width` | Border | **the one key that differs** |
| `borderStyle` | `--v-tl-border-style` | `border-style` | Border | container default `solid` |
| `borderRadius` | `--v-tl-border-radius` | `border-radius` | Border radius | |
| `padding` | `--v-tl-padding` | `padding` | Padding | container default `10px`; `"0"` for full-bleed images |
| `fontSize` | `--v-tl-font-size` | `font-size` | Typography | |
| `lineHeight` | `--v-tl-line-height` | `line-height` | Typography | |

A key **omitted** from a box's `style` is not written out at all, so Custom CSS can still set it; a key present always wins. Prefer the `style` objects for the frame (card and cell) and Custom CSS for everything inside — `.frm-grid-view` declares the container defaults, so an unset container key falls back to `--v-tl-padding: 10px`, `--v-tl-border-color: #efefef`, `--v-tl-border-style: solid`, `--v-tl-border-thickness: 1px`, and `initial` for the rest.

**Box numbering and layout rows.** On create, boxes are renumbered to the editor's scheme: **box 0 is the grid container, content boxes take the odd ids 1, 3, 5…, and layout rows take the even ids**. Send `[{"box":1,…},{"box":2,…}]` and `get-view` returns boxes `0, 1, 3`. On update, reuse the ids `get-view` reports so they keep matching the stored layout.

Each content box is added to the listing layout automatically, **one row per box** — two boxes render stacked, not side by side. To put them in one row, call `create-view-layout` (it upserts, replacing the layout of the same type):

```json
{"view_id": 11278, "type": "listing",
 "data": [{"id": 0, "layout": 2, "boxes": [{"id": 1}, {"id": 3}]}]}
```

`layout` is **not** simply a column count — it's a preset id, and five of the nine are asymmetric splits (`FrmViewsLayoutHelper::get_layout_wrapper_class()`):

| `layout` | Split | Box classes, in order |
|---|---|---|
| `1` | full width | `frm12` |
| `2` | halves | `frm6`, `frm6` |
| `3` | thirds | `frm4`, `frm4`, `frm4` |
| `4` | quarters | `frm3`, `frm3`, `frm3`, `frm3` |
| `5` | 25 / 75 | `frm3`, `frm9` |
| `6` | 75 / 25 | `frm9`, `frm3` |
| `7` | 25 / 50 / 25 | `frm3`, `frm6`, `frm3` |
| `8` | 33 / 67 | `frm4`, `frm8` |
| `9` | 67 / 33 | `frm8`, `frm4` |

Anything else yields no class at all (the box renders unstyled), so don't pass a raw column count above 4. Verified end-to-end: `layout: 3` → three `frm4`; `layout: 7` → `frm3`/`frm6`/`frm3` measuring 62/128/62px.

`list-view-layouts` takes an optional `type` filter (`listing` or `detail` only). Detail pages need their own `type: "detail"` layout — see "Detail pages" below.

#### Nested layouts

**A box can contain its own rows.** Give a box a `rows` array instead of leaving it a leaf, and it becomes a nested 12-column grid inside its `.frm{n}` cell. The structure is recursive: `rows → boxes → rows → boxes …`

```json
[
  {"id": 600, "layout": 5, "boxes": [
    {"id": 700, "rows": [
      {"id": 601, "layout": 1, "boxes": [{"id": 1}]},
      {"id": 602, "layout": 1, "boxes": [{"id": 3}]}
    ]},
    {"id": 701, "rows": [
      {"id": 603, "layout": 1, "boxes": [{"id": 5}]},
      {"id": 604, "layout": 2, "boxes": [{"id": 7}, {"id": 9}]}
    ]}
  ]},
  {"id": 606, "layout": 1, "boxes": [{"id": 11}]}
]
```

That renders a 25/75 split where the narrow column stacks a thumbnail over a badge, the wide column stacks a header over a two-up stat row, and a full-width row sits underneath. Verified end-to-end.

Practical rules, all learned the hard way:

- **A box with `rows` holds no content of its own** — it is purely a container. Put content in the leaf boxes.
- **Ids are yours to choose and are not validated against the content boxes.** Container boxes and rows can use ids that appear nowhere in `content` (they render as empty structure); a leaf id with no matching content box renders an empty cell. Pick a distinct range (e.g. rows `600+`, containers `700+`) so they never collide with the content ids.
- **Nested rows do NOT get `frm_no_grid_750`** — only top-level rows do. A nested multi-column row stays side-by-side on mobile unless you write the media query yourself.
- **Give sibling columns the same number of nested rows.** The Layout Builder lays the tree out as a visual grid, so a column with fewer rows than its sibling shows up as an empty hole in the UI. If one side needs less, promote the extra content to a full-width top-level row instead of padding the short column.
- **Nesting multiplies the width division.** A `frm4` (⅓) containing a three-column row gives each nested cell **1/9** of the card. In a 580px content column at 3-up that's ~62px — unreadable. Budget the width down the tree before choosing a depth: *content column ÷ cards-per-row ÷ each nested division*.

> **Gotcha — `create-view` renumbers box ids, `update-view` does not.** On create, whatever ids you send are rewritten to the editor scheme (content boxes on odd ids). On update the ids are stored **exactly as sent** — so re-sending `content` with boxes `1,2,3` after a create assigned `1,3,5` silently orphans every layout reference, and the view renders empty cells. Read the ids back with `get-view` and reuse them, or re-send the layout to match.

> **Gotcha — a grid showing fewer cards than the form has entries is usually pagination, not a filter.** `options.page_size` (with `ajax_pagination`) caps how many entries render per page, and it is *separate* from `limit`. A view with `page_size: "3"` renders three cards and, with `ajax_pagination` on and only one page's worth of extra entries, may show **no visible pagination links at all** — so it just looks like entries are missing. Check `page_size` in `get-view` before suspecting `order_by`, filters, or the entries themselves; clear it with `options: {"page_size": ""}`. Count the rendered cards against `list-entries` as part of verifying any view.

**Sizing sanity check.** `grid_column_count` divides the *theme's content column*, not the window. In a typical ~580px single-post column, 3 cards land at ~186px each and text wraps badly; 2 cards at ~280px read well. Measure the rendered card width before settling on a column count rather than assuming 3- or 4-up looks good.

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
  }' 2>&1 | jq '.result.structuredContent.data | to_entries[] | "\(.value.name) => [\(.value.field_key)]"'
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
  }' 2>&1 | jq '.result.structuredContent.data[] | {id, title, slug, form_id}'
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
  }' 2>&1 | jq '.result.structuredContent.data'
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
