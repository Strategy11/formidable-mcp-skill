# Advanced form and field settings (7.0)

Read this for submission quotas, GDPR/retention, linked image choices, composite-field logic, date/time ranges, autocomplete, or diagnosing changed 7.0 behavior. "Other" placeholders are in [forms-and-fields.md](forms-and-fields.md#other-write-in-option-for-choice-fields); payment action limits are in [payments.md](payments.md#registered-types-and-per-form-limits).

These settings were reviewed against the local Lite 7.0.2b and Pro 7.0.1b source and the changes since each repository's `v6.35` tag. Beta behavior can change. On another site, inspect the installed ability schema and read back saved settings; a successful write alone does not prove a feature is supported. Pro/add-on features require their implementing plugin to be active.

## Submission limits (Pro)

Use `create-form` or `update-form` with an `options` object. These are identity-based quotas, distinct from closing an entire form after `max_entries` or limiting an individual choice's inventory.

| Option | Value and meaning |
|---|---|
| `single_entry` | `1` enables the quota; `0` disables it. The other keys alone do not enable it. |
| `single_entry_type` | Array containing `user`, `ip`, `cookie`, and/or `email`. Multiple identities are checked separately; reaching any selected identity's quota can block a submission. |
| `single_entry_limit` | Positive integer, default `1`. Selecting `cookie` caps it at `100`, including combinations with other identities. |
| `single_entry_interval` | `forever` (default), `hour`, `day`, `week`, `month`, or `year`. Use singular unit names. |
| `single_entry_interval_count` | Positive integer, default `1`; e.g. `2` with `week` means per two calendar weeks. Ignored for `forever`. |
| `unique_email_id` | Numeric ID of the email field to check when `email` is selected. Set it explicitly, especially when several email fields exist. |
| `cookie_expiration` | Cookie lifetime in hours; fractions are accepted. A timed quota retains the cookie at least until its counted entry expires from the interval. |

Example: three submissions per email per two calendar weeks:

```json
{
  "ability_name": "formidable-forms/update-form",
  "parameters": {
    "id": 123,
    "options": {
      "single_entry": 1,
      "single_entry_type": ["email"],
      "unique_email_id": 456,
      "single_entry_limit": 3,
      "single_entry_interval": "week",
      "single_entry_interval_count": 2
    }
  }
}
```

**Calendar semantics:** intervals use the site's timezone. Days start at midnight, weeks follow WordPress's Week Starts On setting, months start on the first, and years on January 1. A count of three months in June counts from April 1, not from three months before the submission's exact timestamp. Describe this accurately if the user asks for a rolling 24-hour window: these settings do not implement that window.

For the expanded count/time quotas, database counts include submitted entries (`is_draft: 0`), excluding drafts and spam. Email validation excludes the entry currently being edited. The legacy one-entry-forever behavior retains its original checks; the special "edit your one existing user entry" behavior only applies to one entry forever, not larger or timed quotas. Do not promise that turning on editing permits extra new submissions.

Email quota and field `unique` are different: a globally unique email field can defeat a quota allowing multiple entries. Read that field's options and verify whether `unique` should be disabled for the requested behavior. `user` quotas need a real logged-in identity; ensure the form's user ID field and access settings support this. `ip` requires IP storage, and `cookie` requires cookies to be allowed by global GDPR settings; do not turn on incompatible identities.

Verification: `get-form` → check every quota key, then `list-fields` → verify the referenced email/user field. Frontend identity/cookie/calendar enforcement needs browser verification when requested; MCP readback is configuration verification, not proof of cookie enforcement. Do not seed entries into an existing form just to consume its quota.

### Other kinds of limits

- Entire-form capacity uses `options.open_status: "limit"` and `max_entries`, with `closed_msg` for the closed state. Scheduled opening uses `open_date`/`close_date` and the installed site's supported `open_status` values. This is not a per-person quota.
- Choice inventory uses the choice's `limit` and the relevant field settings. `options.disable_on_choice_limit: 1` keeps exhausted choices visible but disabled rather than hiding them. Read the existing field configuration before applying inventory limits.
- Repeater row limits (`minnum`, `maxnum`) and slider boundaries (`minnum`, `maxnum`, `step`, `mingap`, `maxgap`) are field settings, not submission quotas. See [repeaters.md](repeaters.md).

## GDPR agreement and automatic entry retention

The form's GDPR panel combines a real agreement field, Pro retention options, and a read-only summary of global GDPR settings.

**Agreement field:** the UI's `frm_include_gdpr` is an admin POST control that adds/removes a `gdpr` field; it is not a stored form option or an MCP parameter. Through MCP, inspect `list-fields` and create/edit the actual `gdpr` field with a label and agreement text. Do not send `options.frm_include_gdpr` and expect a field to appear. Agreement fields require global GDPR to be enabled.

**Pro retention:** stored in form `options`:

```json
{
  "id": 123,
  "options": {"auto_delete_entries": 1, "auto_delete_days": 90}
}
```

Use this only when the user's task authorizes permanent retention-based deletion, including already-existing expired entries. A general request to add a consent checkbox does not authorize enabling retention.

- `auto_delete_entries`: integer `1` enabled, `0` disabled.
- `auto_delete_days`: positive whole days, default `90`, maximum `3650`; invalid/nonpositive input falls back to `90`, larger input is capped.
- Deletion runs hourly through WP-Cron, normally at most 200 entries across forms per run. A backlog can take multiple runs. Eligibility uses entry creation time, not its last edit; drafts and spam are also eligible because this job has no status filter.
- Entries and child entries are permanently removed. Linked posts are trashed. Upload deletion follows the upload field's delete-with-entry setting. Explain these effects when enabling retention.
- Global GDPR (`enable_gdpr`) must be enabled for the job to run. While it is disabled, Pro's settings-save path preserves existing form retention values. A standalone MCP write may follow a different hook path; verify the stored values and the global prerequisite before reporting that cleanup is active.

Global `enable_gdpr`, `no_gdpr_cookies`, `no_ips`, and custom IP-header settings are not per-form overrides. No global-settings ability is present in the reviewed core catalog. If a prerequisite needs changing, explain the required Global Settings UI action instead of inventing an MCP setting or writing to the database.

**Spam retention is separate:** Pro's global `spam_retention_days` defaults to 30 and supports `0` (keep until manually deleted), `7`, `15`, `30`, `60`, or `90`. This cleanup does not require global GDPR. It is not `auto_delete_days`. See [entries-and-views.md](entries-and-views.md#spam-entries-is_draft-4) for MCP access limitations.

## Images in dynamic and lookup choices (Pro)

Linked fields with `data_type: "radio"` or `"checkbox"` can inherit image choices from a source radio, checkbox, product, or upload field. Dropdowns do not use this renderer.

| Setting | Dynamic (`type: "data"`) | Lookup (`type: "lookup"`) |
|---|---|---|
| Source field | `field_options.form_select`: numeric source **field** ID | `field_options.get_values_field`: numeric source field ID |
| Source form | `get_values_form` | `get_values_form` |
| Choice display | `data_type: "radio"` or `"checkbox"` | Same |
| Saved selection | Source entry ID(s) | Source value(s), or label(s) with `lookup_saved_value: "label"` |

Example settings for a lookup (substitute actual IDs):

```json
{
  "id": 789,
  "field_options": {
    "data_type": "radio",
    "get_values_form": 123,
    "get_values_field": 456,
    "lookup_displayed_value": "label",
    "lookup_saved_value": "value",
    "image_size": "medium",
    "hide_image_text": 0,
    "image_label_field": 457
  }
}
```

Image behavior is derived from the source; do not populate the linked field with static copies of image options. The source choices must actually have images enabled. Upload sources use the first upload per submitted value. Image styling is used when **more than half** of the source's valid first-upload attachment IDs are images, measured across the source rather than the currently filtered choices; a tie or a non-image majority uses text choices. Non-image files still have text labels.

`image_label_field` optionally supplies upload labels from a saved field in the same source form; `0` uses the filename. File, dynamic, lookup, and no-save fields are not valid label sources. `image_size` accepts `small`, `medium`, `large`, `xlarge`; `hide_image_text` controls captions. Dynamic selections still save entry IDs, not attachment IDs. Verify saved values and rendered labels/images independently. For shortcode display, use the field's normal image-choice rules; `saved_value` requests raw stored values, and lookup `show="value"` bypasses the image display path.

## Composite fields and conditional logic

Name and Address subfields can control logic. Store a subfield reference as `"<numeric_field_id>_<subfield_key>"` in `hide_field`, e.g. `"456_first"` or `"789_country"`. This is an exception to plain numeric settings, not permission to use a field key. Use Name keys `first`/`middle`/`last`, and Address keys `line1`/`line2`/`city`/`state`/`zip`/`country` as available for the field.

```json
{
  "id": 800,
  "field_options": {
    "hide_field": ["789_country"],
    "hide_field_cond": ["=="],
    "hide_opt": ["United States"],
    "show_hide": "show",
    "any_all": "all"
  }
}
```

Compare to the actual saved country value, not an assumed abbreviation. Address logic offers subfields rather than a whole-address option; Name can also use the whole field. Keep condition arrays aligned. Field logic and action conditions have different structures; do not transpose this object into an email action. Composite validation can identify individual failing subfields, including within repeater rows; repair the named subfield, not the whole field's value shape.

## Date/time ranges and sliders

Flatpickr is the default datepicker for new Pro settings; existing sites can retain jQuery. The global `datepicker_library` is `flatpickr` or `jquery`, not a field setting, and has no reviewed MCP global-settings ability. Read the installed configuration/UI before assuming a renderer. Date validation accepts leading-zero differences in the configured date format; use that format when submitting values.

A date/time range is a pair of fields, not a `range` slider. Preserve its numeric `range_start_field` link and `is_range_end_field` flag; inspect an existing pair when configuring one. The start has `range_field` enabled; its paired end uses `is_range_end_field: 1` and `range_start_field` pointing back to the start. The start controls `required` (a top-level field property), plus `unique`, `read_only`, `admin_only`; date pairs also share `start_year`/`end_year`, and time pairs share `linked_date_field`. Pro copies these when creating an end field and when saving the builder. A standalone MCP update is not necessarily a builder save: read both halves and update the end through MCP too if it has not synchronized. Do not configure opposing visibility or required rules on the end. The builder deletes paired end fields with their starts; after an MCP deletion, read the form to check for an orphan instead of assuming the same UI cascade.

For a `range` slider, `mingap: 0` is valid and allows handles to meet. A blank/non-numeric value uses the default. Keep min/max, step, gaps, and defaults consistent; saved values outside narrowed boundaries are visually clamped. Verify keyboard access to both handles when changing/customizing the rendered slider.

## Autocomplete, calculations, and uploads

- **Autocomplete is in Lite:** use `field_options.autocomplete` on supported field types, e.g. `"email"`, `"organization"`, `"tel"`, `"on"`, or `"off"`. Use the appropriate HTML autocomplete token, not a boolean. Name subinputs retain their own given/family-name handling; repeater Name fields omit autocomplete to avoid unwanted repeated autofill.
- **Calculated text:** the builder disables Max Characters when a calculation is enabled. Do not use a text field's `max` as a way to truncate a computed result; read `calc`/calculation mode and remove an obsolete character limit when appropriate. Calculation caching/lookup optimizations require no new MCP options. Test representative outputs if changing formulas.
- **Upload resizing:** existing `resize`, `new_size`, and `resize_dir` control pre-upload image resizing. The 7.0 resize path strips image metadata and avoids a second EXIF rotation; there is no new EXIF-preservation field option. Verify actual uploaded output if metadata/orientation matters.
- **Accessibility and builder performance:** error summaries now link to failing inputs/subfields, AJAX success/error messages manage focus, and builder settings/logic lists can load lazily. Preserve generated labels, error containers, and focus markup when customizing HTML. A deferred settings panel is not proof that a setting is missing; inspect MCP saved data and open the relevant panel.

## Source review and capability boundaries

The Lite/Pro core ability catalog was compared with [mcp-protocol.md](mcp-protocol.md). 7.0 moves core abilities into Lite/Pro: basic forms/fields/reads/actions/payments are in Lite; entry create/update, statistics, application management and additional style management are Pro. Add-ons supply their own abilities. Do not require `formidable-api` merely to use core MCP features or debug the retired `FrmAPIAbilitiesController` for a core schema problem.

The `v6.35..HEAD` review also covered application assignment from the Forms list (use existing application abilities), style CSS-class renaming (UI feature; do not assume `update-style` supports slug changes), readonly checkbox validation, checkbox statistics/view comparisons, numeric/currency formatting, repeater rendering/button labels, CSV draft statuses, conditional payment actions, spam handling, meta indexing, import remapping, and builder/frontend accessibility/performance fixes. These reuse existing abilities/settings; they do not warrant invented new tool names. Import/export, application, style, shortcode and payment tasks still use their dedicated references.

Primary code locations for updating this reference: `FrmProFormEntryLimitHelper`, `FrmProAutoDeleteEntriesController`, `FrmProSpamEntriesController`, `FrmProChoiceImagesHelper`, `FrmProOtherInputHelper`, `FrmProConditionalLogicController`, `FrmProRangeFieldsController`, `FrmProTransLiteController`, `FrmAbilitiesFormsController`, and `FrmAbilitiesFieldsController`. Check tests for those classes when semantics are unclear.
