# Known Bugs & Gotchas

Read this when: an MCP ability call fails, silently does nothing, or returns empty results — check here for known symptoms before debugging from scratch.

## Active Bugs

When a new failure appears, record it here (symptom → cause → status) and prefer fixing it in the `formidable-api` plugin over documenting a workaround — workarounds that bypass the API (wp-cli writes, direct SQL) are not acceptable. Once a bug is fixed, don't archive it here: fold whatever behavior it clarified into the relevant reference file and delete the entry. The plugin is unreleased, so there are no old builds in the wild whose symptoms need recognizing.

- **`create-coupon` without `start` produces a coupon that silently never applies.** The ability defaults `'start' => ''` and never fills it, while `FrmCouponsAppHelper::check_coupon_object_for_status()` returns `'draft'` on `empty( $coupon_data->start )`. So a call with just the documented required fields (`name`, `code`, `amount`) succeeds, returns `status: "draft"`, and discounts nothing — no error, no warning. Evidence it is API-specific: on the dev site all 9 admin-created coupons carry a start date and only the MCP-created one did not; the admin UI always sets one. Adding `start` via `update-coupon` was the only change needed to flip it to `active`. **Status: open** — the schema description now warns ("A coupon with no start date is a draft and never applies") but the behavior is unchanged (re-verified against current `formidable-coupons`). Right fix is to default `start` to now in the model, matching the admin; failing that, refuse the create without it. Until then, always send `start`. See `coupons.md`.

- **`list-fields` fails outright on any form containing a choice field whose options are `{label, value}` objects.** The call returns an MCP output-validation error instead of data: `Ability "formidable-forms/list-fields" has invalid output. Reason: output[<field_key>][options][0] is not of type string.` The reader's output schema declares `options` as an array of **strings**, but `create-field`/`update-field` document, accept, and return the object form — so the writer's contract and the reader's schema disagree, and one object-option dropdown makes the whole form's field list unreadable. Isolated on a scratch form: text field only → OK; after adding a select with `options: ["Alpha","Beta"]` → OK; after adding a select with `options: [{"label":"Gamma","value":"gamma"}]` → error. **This leaves no field read path on such a form**: `get-field` does not exist as an ability, and `get-form` returns no `fields` key. **Status: open.** Right fix is to widen the `list-fields` output schema for `options` to accept string-or-object, matching what the write abilities store. Until then, read field keys/ids from the `create-field` responses as you go, or fall back to `get-form` with `return: "html"` and parse the rendered markup (`name="item_meta[<id>]"`, `id="field_<key>"`).

## Standing Cautions

### Conditional logic

- **The builder's condition dropdown is populated only with fields from the form being edited.**
  Cross-form conditional logic therefore renders correctly **only in the parent/child shape**
  (a repeater or embedded child form referencing a parent field), where the parent's fields are
  offered. Between two unrelated top-level forms the reference has no matching `<option>` and the
  select falls back to "— Select —" **even when the stored id is perfectly correct** — which reads
  exactly like a broken import and is not one. Verified both ways on one import: repeater child →
  parent field showed "Parent trigger" selected; unrelated top-level form → stored
  `hide_field => ['19197']` (correct) with a blank dropdown. So **never diagnose conditional logic
  from the builder alone** — read `wp_frm_fields.field_options` or `list-fields`. And treat a form
  in the blank state as read-only: pressing Update posts the empty select over the correct id.

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

### Coupons

- **A coupon needs a `start` date AND a form assignment before it does anything.** See the active bug above for `start`. On the form side, `allowed_form_ids` is derived from the `allowed_coupons` setting on each form's **coupon field**, not stored on the coupon — so an empty `allowed_form_ids` means the coupon works on **no** form, not all of them (`FrmCouponsFilterHelper::filter_coupons_for_form()` returns `array()`).
- **Assigning a coupon to a form that has no Coupon field is silently dropped.** `assign_coupon_to_form()` opens with `FrmProFormsHelper::has_field( 'coupon', $form_id )` and returns early when there isn't one — no error, the ID just never shows up in `allowed_form_ids`. `list-fields` for a `coupon` field first, and read `allowed_form_ids` back after every write.
- **`allowed_form_ids` replaces the whole set**, it doesn't append. Send the full list each time; omit the key to leave assignments alone.
- **`status` is computed on read, never settable** (`draft`/`invalid`/`scheduled`/`expired`/`limit_reached`/`active`), which makes reading it back the cheapest confirmation that a coupon is live.
- **An exhausted coupon reports "Invalid coupon code" on the front end**, not anything about the usage limit — pre-existing add-on wording, and misleading while debugging. Exhaustion does genuinely block the discount, not just the status (verified: total unchanged, no discount applied).
- **`code` and `amount` are frozen once a coupon has been used on an entry.** Create a new coupon instead of repointing an old one.
- **Product options need a `price` key.** `{label, value}` alone is accepted and renders `data-frmprice=""` with a permanently $0.00 total, so a coupon has nothing to discount — see `forms-and-fields.md` § "Layout & Composite Fields".
- **Formidable's price calc doesn't fire on programmatic `value` assignment.** Dispatch real `input`/`change` events when driving a pricing form in a browser, and JS-click the coupon Apply button (`browser_click` times out on the stability wait).

### Landing pages

- **A form has at most one landing page — use `save-landing-page` for every write.** It upserts, so it creates when the form has none and updates when it has one, and cannot produce a duplicate (verified: same input twice → same id with `created: false`, and zero forms site-wide with more than one page). `update-landing-page` exists only for when you already hold a post ID, and cannot move a page between forms.
- **Two switches gate rendering: `status: "publish"` and `enabled: true`.** `enabled` is the add-on's toggle, stored as the form option `landing_page_id` holding `'1'` or `''` (despite the name, nothing reads it as an ID). A published-but-disabled page is not served — the usual cause of an unexplained 404.
- **Landing pages are served from the site root, so slugs compete with every post and page.** A taken slug or a reserved word is **rejected** (`frm_landing_slug_taken`), not silently suffixed.
- **The form embed is always guaranteed on the page.** Supply `content` that already embeds the assigned form (by ID or key, shortcode or block) and it is kept verbatim with `form_embed_injected: false`; supply content without it and the canonical block embed is **appended**, `form_embed_injected: true`. Include the embed yourself to control where the form sits.
- **Settings are split between the post and the form.** `title`/`slug`/`status`/`content` are on the `frm_landing_page` post; `enabled`/`layout`/`bg_image_id`/`opacity` are form options. Worth knowing when verifying raw storage.
- **`delete-landing-page` is cleaner than the add-on's own delete button.** The ability hard-deletes the post *and* clears the toggle (verified: no orphan options, URL 404s); the admin button only trashes the post and leaves the toggle on, so the next form-settings save regenerates a page. Prefer the ability. Note `force: false` trashes instead, and a trashed page still counts as the form's landing page — a later `save-landing-page` updates that trashed post rather than creating a fresh one.

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
