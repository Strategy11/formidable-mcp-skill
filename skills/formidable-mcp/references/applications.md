# Applications (Pro)

Read this when: creating or managing Formidable Applications (Pro) — grouping forms, views, and pages as `frm_application` taxonomy terms — or building/troubleshooting the views that live inside them.

## Overview

**What is an Application?**
- A Formidable Pro feature that groups forms, views, and pages together
- Stored as WordPress taxonomy terms in the `frm_application` taxonomy
- Forms linked via `_frm_form_id` metadata
- Views/pages linked via `term_relationships` table entries
- Displays as a card on the applications management page with form/view counts

**Use Cases:**
- Group related forms (e.g., "HR", "Sales", "Support")
- Create arcade-style high scores applications with custom views
- Organize multi-form workflows

## Architecture

### Storage Model
```
Applications = wp_terms (taxonomy: frm_application)
  ├─ Forms: wp_termmeta with key "_frm_form_id" (can have multiple)
  ├─ Views/Pages: wp_term_relationships (post_type: frm_display)
  └─ Metadata: _frm_created_at, _frm_updated_at, _frm_form_count, _frm_view_count, _frm_page_count
```

### Key Retrieval Methods (Pro internals)
- **Forms**: `FrmProApplication::get_forms_for_application($id)` queries `_frm_form_id` metadata
- **Views**: `FrmProApplication::get_posts_for_application($id)` queries `term_relationships` with `tax_query` for `post_type: frm_display`

**Critical Point:** Views MUST have `post_type: "frm_display"` (NOT "frm_views"). The retrieval code specifically queries for `frm_display` posts.

**You never need to write to this storage directly.** The Formidable MCP abilities fully cover application management: `list-applications`, `get-application`, `create-application`, `add-item-to-application`, `remove-item-from-application`, `list-application-items`, `delete-application`. Notably, `add-item-to-application` handles the storage difference internally — forms go to `_frm_form_id` termmeta, views/pages go to `term_relationships` — so callers do not need to know that distinction to link items. Keep this storage model in mind only as background for interpreting what the abilities return.

## Complete Workflow: Creating an Application

Every step uses Formidable MCP abilities. **No wp-cli or SQL writes anywhere in this workflow.** Call each ability via `mcp-adapter-execute-ability` (MCP over HTTP, or the stdio bridge `wp mcp-adapter serve --server=formidable-mcp --user=1` — see the MCP protocol reference for transport/session boilerplate). Only ability names and parameters are shown below.

### Step 1: Create a Form

`formidable-forms/create-form`:

```json
{"name": "High Scores", "description": "Top arcade game scores"}
```

**Result:** `FORM_ID` (e.g., `1429`)

### Step 2: Add Fields to the Form

`formidable-forms/create-field`, once per field. `submit` is not a creatable type — set the button label with `update-form` `options.submit_value`. If the form already has a `submit` field (older/editor-built forms), keep it at the highest `field_order`.

```json
{"form_id": "1429", "type": "text", "name": "Game", "field_order": 1}
```

Add more fields (name, score, etc.) with sequential `field_order` values.

View templates need field **keys** (not names) for shortcodes — get them with `formidable-forms/list-fields` for the form (e.g., `[game2]`, `[player2]`, `[score2]`).

### Step 3: Create the View (one call)

> **Before writing view content, read `entries-and-views.md` § "Styling views" and § "Grid views".** Two rules decide the shape of this call and are easy to miss when arriving from this page: styling goes in the View Custom CSS setting (`options.listing_page_custom_css`), never inline `style=` attributes; and a card/column layout should be a **`type: "grid"`** view with `options.grid_column_count`, not a classic view wrapping a hand-built `display:grid` container.

`formidable-forms/create-view` creates the `frm_display` post AND sets ALL required postmeta automatically (`frm_form_id`, `frm_form`, `frm_param`, `frm_type`, `frm_active_preview_filter`, `frm_dyncontent`, `frm_grid_view`, `frm_show_count`, `frm_options`). **Do not create views with `wp post create` or `wp_insert_post`.**

Parameters: `form_id` (required, int), `name`, `type` (`all`|`grid`|`table`|`map`|`timeline`|`calendar`, default `all`), `content` (raw HTML for classic views; JSON box array for layout views), `before_content` / `after_content` (strings rendered once before/after the repeating content — written to both the `frm_before_content`/`frm_after_content` postmeta and the matching `frm_options` keys automatically), `options` (object merged into `frm_options`: `where`/`where_is`/`where_val`/`where_or` filter arrays, `empty_msg`, `page_size`, `order_by`, etc.), `limit`, `status` (`publish`|`private`|`draft`, default `private` — verified in FrmAPIViewsController; set `publish` explicitly for public views).

```json
{
  "form_id": 1429,
  "name": "High Scores Leaderboard",
  "content": "<table style=\"width:100%; border-collapse:collapse;\"><thead><tr><th>Game</th><th>Player</th><th>Score</th></tr></thead><tbody><tr><td>[game2]</td><td>[player2]</td><td>[score2]</td></tr></tbody></table>"
}
```

**Result:** `VIEW_ID` (e.g., `10634`)

Content rules still apply:
- **Classic views**: `content` is **plain HTML only** with `[field_key]` shortcodes (no JSON metadata like `{"form_id":X,"type":"table"}` — that makes the view show as "(no title)" on the frontend)
- **Layout views**: `content` is a JSON array of boxes (advanced use case)
- Each entry repeats the template row/content

To change a view later, use `formidable-forms/update-view` — it accepts `id` plus the same content parameters (`content`, `before_content`, `after_content`, `options`, `limit`, `post_status`, `title`), and backfills a missing `frm_form` postmeta on views that lack it.

### Step 4: Create the Application

`formidable-forms/create-application` — `name` (required), optional `description`. Returns `{id, name, message}`.

```json
{"name": "High Scores", "description": "Arcade game high scores"}
```

**Result:** `APPLICATION_ID` (e.g., `48`)

### Step 5: Add the Form to the Application

`formidable-forms/add-item-to-application` — `application_id` (int), `item_id` (int), `item_type` (`"form"`|`"view"`|`"page"`), all required:

```json
{"application_id": 48, "item_id": 1429, "item_type": "form"}
```

Repeat for each additional form.

### Step 6: Add the View to the Application

Same ability, `item_type: "view"`:

```json
{"application_id": 48, "item_id": 10634, "item_type": "view"}
```

The ability routes storage correctly on its own (forms → `_frm_form_id` termmeta; views/pages → `term_relationships`) — you don't need to know that distinction to link items.

Related abilities: `formidable-forms/remove-item-from-application` (same params) to unlink an item; `formidable-forms/delete-application` (`application_id`) to delete the whole application.

### Step 7: Verify with list-application-items

`formidable-forms/list-application-items`:

```json
{"application_id": 48}
```

Returns `{application_id, application_name, items: [{id, name, type}]}` — confirm the form and view both appear.

### Optional: Add Sample Entries

`formidable-forms/create-entry` (values keyed by field ID or field key), once per entry:

```json
{"form_id": "1429", "1": "Pac-Man", "2": "Billy Mitchell", "3": "9999999"}
```

## Verification

After creating an application, verify it displays correctly:

1. **MCP (primary)**: Call `formidable-forms/list-application-items` with the `application_id` and confirm every expected item appears in `items` with the right `type`.

2. **Applications Page**: `/wp-admin/admin.php?page=formidable-applications`
   - Should show application card with form/view counts
   - Example: "High Scores | 1 Form | 1 View"

3. **Use a browser (e.g., Playwright) to verify**: Open the applications page and verify the application appears with correct counts and content displays.

4. If the MCP result and the admin UI disagree, re-run `list-application-items` after a hard refresh before assuming the data is wrong — and fix any real discrepancy with the MCP abilities, never with direct writes.

## Common Mistakes & Solutions

| Mistake | Problem | Solution |
|---------|---------|----------|
| View has `post_type: frm_views` | Application shows "no items" | Create views with the `create-view` ability (always uses `frm_display`); fix existing bad posts by recreating via `create-view` |
| Form added to `term_relationships` | Application shows empty | Link forms with `add-item-to-application` (`item_type: "form"`) — it stores forms in `_frm_form_id` termmeta automatically |
| Missing metadata counts | Application doesn't display correctly | Create applications with `create-application` and link items with `add-item-to-application` instead of manual term writes |
| Missing `post_author` on view post | View behaves inconsistently in admin | Create views with the `create-view` ability instead of `wp post create` |
| Submit button in middle of form | UX breaks | Ensure submit button has highest `field_order` value |
| Form has no fields | Cannot add entries | Add fields before creating entries |
| View post_content is JSON metadata | View shows as "(no title)" on frontend | Use plain HTML for classic views, not `{"form_id":X,"type":"table"}` |
| View missing postmeta | View doesn't display/appear in lists | Create views with `create-view` — it sets all required postmeta (`frm_form_id`, `frm_form`, `frm_options`, `frm_show_count`, etc.) automatically |
| View not linked to form | View doesn't appear in `/wp-admin/edit.php?post_type=frm_display&form=X` | `create-view` sets both `frm_form_id` and `frm_form`; for older views, `update-view` backfills a missing `frm_form` |
| View not linked to application | View doesn't appear in application | Use `add-item-to-application` with `item_type: "view"` (it writes the `term_relationships` row internally) |
| **Using layout view (frm_grid_view: 1) to show before/after content once** | ALL boxes repeat for every entry, including header/footer | Use a classic view (frm_grid_view: 0) with the `before_content`/`after_content` parameters for content that appears once |
| **Storing HTML with quotes in JSON layout-view content** | JSON syntax error; content doesn't render | Build the `content` string with `json_encode($boxes, JSON_UNESCAPED_SLASHES)` so all HTML strings are properly escaped |
| **Putting once-only header/footer in the row template** | Header/footer repeat per entry; JSON might be visible | For classic views: put the repeating row template in `content` and the once-only header/footer in `before_content`/`after_content` |
| **Creating layout view (JSON boxes) for filtered data display** | Header repeats for each entry (390 boxes instead of 10) | Use a classic view with `before_content`/`after_content` instead; layout views are only for card/grid layouts where you want each entry in its own box |
| **Writing before/after content into `frm_options` postmeta by hand** | Content stored but never displays; causes JSON to show instead | Pass `before_content`/`after_content` to `create-view`/`update-view` — they write both the `frm_before_content`/`frm_after_content` postmeta and the matching `frm_options` keys |

## API Reference

### Application Abilities (use these for all writes)

| Ability | Params | Notes |
|---------|--------|-------|
| `formidable-forms/list-applications` | none | Returns array of `{id, name, form_count, view_count, page_count, created_at, updated_at}` |
| `formidable-forms/get-application` | `application_id` | Same object shape as the list; 404 for unknown ids |
| `formidable-forms/create-application` | `name` (required), `description` (optional) | Returns `{id, name, message}` |
| `formidable-forms/add-item-to-application` | `application_id` (int), `item_id` (int), `item_type` (`"form"`\|`"view"`\|`"page"`) — all required | Routes storage internally (forms → termmeta, views/pages → term_relationships) |
| `formidable-forms/remove-item-from-application` | Same as add | |
| `formidable-forms/list-application-items` | `application_id` | Returns `{application_id, application_name, items: [{id, name, type}]}` — use for verification |
| `formidable-forms/delete-application` | `application_id` | Forms/views/pages remain, just unlinked |

The sections below describe the underlying storage — background/debugging knowledge only (read-only inspection). All writes go through the abilities above plus `create-view`/`update-view`.

### Application Metadata Keys
- `_frm_form_id` — Form ID (repeating, one per form)
- `_frm_form_count` — Number of forms in application
- `_frm_view_count` — Number of views in application
- `_frm_page_count` — Number of pages in application
- `_frm_created_at` — Unix timestamp of creation
- `_frm_updated_at` — Unix timestamp of last update

### View Post Type & Metadata

**Post Properties:**
- Must be `post_type: frm_display` (not `frm_views`)
- `post_author` should be set to a valid user ID (e.g., `1`)
- `post_status` should be `publish`

**post_content Format:**
- **Classic Views**: Plain HTML with shortcodes (e.g., `<table><tr><td>[field_key]</td></tr></table>`)
- **Layout Views**: JSON array of boxes (advanced; for grid/card layouts)
- Each entry repeats the template content

**Required postmeta keys** (all set automatically by `create-view`; listed here for read-only debugging):
- `frm_form_id` — Form ID (view's datasource; without it the view editor shows "No form is selected")
- `frm_form` — Form ID (admin views-list link; without it the view doesn't appear at `/wp-admin/edit.php?post_type=frm_display&form=X`)
- `frm_show_count` — "all" or specific count
- `frm_options` — Serialized array of view options (grid settings, field configs, etc.)
- `frm_grid_view` — 0 for classic, 1 for grid layout
- `frm_param` — "entry" (standard value)
- `frm_type` — "id" (standard value)
- `frm_active_preview_filter` — "limited" (standard value)
- `frm_dyncontent` — empty string

**Linking to Application:**
- Use `add-item-to-application` with `item_type: "view"` — internally it adds a `wp_term_relationships` row with `object_id: VIEW_POST_ID` and the application term's `term_taxonomy_id` (know this only for read-only debugging)

### View Content Structure: Classic vs Layout

**CRITICAL:** Formidable has two fundamentally different view architectures. Using the wrong one causes content to repeat when it shouldn't.

#### Classic View (frm_grid_view: 0) — For Filtered Data & Tables

**Use classic views when:**
- Showing a filtered list of entries (e.g., game filter shows only matching scores)
- You need header/footer that appears once, rows that repeat
- You want simple HTML template with shortcodes

**Structure** (storage, for read-only debugging):
1. `post_content` — Row template ONLY (plain HTML with [field_key] shortcodes)
2. `frm_before_content` postmeta — Header section (filter, table open tag, column headers)
3. `frm_listing_content` postmeta — Row template (the repeating content per entry)
4. `frm_after_content` postmeta — Footer section (table close tag, footer text)

**Rendering order:**
1. `frm_before_content` renders ONCE at the start
2. `frm_listing_content` repeats for EACH matching entry
3. `frm_after_content` renders ONCE at the end

Set this structure with the `content` (row template), `before_content`, and `after_content` parameters of `create-view`/`update-view`. Before/after content is written to both the `frm_before_content`/`frm_after_content` postmeta and the matching `frm_options` keys automatically.

**Example - Filtered Leaderboard** (`create-view` parameters — the `options` filter arrays do the filtering at query level):
```json
{
  "form_id": "362",
  "name": "Leaderboard",
  "content": "<tr><td>[player]</td><td>[score]</td></tr>",
  "before_content": "<table><thead><tr><th>Player</th><th>Score</th></tr></thead><tbody>",
  "after_content": "</tbody></table>",
  "options": {
    "where": [13104],
    "where_is": ["="],
    "where_val": ["[get param=\"game\"]"],
    "where_or": [0]
  }
}
```

(`update-view` accepts the same parameters plus `id`.)

#### Layout View (frm_grid_view: 1) — For Card/Grid Layouts

**Use layout views when:**
- Displaying entries as individual cards in a grid (e.g., product showcase)
- Each entry should be visually distinct in its own box
- You want flexible column layouts

**Structure:**
- `post_content` — JSON array of boxes
- Box 0 = before (appears once, but also counts toward box repeating)
- Box 1 = main content (repeats for each entry)
- Box 2+ = additional sections (also repeat)

**CAVEAT:** In layout views, ALL boxes repeat for each entry. There's no true "before/after" that appears once. Use classic views if you need that.

**Do NOT use layout views for:**
- Data with single header/footer that should appear once
- Tables where you need a header row appearing once
- Filtered data where repeating the header for each row is wrong

#### Summary Decision Tree

```
Is the view showing multiple entries in a list/table?
├─ YES: Use CLASSIC view (frm_grid_view: 0) with content + before_content/after_content
│   └─ (stored as frm_listing_content, frm_before_content, frm_after_content postmeta)
├─ NO: Showing as individual cards/grid?
│   └─ Use LAYOUT view (frm_grid_view: 1) with JSON boxes
└─ WRONG: Using layout view for a table? → Header repeats 39 times!
```

## Example: High Scores Arcade Application

**Complete workflow to create a high scores leaderboard — MCP abilities only (each line is one `mcp-adapter-execute-ability` call):**

```text
1. formidable-forms/create-form
   {"name": "High Scores", "description": "Arcade game leaderboard"}          → FORM_ID

2. formidable-forms/create-field (three calls)
   {"form_id": "FORM_ID", "type": "text",   "name": "Game",   "field_order": 1}
   {"form_id": "FORM_ID", "type": "name",   "name": "Player", "field_order": 2}
   {"form_id": "FORM_ID", "type": "number", "name": "Score",  "field_order": 3}

3. formidable-forms/update-field (submit button to last position)
   {"id": "SUBMIT_FIELD_ID", "field_order": 4}

4. formidable-forms/list-fields → field keys for shortcodes (e.g. game2, player2, score2)

5. formidable-forms/create-view (one call — post + ALL postmeta created automatically)
   {"form_id": FORM_ID, "name": "Top 10 Scores", "limit": 10,
    "content": "<table style=\"width:100%; border-collapse:collapse;\"><thead><tr style=\"background:#FF006E; color:#000;\"><th>Game</th><th>Player</th><th>Score</th></tr></thead><tbody><tr style=\"background:#1a1a1a; color:#00F5FF;\"><td>[game2]</td><td>[player2]</td><td>[score2]</td></tr></tbody></table>"}
   → VIEW_ID

6. formidable-forms/create-application
   {"name": "High Scores", "description": "Arcade game leaderboard"}          → APP_ID

7. formidable-forms/add-item-to-application (form)
   {"application_id": APP_ID, "item_id": FORM_ID, "item_type": "form"}

8. formidable-forms/add-item-to-application (view)
   {"application_id": APP_ID, "item_id": VIEW_ID, "item_type": "view"}

9. formidable-forms/list-application-items (verify)
   {"application_id": APP_ID}
   → items should contain the form and the view

10. formidable-forms/create-entry (repeat for each sample score)
    {"form_id": "FORM_ID", "FIELD_ID_1": "Pac-Man", "FIELD_ID_2": "Player Name", "FIELD_ID_3": "9999999"}
```

Then verify visually in a browser (Playwright) on the applications page.

## View Templates and Shortcodes

Views display form entries using HTML templates with field shortcodes. Formidable supports 6 view types and extensive shortcode options for displaying, filtering, and aggregating entry data.

### Important: JSON Encoding for layout-view content

Layout-view JSON box content is passed as the `content` string parameter of `create-view`/`update-view`. When building that string, **always escape properly (e.g., `json_encode()` with proper flags):**

```php
// ✗ WRONG - Hand-built string breaks JSON with unescaped quotes
$content = '[{"box":0,"content":"<div style="color: red;">...</div>"}]';

// ✓ RIGHT - Properly escaped HTML
$boxes = [
    ['box' => 0, 'content' => '<div style="color: red;">content</div>']
];
$content = json_encode($boxes, JSON_UNESCAPED_SLASHES);

// Verify JSON is valid before passing it as the content parameter
if (json_last_error() !== JSON_ERROR_NONE) {
    echo "JSON Error: " . json_last_error_msg();
    return;
}
// Then: update-view {"id": VIEW_ID, "content": $content}
```

**Why this matters:** HTML with quotes breaks JSON syntax. `json_encode()` handles escaping automatically. Always verify the JSON parses correctly before passing it as `content`.

### View Types

- **Classic View** — Simple bulleted/numbered list display
- **Table View** — Structured columns with sorting capabilities
- **Grid View** — Card-based layout with images and custom HTML
- **Calendar View** — Date-based visualization with event popups
- **Map View** — Location-based display (requires Geolocation add-on)
- **Timeline View** — Chronological organization with visual markers

### Getting Field Keys for View Shortcodes

**CRITICAL:** View templates use field keys (NOT field names) in shortcodes.

Get field keys with the `formidable-forms/list-fields` ability (pass the form ID) — each field's `field_key` is what goes in the shortcode.

**Example:** If your form has fields:
- "Story Category" → field_key: `lwrli` → use `[lwrli]` in view
- "Character Name" → field_key: `v8lk9` → use `[v8lk9]` in view
- "Generated Story" → field_key: `generatedstory` → use `[generatedstory]` in view

**WRONG (field names - won't work):**
```html
[story_category] [character_name] [generated_story]  ✗ INCORRECT
```

**RIGHT (field keys - required):**
```html
[lwrli] [v8lk9] [generatedstory]  ✓ CORRECT
```

### Shortcode syntax: see `shortcodes.md` (canonical)

All shortcode syntax used inside view content — field display/formatting parameters, date/number formatting, `[if]` conditionals, `[foreach]`, `[frm-stats]`/`[frm-math]`/`[frm-graph]`, `[frm-search]`/`[frm-letter-filter]`, `[get param]`, `[editlink]`/`[deletelink]`/`[detaillink]`, and `[display-frm-data]` publishing parameters — is documented ONLY in `shortcodes.md`. Read it; do not work from memory.

A divergent copy of that material previously lived here and contained wrong parameter names (`show_label=`, `is_link=`, `html=`, `format="currency"`, `type="bar"`, `type="donut"`, `[frm-stats type=sum]`, `[if ... is_blank]`, `[frm-search id= param=]`, `[entry_date]`). It was removed deliberately — the canonical forms are `show="field_label"`, `clickable=1`, `striphtml=1`, `decimal=`, `type="hbar"`, `pie_hole=`, `type=total`, `is_blank`→use `equals=""`-style operators from shortcodes.md §3, `[frm-search post_id=]`, `[created_at format=]`.

### View Configuration Options

When creating or editing a view in Formidable:
- **View Type** — Choose from 6 available types
- **Display Columns** — Select which fields to show
- **Pagination** — Set page size (50 or less recommended)
- **Limit** — Total entries displayed
- **Offset** — Skip first N entries
- **Sort Field** — Primary sort column
- **Sort Order** — Ascending or Descending
- **Filters** — Add conditions: contains, equals, greater than, less than, etc.
- **Detail Page** — Link to full entry view
- **Responsive Design** — Mobile-friendly layouts

## Troubleshooting

### Field Recreation and Entry Data Mismatch

**Problem:** After recreating form fields with FrmField::create(), view shortcodes show empty values or literal shortcode text.

**Root Cause:** When fields are deleted and recreated:
- Old field IDs still exist in `wp_frm_item_metas` (entry data)
- New fields get new IDs
- View templates reference new field keys, but entries have data in old field IDs
- Shortcodes fail to resolve because the referenced fields have no data

**Solution:** Don't repair the orphaned rows in place — recreate the entries through MCP so validation, serialization, and cache clearing all run:

1. `list-entries` on the form and read the surviving values out of each entry's response.
2. `create-entry` for each one, keying the values by the **new** field IDs.
3. `delete-entry` on the stale originals once the replacements verify.

**Better still, prevent it:** don't delete and recreate fields on a form that already has entries. Rename or reconfigure the existing field with `update-field` instead — the field ID stays stable and the entry data keeps resolving.

### View Shortcodes Not Processing

**Problem:** View templates show literal shortcode text like `[field_key]` instead of field values.

**Root Cause:**
- Field doesn't exist (deleted during field recreation)
- Field has no data for this entry
- Shortcode is in wrong format or references wrong field ID/key

**Solution:**
1. Verify the field exists — `list-fields` on the form
2. Verify the entry has data for it — `get-entry` on the entry ID
3. Use field KEYS (not names) in shortcodes: `[field_key]` not `[field_name]`
4. For conditional filtering, use: `[if field_key equals="value"]CONTENT[/if field_key]`

### Massive Spacing Gaps in Views

**Problem:** Large vertical gaps between view sections (2000px+) when using conditional shortcodes.

**Root Cause:** WordPress's autop (automatic paragraph) filter wraps unprocessed shortcodes in `<p>` tags. When `[if]` conditions don't match, the entire shortcode outputs as literal text, wrapped in `<p>` tags, creating huge spacing.

**Solution:**
- Remove unmatched `[if]` shortcodes from listing templates temporarily to verify data displays
- Then add conditional filters back, ensuring shortcodes are processed correctly (not showing as literal text)
- If gap persists after adding conditionals back, reduce form styling (margins, padding, line-height) with aggressive CSS:
  ```css
  .frm_form_field { margin: 0 !important; padding: 0 !important; min-height: 0 !important; line-height: 1 !important; }
  form.formidable_form { margin: 0 !important; padding: 0 !important; }
  ```

### View Content Structure

**Problem:** Unsure how view content is structured.

**Solution:**
- **Classic views (frm_grid_view: 0)** — pass the row template as `content` and once-only sections as `before_content`/`after_content`; storage is:
  - `frm_before_content` — Header/form, rendered once
  - `frm_listing_content` — Entry row template, repeated per entry
  - `frm_after_content` — Footer, rendered once
- **Layout views (frm_grid_view: 1)** — pass a JSON box array string as `content`
- `create-view`/`update-view` keep post_content, the postmeta keys, and the matching `frm_options` keys in sync
- Caches are handled by the API; hard-refresh the browser if the output looks stale

### View Filtering: Avoid Template Conditionals

**Problem:** Using `[if field equals="[get param]"]` in the row template creates spacing issues and is inefficient.

**Solution:** Pass filter arrays in the `options` parameter of `create-view`/`update-view` (merged into `frm_options`):
```json
{
  "id": "VIEW_ID",
  "options": {
    "where": [13104],
    "where_is": ["="],
    "where_val": ["[get param=\"game\"]"],
    "where_or": [0]
  }
}
```

This approach:
- Filters at query level (faster, cleaner)
- Doesn't create empty `<p>` tags or spacing gaps
- Keeps templates simple and readable
- Properly handles [get param] shortcodes in where_val

### URL Parameter Filtering

**Problem:** Need to filter view entries by URL parameter (e.g., `?game=Pac-Man`).

**Solution:** Use filter rules via the `options` parameter of `create-view`/`update-view` instead of template conditionals — the object is merged into the view's `frm_options`:

```json
{
  "id": "VIEW_ID",
  "options": {
    "where": [13104],
    "where_is": ["="],
    "where_val": ["[get param=\"game\"]"],
    "where_or": [0]
  }
}
```

**Key points:**
- `where` — array of field IDs to filter on
- `where_is` — array of operators, one per where field ("=", "LIKE%", ">", "<", etc.)
- `where_val` — array of values (can include [get param='key'] shortcodes)
- `where_or` — array of 0/1 values (0=AND, 1=OR between rules)
- All arrays must have matching lengths

For dropdown pre-selection without filtering, use JavaScript:
```javascript
const gameParam = new URLSearchParams(window.location.search).get("game");
if (gameParam) {
  const decodedGame = decodeURIComponent(gameParam.replace(/\+/g, " "));
  const select = document.getElementById("field_game_select");
  if (select) {
    select.value = decodedGame;
  }
}
```

**DO NOT use** `[if field equals="[get param]"]` in templates — use proper filter rules instead for cleaner, more performant filtering.

## Important Notes

- **Always use MCP**: All form/field/entry/view/application operations via MCP abilities — never wp-cli or direct database writes
- **Applications**: `create-application` → `add-item-to-application` (form, then view) → verify with `list-application-items`
- **Views**: One `create-view` call creates the post and all required postmeta; never `wp post create`
- **Post type critical**: Views MUST be `post_type: frm_display`, not `frm_views` (`create-view` guarantees this)
- **View content structure**:
  - **Classic views (frm_grid_view: 0)** use `content` (row template) plus `before_content`/`after_content` (rendered once; stored as `frm_before_content`, `frm_listing_content`, `frm_after_content` postmeta)
  - **Layout views (frm_grid_view: 1)** use a JSON box array as `content` (all boxes repeat per entry)
  - Do NOT mix approaches; do NOT use layout views for tables with single headers
- **Form ordering**: Submit button must have highest `field_order`
- **Metadata required**: Applications won't display without proper metadata; the application abilities manage it — don't set termmeta by hand
- **View metadata required**: All postmeta keys must be set for views to work correctly (`create-view` handles this; `update-view` backfills missing `frm_form`)
- **JSON encoding**: When building layout-view `content` JSON with HTML inside, use `json_encode($data, JSON_UNESCAPED_SLASHES)` and verify it parses before passing it
- **Verification**: Verify pages visually in a browser (e.g., Playwright), not with curl
  - Always verify the actual output by visiting the URL in a browser
  - Do NOT assume code is correct without visual verification
  - Check: filter links appear once (not repeated per entry), header/footer appear once, rows repeat with correct data
  - Log in first: navigate to wp-login.php, fill form, wait for navigation
  - Then check the applications page and the form's views page
