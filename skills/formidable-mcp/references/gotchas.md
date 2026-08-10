# Known Bugs & Gotchas

Read this when: an MCP ability call fails, silently does nothing, or returns empty results — check here for known symptoms before debugging from scratch.

## Active Bugs

When a new failure appears, record it here (symptom → cause → status) and prefer fixing it in the `formidable-api` plugin over documenting a workaround — workarounds that bypass the API (wp-cli writes, direct SQL) are not acceptable. Once a bug is fixed, don't archive it here: fold whatever behavior it clarified into the relevant reference file and delete the entry. The plugin is unreleased, so there are no old builds in the wild whose symptoms need recognizing.

- None currently.

## Standing Cautions

### Entries

- **XML entry import preserves the `<id>` from the file and can take over an existing entry row with that ID** (observed: a test import whose XML contained `<id>258</id>` absorbed the live entry occupying id 258). Never import an entries-containing XML into a site whose data you care about as a "test" — use a scratch site, or strip `<item>` blocks first.
- **Repeater display after import**: `[foreach]` reads the parent's cached child-ID array, which the importer never remaps — see `repeaters.md` "Displaying Repeater Rows in Views" for the import-proof `parent_item_id`-filtered nested-view pattern.
- **`create-entry` runs Formidable's duplicate-submission check** (`FrmEntry::is_duplicate`): a create identical to a recent entry fails with "It looks like you've already submitted that." To seed several identical test entries, create them with unique values first, then `update-entry` each to the target value (updates skip the check). Core's `frm_time_to_check_duplicates` filter can shorten the window if the API should ever allow duplicates.
- **Field values are top-level parameters or an `item_meta` object, keyed by field id or field key** (id wins when both are given for one field). A nested `values` object is rejected with a clear error. `create-entry` also accepts `is_draft`, `user_id`, and `created_at`; `update-field` accepts `type` (installed-types enum) and an optional `form_id` to move a field.
- **`list-entries` includes draft entries by default** (it is backed by the current `frm/v3` controllers). Pass `is_draft: 0` to get only submitted entries, or `is_draft: 1` for drafts only. Only the frozen legacy `frm/v2` REST namespace still excludes drafts unconditionally.
- **`number` fields silently cap at 9999999 (7 digits) by default.** A `create-entry` with a larger value fails with `field####: Please select a lower number` — Formidable's default `maxnum` field option, not an MCP limit. Raise it before seeding large values: `update-field {"id": "<field_id>", "field_options": {"minnum": "0", "maxnum": "999999999", "step": "1"}}`. Bites arcade-score / currency / population-style data where 8+ digits are normal.
- **Per-option selection limits apply to MCP entry writes too.** If a choice field's options carry a `limit` (max times each option can be chosen across entries), entry writes fail with `field####: The maximum number of times the following choices can be selected was reached: <option>` once the quota is used. This is form validation working as designed — pick a different option or raise the limit.

### Views

- **Map views render nothing on the frontend without the formidable-geo add-on active.** `create-view` with `type: map` succeeds and stores `map_address_fields` in `frm_options`, but the frontend map container and markers are injected by `FrmGeoMapViewController` hooks, and marker coordinates come from geo entry meta (geocoded at submission), not the raw address value. Without the geo plugin the page shows only the `<!-- FRM-VIEW ... -->` comment.
- **Timeline views reveal cards on scroll.** In a headless browser (or a full-page screenshot) only the first card looks visible; the rest are `opacity: 0` until scrolled into view. All cards are in the DOM — assert on the accessibility snapshot, not the screenshot.
- **A view filter whose `where_val` shortcode resolves to empty shows ALL entries.** `where_val: "[get param=x]"` with no `x` in the request drops the rule rather than matching zero rows, so a nested child view's own permalink leaks its whole form and `empty_msg` never fires. Set such views to `private`/`draft` (embedded rendering is unaffected).
- **Draft and private views still render wherever they are embedded** (shortcode, block, page). Those statuses only gate the standalone `/frm_display/<slug>/` permalink, where normal WordPress visibility applies (draft: 404 for visitors; private: viewable with `read_private_posts`).
- **`order_by` and `order` in a view's `options` are parallel ARRAYS, not strings** — one entry per sort rule, positionally paired: `{"order_by": ["created_at"], "order": ["DESC"]}`, or `{"order_by": ["13619", "13620"], "order": ["ASC_numeric", "ASC_numeric"]}` for a two-level sort. This is how the wp-admin sort UI stores them (`options[order_by][<n>]`) and what the query builder reads (`order_by_array`); a bare string is the wrong shape and historically corrupted the view. Applies to every view type — classic, table, grid, calendar — not just grid views. `order` values are `ASC`, `DESC`, `ASC_numeric`, or `DESC_numeric` (`_numeric` sorts a text-stored field as a number); `order_by` values are a numeric field ID, `created_at`, `updated_at`, `id`, `rand`, or a name/address subfield as `<field_id>_<part>`.
  - `create-view`/`update-view` coerce a plain string into a single-element array before saving, so `"order_by": "created_at"` is accepted and stored correctly. Still send arrays — the coercion cannot express a multi-level sort, and it is a safety net rather than the contract.
  - Send exactly as many `order` entries as `order_by` entries. The two are paired by index, so an unpaired rule has no order to read.
  - Always read the view back with `get-view` after writing sort options and confirm both came back as arrays of the length you sent.
- **Grid View content boxes do not need a `style` key.** `style` is optional and only stored when it holds something: the editor's own save path writes it solely under `if ( ! empty( $box_data['style'] ) )`, so an empty `"style": {}` you send is dropped the next time the view is saved from wp-admin. Boxes written as `{"box":0,"content":"..."}` render correctly on the front end and open normally in the builder with the "Grid Style Settings" panel fully populated (verified in the builder against a grid view whose boxes carry no `style` key at all). Send `style` only when setting real values such as `{"borderStyle":"none"}`.

### Forms & Applications

- **MCP-created forms/fields are equivalent to builder-created ones — don't "fix" the differences.** MCP forms omit the auto `submit` field the builder adds, and MCP fields store only the base default `field_options` (the builder's AJAX insert adds ~54 extra Pro keys). Both are benign: forms render a working submit button via the `submit_html` fallback, absent field_options resolve to defaults through `FrmField::get_option`, and opening the form in the builder self-heals both. Don't force-add the missing keys.
- **Draft forms are invisible inside applications.** `add-item-to-application` succeeds and writes the `_frm_form_id` termmeta, but `FrmProApplication::get_forms_for_application()` filters `status = 'published'`, so a draft form is missing from `list-application-items` and the card's form count. Publish the form and it appears — this is core Pro behavior, not an MCP bug.
- **`get-form` rendered HTML: the parameter is `return: "html"`** (a `format` param is silently ignored); the markup comes back in `data.renderedHtml` and includes the assigned style's `frm_style_*` class — useful for verifying style assignment without a browser.

### Form actions

- **`create-form-action` runs the action class's `update()` method, the same as `update-form-action` and the wp-admin save.** Add-on actions do real work there — the Quizzes actions call `FrmQuizzesField::maybe_add_score_field()` to auto-insert the hidden `quiz_score` field the form needs, and On Submit sanitizes its redirect URL. One `create-form-action` call is enough; the old advice to follow every add-on action with a no-op `update-form-action` no longer applies. Still `list-fields` afterwards to confirm what the action added.
- **Quiz field types cannot be created directly.** `quiz_score` and `quiz_timer` are rejected by the field-type enum on `create-form`/`create-field` (`input[fields][N][type] is not one of …`), and their builder buttons are `display: none` by design. You do not need them: creating the quiz action inserts the field for you.
- **Scored quizzes still work without a score field, outcomes don't.** Per-question scoring and "Correct answer: X" render from the action settings alone, but `maybe_set_outcome_to_item_meta()` returns early when the form has no `quiz_score` field, so quiz outcomes produce nothing on the frontend.
- See `templates.md` § "quiz (scored)" for the Formidable Quizzes add-on's `post_content` schema.

### Styles

- **Prefer `update-style` over delete-and-recreate** — forms reference styles by ID, so recreating breaks the assignment.
- **`submit_style` is INVERTED — it means "disable submit button styling".** The submit_* color settings only take effect when `submit_style` is `""`/`"0"` (the CSS template gates the whole submit block on `if ( ! $submit_style )` in `formidable/css/_single_theme.css.php`). Setting it to `"1"` makes the submit button render unstyled/native. Related unfixed Lite bug: the "Disable submit button styling" toggle in `formidable/classes/views/styles/_buttons.php` passes `'checked' => ! $frm_style->get_field_name( 'submit_style' )` — negating a name string — so it always renders unchecked regardless of the saved value.
- **Style colors are stored WITHOUT the `#` prefix** (`submit_bg_color: "8B0000"`). Anything that injects stored values into inline CSS must re-add the `#`; anything writing values can send either form (save strips `#`).

### General

- **Verify with reads after writes.** Abilities validate input at the schema layer, but confirming persisted state with `get-view` / `get-form` / `get-form-action` after a write remains the standard pattern.
- **`list-fields` and some list responses key `data` by field_key/form_key (object), not as an array** — don't index them numerically.

## Form Action Creation Reference

### Email actions
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

### Confirmation actions (success messages)
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

**Note:** The confirmation message lives at `post_content.success_msg`, NOT `confirmation_message`.
