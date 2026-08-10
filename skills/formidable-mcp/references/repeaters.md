# Repeaters & Nested Forms

Read this when: creating, debugging, or verifying repeatable sections (repeaters) or nested forms in Formidable — the most error-prone area of form building via MCP.

## Anatomy of a Repeater

A repeatable field group requires FOUR components, in this order:

### 0. Child form (ALWAYS required)
- Create a separate form to define/anchor the repeatable structure.
- Formidable uses it to render the nested-form interface and add/remove buttons. Without it, buttons won't render properly and the editor icon breaks.
- **Create it with `parent_form_id` set in the same call** — `create-form` accepts and persists `parent_form_id` (e.g. `{"name": "Repeater Items", "parent_form_id": 362}`). For an existing child form missing the link, fix it with `update-form` (`{"id": <child_id>, "parent_form_id": <parent_id>}`; `0` detaches). Never set it via SQL/wp-cli.

### 1. Divider field (start marker) — in the PARENT form
- Type: `divider`
- Required `field_options`:
  - `"repeat": "1"` — enables repeating behavior (`"0"` = plain non-repeating section)
  - `"form_select": "<child_form_id>"` — CRITICAL, must NEVER be empty (see Critical Rule)

### 2. Repeater fields
- Every repeater field must have `"in_section": <divider_id>` in its `field_options`.
- Which form they live in depends on the pattern (see Two Patterns below).
- Fields should be consecutive in `field_order` (no gaps, no unrelated fields between them).
- Can be any type (text, checkbox, textarea, etc.).
- Always copy FULL default `field_options` (the complete default key set — typically 18 keys for simple fields: size, max, label, blank, required_indicator, invalid, unique_msg, separate_value, clear_on_focus, classes, custom_html, minnum, maxnum, step, format, placeholder, draft — plus `in_section`; template fields can have 71+ keys). Partial field_options cause rendering corruption.

### 3. End divider field (end marker + buttons) — in the PARENT form
- Type: `end_divider`
- Placed immediately after the last repeater field (`field_order` just above it).
- `field_options` should include `"add_label": "Add"` and `"remove_label": "Remove"` (or custom labels).
- Its own `in_section` is `"0"` — it is not inside the repeater itself.
- Renders hidden markup; JavaScript (formidablepro.js) turns it into the add/remove buttons.
- Note: if `create-field` rejects the `end_divider` type, check the formidable-api plugin's ability validator (`FrmAPIAbilitiesController.php`) — `end_divider` must appear in its allowed field-type enums.

## CRITICAL RULE: form_select Must ALWAYS Be Set

**`form_select` MUST always be set to a child form ID, on every repeater divider, in every pattern — even for the simplest repeater.**

The plugin decides the editor icon (and recognizes the repeater) like this:

```php
$icon_class = ! empty( $field['form_select'] ) ? 'frm_repeat_icon' : 'frm-form-title-style';
```

- `form_select` set → repeater icon (⟳), plugin recognizes the repeater structure
- `form_select` empty → header icon ("H"), broken repeater behavior

> **Anti-pattern (do NOT do this):** Leaving `form_select` as `""` on a repeater divider — even for simple repeaters where `in_section` alone groups the fields. An empty `form_select` produces the "H" header icon and broken editor behavior. Always create a child form (even an empty one) purely so `form_select` has something to point to.

## The Two Repeater Patterns

Both patterns require a child form and `form_select`. The only difference is **where the repeater fields are stored**.

| | Pattern 1: Nested Forms | Pattern 2: Direct Parent |
|---|---|---|
| Use when | Complex repeaters, many fields, reusable sub-forms | Simple field groups, few fields, no reuse |
| Child form | Contains the repeater fields | Empty — exists only as the `form_select` reference |
| Repeater fields live in | CHILD form, with `in_section: <divider_id>` | PARENT form, with `in_section: <divider_id>` |
| Divider `form_select` | Child form ID (required) | Child form ID (required — empty is the anti-pattern) |
| Editor visibility | Fields appear in child form editor (nested under divider in parent editor once `parent_form_id` is set) | Fields appear directly in parent editor, indented under divider |

**Key insight:** `in_section` is what groups fields under a divider — it works whether the field row is stored in the parent or child form. `form_select` is what enables the nested-forms rendering interface and the repeater icon. You need both configured correctly.

Choose before building: "Is this a simple flat group of fields, or a complex/reusable nested structure?" Simple → Direct Parent. Complex → Nested Forms.

## Step-by-Step: Pattern 1 — Nested Forms Repeater

Use MCP abilities for all creates/updates, and MCP reads (e.g. `get-form`) for verification.

```bash
# 1. Create the child form WITH the parent link in ONE call
#    ability: formidable-forms/create-form
#    parameters: {"name": "Repeater Items", "parent_form_id": 1492}
#    -> returns child_form_id (e.g. 1495); parent_form_id is persisted directly
#
#    For an EXISTING child form missing the link, use update-form:
#    ability: formidable-forms/update-form
#    parameters: {"id": 1495, "parent_form_id": 1492}

# 2. Create the divider in the PARENT form
#    ability: formidable-forms/create-field
#    parameters: {
#      "form_id": "1492",
#      "type": "divider",
#      "name": "Items Section",
#      "field_options": {"repeat": "1", "form_select": "1495"},
#      "field_order": 10
#    }
#    -> returns divider_id (e.g. 12919)

# 3. Create each repeater field in the CHILD form
#    ability: formidable-forms/create-field
#    parameters: {
#      "form_id": "1495",                 // CHILD form
#      "type": "text",
#      "name": "Item Name",
#      "field_options": {"in_section": 12919, ...full default field_options},
#      "field_order": 1
#    }

# 4. Create the end_divider in the PARENT form
#    ability: formidable-forms/create-field
#    parameters: {
#      "form_id": "1492",
#      "type": "end_divider",
#      "name": "Section Buttons",
#      "field_options": {"add_label": "Add", "remove_label": "Remove", ...},
#      "field_order": 11                  // right after the divider/fields
#    }

# 5. Done — MCP field operations clear form caches automatically.
#    If the editor looks stale, hard-refresh the browser (Cmd+Shift+R).
```

## Step-by-Step: Pattern 2 — Direct Parent Repeater

```bash
# 1. Create an EMPTY child form (exists only for the form_select reference!)
#    with the parent link in the SAME call:
#    ability: formidable-forms/create-form
#    parameters: {"name": "Simple Repeater", "parent_form_id": 1492}
#    -> returns child_form_id (e.g. 1505)
#    (Existing child form missing the link? formidable-forms/update-form
#     {"id": 1505, "parent_form_id": 1492})

# 2. Create the divider in the parent form — form_select MUST still be set!
#    parameters: {
#      "form_id": "1492",
#      "type": "divider",
#      "name": "Radio Options",
#      "field_options": {"repeat": "1", "form_select": "1505"},
#      "field_order": 54
#    }
#    -> returns divider_id (e.g. 13020)

# 3. Create the repeater fields in the PARENT form (not the child!)
#    parameters: {
#      "form_id": "1492",                 // PARENT form
#      "type": "checkbox",
#      "name": "North",
#      "field_options": {"in_section": 13020, ...full default field_options},
#      "field_order": 56
#    }
#    (repeat for each field; keep orders consecutive between divider and end_divider)

# 4. Create the end_divider in the parent form
#    parameters: {
#      "form_id": "1492",
#      "type": "end_divider",
#      "field_options": {"add_label": "Add", "remove_label": "Remove", ...},
#      "field_order": 58
#    }

# 5. Done — MCP field operations clear form caches automatically.
#    If the editor looks stale, hard-refresh the browser (Cmd+Shift+R).
```

## Requirements Common to Both Patterns

1. **Child form creation** — always create a child form.
2. **parent_form_id** — always set it by passing `parent_form_id` to `create-form` when creating the child form (or `update-form` for an existing child form; never via SQL/wp-cli). When set, child fields appear nested/indented under the divider in the parent form editor, and Formidable recognizes the parent/child relationship. Refresh the editor after setting it. Verify with MCP `get-form`, which returns `parent_form_id`.
3. **form_select on the divider** — always set to the child form ID.
4. **in_section on every repeater field** — set to the divider's field ID.
5. **end_divider** — always create it, with `add_label` and `remove_label`.
6. **Cache clearing** — automatic for all MCP create/update/delete operations. If the editor shows stale data, hard-refresh the browser first; a manual flush is a last-resort local troubleshooting step only (see the cache notes in forms-and-fields.md).
7. **Field ordering** — divider, then repeater fields (consecutive), then end_divider immediately after; no duplicate `field_order` values; no unrelated fields caught between the divider and end_divider.
8. **Serialization** — `field_options` is stored PHP-serialized (e.g. `a:18:{...}`) in `wp_frm_fields.field_options`. If you write to the database directly, JSON-encoded field_options are corrupted and break rendering; MCP abilities handle serialization correctly, which is another reason to use MCP for all writes.

## Worked Example (Parent Form 1492)

A parent form combining regular fields, two nested-forms repeaters, lookup/data fields, and a submit button — verified working on both backend and frontend:

```
Order | ID    | Type         | Name                   | in_section | field_options highlights
------|-------|--------------|------------------------|------------|--------------------------
1-7   | ...   | text/etc.    | Regular fields         | 0          | -
8     | 12919 | divider      | First Repeater Section | 0          | repeat: "1", form_select: "1495"
      | 12925 | text         | First input            | 12919      | (stored in child form 1495)
      | 12926 | text         | Second input           | 12919      | (stored in child form 1495)
      | 12927 | text         | Third input            | 12919      | (stored in child form 1495)
12    | 12924 | end_divider  | Section Buttons        | 0          | add_label, remove_label
14    | 12928 | divider      | Details Section        | 0          | repeat: "1", form_select: "1496"
      | 12933 | text         | Text                   | 12928      | (stored in child form 1496)
      | 12934 | textarea     | Textarea               | 12928      | (stored in child form 1496)
17    | 12931 | end_divider  | Details Buttons        | 0          | add_label, remove_label
18    | 12936 | data         | Animal Dynamic         | 0          | outside repeaters
19    | 12935 | lookup       | Animal Lookup          | 0          | outside repeaters
20    | 12910 | submit       | Submit                 | 0          | last
```

Child forms:
- Form 1495 (parent_form_id: 1492) — 3 text fields, each `in_section: 12919`
- Form 1496 (parent_form_id: 1492) — 2 fields, each `in_section: 12928`

A Direct Parent example from the same form: a "Directions" repeater whose divider has `repeat: "1"` plus `form_select` pointing to an empty child form, with four individual checkbox fields (North/South/East/West, each a separate field with `in_section: <divider_id>`, each with a "Yes" option) stored directly in form 1492, closed by an end_divider with Add/Remove labels.

Placement notes from this example:
- Lookup/data fields go AFTER (outside) all repeater sections — never between a divider and its end_divider, or they get swallowed into the repeater.
- Each repeatable checkbox is its own field; do not model a repeating group as one multi-option field.

### Expected behavior when correct

**Parent form editor** (`/wp-admin/admin.php?page=formidable&frm_action=edit&id=<parent_id>`):
- Shows regular fields, dividers (with the ⟳ repeater icon, NOT the "H" header icon), end_dividers, and — for Direct Parent repeaters — the repeater fields indented under their divider.
- Nested-forms child fields appear in the CHILD form editor; with `parent_form_id` set they also display nested under the divider in the parent editor. Not seeing child fields listed as top-level parent fields is correct.

**Frontend** (`/wp-admin/admin-ajax.php?action=frm_forms_preview&form=<form_key>` on https://your-site.local):
- Each repeater section renders as a repeating row of its fields.
- Repeater fields carry `data-sectionid="<divider_id>"` attributes.
- Add/remove buttons render (via the end_divider + formidablepro.js).
- The nested forms controller (`display_front_end_repeating_section`) handles rendering.

## Common Mistakes / Anti-Patterns

Each of these breaks the repeater structure:

1. **Empty `form_select` on the divider** — the biggest one. Produces the "H" header icon instead of the repeater icon and breaks repeater recognition. `form_select` must always point to a child form ID.
2. **Creating a repeater without a child form** — buttons and the nested interface won't render.
3. **Forgetting `parent_form_id` on the child form** — child fields won't nest under the divider in the parent editor; Formidable doesn't associate the forms. Fix: pass `parent_form_id` on `create-form`, or repair existing forms with `update-form`.
4. **Missing `in_section` on repeater fields** — fields don't group under the divider.
5. **Fields in the wrong form for the pattern** — e.g., putting Direct Parent fields into the child form, or duplicating nested-pattern fields into the parent (fields defined in the child AND given `in_section` copies in the parent appear twice — inside and outside the repeater).
6. **Missing end_divider (or missing add_label/remove_label)** — no add/remove buttons.
7. **Partial `field_options`** — always copy the full default option set (18 keys for basic fields; 71+ for template-derived fields) plus `in_section`. Partial or JSON-instead-of-PHP-serialized options corrupt rendering.
8. **Debugging stale output** — MCP operations clear caches automatically; if output looks stale, hard-refresh the browser before suspecting the data. Manual cache flushing is a last-resort local troubleshooting step, never part of the workflow.
9. **Assuming every repeater needs the nested-forms pattern** — simple flat groups belong in the parent (Direct Parent pattern); creating unnecessary child forms with fields complicates structure and debugging.
10. **Blaming field_options corruption for structural problems** — when fields render in the wrong place, first verify the architecture (form_select, in_section, parent_form_id, field ordering) before suspecting data corruption.

### Failure-mode reference (broken state, what NOT to leave behind)

A broken parent form structure looks like this:

```
Order 1:  divider 13002       <- orphaned divider at the top, no fields inside
Order 4:  end_divider 13003   <- orphaned end_divider, AND duplicate order value
Order 4:  text 12911          <- duplicate field_order "4" (rendering issues)
...
Order 39: divider 13014       <- "Directions" repeater divider
Order 40: end_divider 13015   <- immediately follows divider with NO fields between them
```

Symptoms: repeater "not showing correctly" on the frontend. Root causes to check in this situation:
- Orphaned divider/end_divider pairs with no fields between them (leftovers from failed attempts) — delete them.
- Duplicate `field_order` values — renumber so ordering is unambiguous.
- Divider/end_divider pairs that contain zero fields because the fields were never given `in_section`, or were created in the wrong form.
- Missing or empty `form_select` / `repeat` on the divider.

The fix is restructuring to the two valid patterns above (fields with `in_section` between divider and end_divider, `form_select` set, orphans removed).

## Displaying Repeater Rows in Views: Use a parent_item_id-Filtered Nested View, NOT [foreach]

**For application templates (anything meant to be exported/imported), never render repeater rows with `[foreach DIVIDER]` — use a nested child-form view filtered by `parent_item_id` instead.**

Why (confirmed via live import reproduction): a parent entry stores its repeater rows two ways — (a) the relational `parent_item_id` column on each child entry, and (b) a cached array of child entry IDs in the parent's own item_meta for the divider field. `[foreach]` renders from (b). On XML import, Formidable's entry importer repairs (a) correctly (`FrmProXMLHelper::update_parent_item_ids`) but **never remaps (b)** — `FrmFieldType::get_import_value` is a no-op and no field type overrides it — so whenever imported entry IDs differ from source IDs (i.e., any target site with existing entries), `[foreach]` renders nothing while the child rows actually exist. The cached array can also silently drift on the source site; the relational link is always authoritative.

The import-proof pattern (no code, no JS — Views natively support `parent_item_id` as a where-filter field, see `FrmViewsDisplay.php`):

1. Create a small classic view on the CHILD form rendering one row, filtered by parent:
   - content: `<div class="row"><span>[child_field_key]</span>...</div>` (field KEYS)
   - options: `{"where": ["parent_item_id"], "where_is": ["="], "where_val": ["[get param=workout]"], "empty_msg": ""}` (empty `empty_msg` so rowless parents don't print "No Entries Found")
2. Embed it in the parent view's per-entry content, passing the current entry ID as the param:
   `[display-frm-data id=<child-view-slug> filter=limited workout="[id]"]`
3. Don't wrap the embed in `<table>`/`<tbody>` — the nested view emits wrapper divs that browsers hoist out of tables. Use CSS-grid rows (`display:grid; grid-template-columns:...`) for tabular layout instead.
4. Add the child view to the application so it exports with everything else.

`[foreach]` remains fine for email bodies (rendered on the source site where the cached IDs are valid) and for single-site views that will never be exported.

## Writing Entry Data for Repeaters (create-entry / update-entry)

The divider takes either its numeric field ID or its field key, like any other entry field. **What actually matters is the ROW keys**, and the API now normalizes them for you:

```json
{
  "item_meta": {
    "<divider_id_or_key>": {
      "form": "<child_form_id>",
      "i0": { "<child_field_id_or_key>": "<value>" },
      "i1": { "<child_field_id_or_key>": "<value>" }
    }
  }
}
```

- **Row keys are `i0`, `i1`, `i2`, …** (plain digits also work). Pro decides whether any rows were submitted by matching each row key against `/^i?\d+$/` in `FrmProEntryMeta::matches_repeater_index_regex()`. A key outside that pattern used to look like "no rows submitted", so validation discarded the rows, substituted one blank row, and the entry saved with an empty repeater and no error. `create-entry`/`update-entry` now renumber non-conforming row keys, so `"row1"` or `"first"` works — but write `i0`/`i1` anyway, since that is what the data looks like when you read it back.
- **`form` must be the child form ID.** It is filled in automatically from the divider's `form_select` when omitted.
- **Child field values inside a row take the field ID or field key**; keys are mapped to IDs before validation.
- **On update, `i<child_entry_id>` edits that existing row in place** (`i109245` updates child entry 109245); any other key creates a new row, and rows you leave out are deleted. This is why keys already matching the pattern are never renumbered.
- **A row whose values are all empty is skipped**, not saved as a blank child entry. A row missing a *required* child field is a validation error naming that row (`field13769-13767-i1`), and the whole write is rejected with nothing partially saved. A required field inside a repeater therefore makes at least one row mandatory.
- **`repeat_limit` silently drops the extra rows** rather than erroring — send at most that many.
- An earlier version of this file claimed the divider's numeric ID "silently saves no rows" and that the field key was required. That was a misattribution — the failing variable was the row key (`r1`), not the divider reference. Verified: the numeric divider ID with `i0`/`i1` rows saves correctly.

Still re-read a repeater write with `get-entry` and confirm the rows came back — it is the only way to catch a row that was dropped for being empty.

## Keys in CONTENT, Numeric IDs in SETTINGS

There is no blanket "always prefer keys" rule. The right choice depends on where the reference lives, and getting it wrong usually fails **silently**.

### Settings take numeric field IDs — never keys

Any stored setting that holds a field reference expects the numeric ID. Most are guarded by `is_numeric()`, so a field key isn't rejected with an error — the setting is just skipped. Verified live: a text field with `hide_field: ["13760"]` renders `display: none` and its conditional logic works, while the identical field with `hide_field: ["show-extra"]` renders `display: block` — the rule was dropped and the field is permanently visible.

Send numeric IDs in at least these:
- **Field conditional logic** — `hide_field` (with `hide_field_cond`, `hide_opt`)
- **Calculations and default values** — `field_options.calc`, `default_value`: `[457]+[458]`
- **Repeater / embedded form / section wiring** — `form_select`, `in_section`
- **Dynamic and lookup fields** — `get_values_field`, `watch_lookup`
- **View options** — `order_by`, `where`, `date_field_id`, `edate_field_id`, `map_address_fields`, `calendar_options`, `timeline_options`
- **Form action settings** — quiz `enable` and each `quiz` entry's `id`, wppost `post_title`/`post_content` mappings

**Numeric IDs in settings are import-safe, so portability is not a reason to avoid them.** Formidable's importer rewrites them against its `$frm_duplicate_ids` map: `FrmProField::duplicate()` covers `calc`, `default_value`, `hide_field`, `form_select`, `in_section` and lookup settings; `FrmFormAction::duplicate_one()` covers action `post_content` including add-on array settings declared via `get_switch_fields()`; and `FrmXMLHelper::populate_postmeta()` covers the view options listed above. This is exactly why these settings store IDs in the first place.

### Content takes keys — they read better and are stable

In rendered content, a field reference is a shortcode, and both forms work. Prefer the key: it says what it points at, and it survives content that gets hand-copied between sites rather than going through the importer.

- `[formidable id=x]` — `x` = form ID **or** form key
- `[display-frm-data id=x]` — `x` = View ID **or** View key/slug
- Field-value shortcodes `[x]` in View/email/confirmation content — `x` = field ID **or** field key. Field **names** silently output blank; don't confuse the two
- `[foreach REPEATER]` — accepts the divider's field key as well as its numeric ID (verified: `[foreach 5cf7q]` rendered identically to `[foreach 440]` on a real grid view with multi-row repeater data). The KB only documents the numeric form
- Entry `meta`/`item_meta` payloads on `create-entry`/`update-entry` — field ID or field key, id winning when both are given for one field

Note that the importer rewrites ID shortcodes in content too (`FrmFieldsHelper::switch_field_ids` runs over view content, `frm_dyncontent`, field descriptions, `success_msg`, and action content), so this is a readability preference, not a correctness one.

### Entry payloads accept either

Entry `meta`/`item_meta` takes field IDs or field keys at any level, including the repeater divider and its child fields (the id wins when both are given for one field). The only structural requirement is the repeater ROW key format covered above — that is about row identity, not about IDs versus keys.

Since field keys are now derived from field names, the readable form is what you get by default: a field named "Preferred Shift" gives you `[preferred-shift]` in content, while its conditional logic and calculations still reference the numeric ID.

## Verification

### Checklist (run after every repeater build)

- [ ] Child form created with `parent_form_id` set to the parent form ID (confirm via MCP `get-form` — it returns `parent_form_id`)
- [ ] Divider has `repeat: "1"`
- [ ] Divider has `form_select: <child_form_id>` (NOT empty!)
- [ ] All repeater fields have `in_section: <divider_id>`
- [ ] All repeater fields have complete field_options (full default key set)
- [ ] End_divider created with `add_label` and `remove_label`
- [ ] Field orders: divider → fields (consecutive) → end_divider; no duplicates; no unrelated fields between divider and end_divider
- [ ] Editor hard-refreshed if stale (MCP operations clear server-side caches automatically)
- [ ] Backend shows repeater icon (⟳), not header icon (H)
- [ ] Frontend shows add/remove buttons
- [ ] Fields display correctly inside the repeater section with `data-sectionid` attributes

### Preferred: MCP verification (reads)

- `formidable-forms/get-form` on the child form — returns `parent_form_id`; confirm it equals the parent form ID
- `formidable-forms/list-fields` on parent and child forms — check types, ordering, and `field_options` (`repeat`, `form_select`, `in_section`). Note: the response `data` is an OBJECT keyed by field_key, not an array.

### OPTIONAL: WP-CLI deep debugging

Use this ONLY when MCP reads aren't enough — reads only, and MCP for every write:

```bash
wp eval '
  $f = FrmField::getOne( <divider_id> );
  print_r( array(
    "repeat"      => $f->field_options["repeat"] ?? null,
    "form_select" => $f->field_options["form_select"] ?? null,
  ) );
'
```

Then verify visually (load the form editor and frontend preview in a browser) rather than asking the user to check.
