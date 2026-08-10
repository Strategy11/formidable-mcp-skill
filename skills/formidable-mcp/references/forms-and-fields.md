# Forms & Fields

Read this when: creating or updating Formidable forms and fields via the MCP adapter — field types, option formats, submit button ordering, repeaters, lookup/dynamic/AI fields, "Other" write-in options, calculations, and conditional logic.

## MCP Call Pattern

All operations go through the Formidable MCP adapter. Initialize a session first, then call abilities via `mcp-adapter-execute-ability`.

**1. Initialize a session and capture the `mcp-session-id` response header:**

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -u "USERNAME:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-25",
      "capabilities": {},
      "clientInfo": {"name": "claude", "version": "1.0"}
    },
    "id": 1
  }' -k -i 2>&1 | grep -i "mcp-session-id" | head -1 | cut -d' ' -f2 | tr -d '\r'
```

**2. Call abilities with the session ID:**

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: {SESSION_ID}" \
  -u "USERNAME:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/create-form",
        "parameters": {
          "name": "Contact Form",
          "description": "A simple contact form"
        }
      }
    },
    "id": 2
  }' -k 2>&1 | jq '.result.structuredContent.data | {id, form_key, name}'
```

**Session management rules:**
- Always initialize a session before making ability calls
- Extract the `mcp-session-id` from the response header
- Include it in all subsequent requests as the `Mcp-Session-Id` header

**Core abilities:**
- `formidable-forms/create-form` — parameters: `name`, `description`, `status`, `logged_in`, `is_template`, `editable`, `fields` (array), `parent_form_id` (integer; persists the child→parent link, e.g. for repeater child forms), and `options` (object). **`options` is applied as the form is created** — `submit_value`, `ajax_submit`, `success_msg`, `success_action` and the rest all take effect in the one call, and any option left out is created with its default. No follow-up `update-form` is needed just to set form options.
- `formidable-forms/update-form` — parameters: `id` (required), plus `name`, `description`, `status` (published/draft), `options` (object), `parent_form_id` (integer; `0` to detach)
- `formidable-forms/list-forms` — parameters: `{}`; returns array with `{id, form_key, name, status}`
- `formidable-forms/create-field` — parameters: `form_id`, `type`, `name`, `required`, `field_order`, `field_options`; `options` accepts both plain strings (`"Option 1"`) and objects with separate values (`{"label": "Low", "value": "low"}`). When any option's label differs from its value, `separate_value` is enabled automatically, so entries validate against the VALUES (`"low"`), not the labels. Validation errors from `create-entry`/`update-entry` come back as readable strings (`"field123: Priority is invalid"`)
- `formidable-forms/update-field` — parameters: `id` (field ID), plus fields to change (e.g. `field_order`, `options`, `field_options`, `default_value` — all persist correctly); `form_id` is optional (derived from the field)
- `formidable-forms/list-fields` — response `data` is an OBJECT keyed by field_key, NOT an array

## Form Cache Clearing

**All field operations via the API automatically clear form caches** to prevent stale data in the form editor:
- Field creation calls `FrmField::delete_form_transient()` and `FrmForm::clear_form_cache()`
- Field updates (single and bulk) clear both caches
- Field deletion clears both caches

**If fields don't appear in the editor after creation/update:**
1. Hard refresh the browser (Cmd+Shift+R or Ctrl+Shift+R)
2. This is almost always a browser cache issue, NOT a server-side problem

**LAST RESORT — local troubleshooting only, NOT part of any workflow.** MCP operations clear caches automatically. Only if a hard refresh still shows stale data, you may manually flush caches on a local dev site:

```bash
wp eval '
  FrmField::delete_form_transient({FORM_ID});
  FrmForm::clear_form_cache({FORM_ID});
  wp_cache_flush();
'
```

## Field Types

### Lite/Free Field Types
- `text` — Single line text
- `textarea` — Paragraph/multi-line text
- `name` — Name field (preferred for names; supports first/last name parsing)
- `email` — Email address
- `url` — Website/URL
- `number` — Numeric input
- `phone` — Phone number
- `checkbox` — Checkboxes
- `radio` — Radio buttons
- `select` — Dropdown select (canonical type; the MCP enum also accepts the alias `dropdown`, normalized to `select` on save)
- `html` — HTML display
- `hidden` — Hidden field
- `user_id` — Current user ID
- `captcha` — CAPTCHA verification
- `credit_card` — Payment field
- `submit` — Submit button
- `gdpr` — GDPR consent field
- `product` — Product (pricing)
- `quantity` — Quantity (pricing)
- `total` — Total (pricing)

### Pro Field Types (Lite plugin shows upsell for these)
- `file` — File upload
- `date` — Date picker
- `time` — Time picker
- `password` — Password (masked input)
- `address` — Address field
- `summary` — Summary/review before submit
- `rte` — Rich text editor
- `toggle` — Toggle switch
- `range` — Slider
- `scale` — Linear scale
- `star` — Star rating
- `data` — Dynamic field
- `lookup` — Lookup field
- `divider` — Section heading
- `divider|repeat` — Repeater section
- `break` — Page break
- `form` — Embed form
- `tag` — Tags field
- `signature` — Digital signature (requires addon)
- `ranking` — Ranking field (surveys addon)
- `likert` — Likert scale (surveys addon)
- `nps` — Net Promoter Score (surveys addon)
- `ai` — AI field (AI addon)
- `ssa-appointment` — Appointment field (Simply Schedule Appointments addon)
- `virtual` — Virtual field
- `coupon` — Coupon field (coupons addon)

### Field Type Preferences

**Always use the most specific field type** rather than defaulting to generic `text`:
- `name` — For name inputs (not text) — supports first/last name separation
- `email` — For email inputs (not text) — proper validation
- `phone` — For phone inputs (not text) — format validation
- `date` — For date inputs (not text) — date picker UI (Pro)
- `textarea` — For multi-line text (not text)
- `address` — For addresses (Pro)

Specialized field types provide proper validation, formatting, and user experience. Before falling back to generic `text`, check if a specialized type matches the field's purpose.

## Field Labels (Required)

**Every form field MUST have the `name` column populated with a label.**

- The `name` column in the `wp_frm_fields` table is what Formidable displays as the field label in the form editor and on the frontend
- Fields without names are inaccessible and confusing; NULL or empty `name` = no visible label
- The `name` field is NOT the field_key — `field_key` is for internal reference; `name` is the display label. **The name does seed the key**: a field named "Full Name" is created with `field_key: "full-name"` unless you pass an explicit `field_key`. Good names therefore give you readable shortcodes for free
- **`field_key` is unique across the whole site, not per form.** A key that already exists anywhere gets silently auto-suffixed (`full-name` → `full-name2`, verified). Always read the actual keys back from the create response or `list-fields` before using them in entry payloads or view shortcodes — an assumed key resolves against the *other* form's field
- Set at field creation time via the create-field ability; fix missing labels with `update-field` (cache clearing is automatic — never update `name` via direct database writes)

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {
    "form_id": "1514",
    "name": "Game",
    "type": "text",
    "required": true
  }
}
```

(`name` MUST be set — it displays as the label; `field_key` is generated as the internal reference and is different from `name`.)

**Verification:**
1. Call `list-fields` for the form (response `data` is an object keyed by field_key) — ensure no NULL/empty `name` values
2. Verify in wp-admin form editor that labels appear

## Adding Fields to a Form

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {
    "form_id": "1429",
    "type": "name",
    "name": "Your Name",
    "required": true
  }
}
```

### Submit Button Sort Order (Critical)

When adding multiple fields, **always ensure the submit button field has the last (highest) `field_order`** among all fields so it appears at the bottom of the form.

After adding all content fields, update the submit button's `field_order` to one greater than the highest field order:

```json
{
  "ability_name": "formidable-forms/update-field",
  "parameters": {
    "id": "{SUBMIT_FIELD_ID}",
    "field_order": {NEXT_ORDER_NUMBER}
  }
}
```

**Example workflow:**
1. Add fields with `field_order`: 1, 2, 3, 4, 5 (submit button initially at 1)
2. After all fields are added, update the submit button to `field_order`: 6
3. Result: form displays content fields 1-5, then submit button at position 6

## Option Fields (Radio, Checkbox, Dropdown)

### Minimum Requirements

- **Radio buttons**: Always add at least 2 options
- **Checkboxes**: Always add at least 1 option
- **Dropdowns (select)**: Always add at least 2 options

Fields without options are broken and unusable — users cannot submit the form. Verify the minimum option count at field creation time, not after.

**Anti-pattern (don't do this):**

```json
{"ability_name": "formidable-forms/create-field", "parameters": {"form_id": "1515", "type": "radio", "name": "Priority"}}
```

### Creating Option Fields via MCP

Pass `options` as a **top-level parameter** (array of label/value objects). Do NOT nest it inside `field_options` — `field_options.options` is silently ignored at creation and the field gets generic "Option 1"/"Option 2" placeholders.

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {
    "form_id": "1515",
    "type": "radio",
    "name": "Priority",
    "required": true,
    "options": [
      {"label": "Low", "value": "low"},
      {"label": "Medium", "value": "medium"},
      {"label": "High", "value": "high"}
    ]
  }
}
```

**After creating the field, verify options display correctly:**
1. Load the form in the browser and hard-refresh
2. Check that option labels match your input (Low, Medium, High)
3. If you see generic "Option 1", "Option 2" labels, repair the options with `update-field` (see fix below)

### Option Format & Database Storage

Options are stored as a **serialized PHP array with numeric indices** in the `frm_fields.options` column.

**Proper unserialized structure:**

```php
[
  0 => ["label" => "Low", "value" => "low"],
  1 => ["label" => "Medium", "value" => "medium"],
  2 => ["label" => "High", "value" => "high"],
]
```

**When serialized in database:**

```
a:3:{i:0;a:2:{s:5:"label";s:3:"Low";s:5:"value";s:3:"low";}i:1;a:2:{s:5:"label";s:6:"Medium";s:5:"value";s:6:"medium";}i:2;a:2:{s:5:"label";s:4:"High";s:5:"value";s:4:"high";}}
```

**Key points:**
- Numeric indices (0, 1, 2, ...) — NOT string keys like "low", "medium", "high" (exception: "Other" options, below)
- Each option has `label` (displayed to users) and `value` (stored in database)
- `value` should be lowercase/simple; `label` should be user-friendly
- Optional: `image` key can be added for image choices (image field type)

### Common Mistake — Generic "Option 1", "Option 2" Display

If an option field displays generic labels like "Option 1", "Option 2" instead of your intended labels, the `options` database column contains generic placeholder values. This happens when:
1. Options are created without explicit label/value pairs
2. Options are stored in `field_options` but the `options` column (which the form renderer uses) was never updated

The MCP creates options in `field_options`, but the form renderer also checks the `options` column. Always verify that both columns contain the same values, or clear `options` entirely and rely only on `field_options`.

### Fixing Wrongly-Formatted Options

If options are in a wrong format (pipe-separated, wrong structure, or generic placeholders), fix them with `update-field` — pass the corrected `options` array. Do NOT use SQL or wp-cli writes for this.

```json
{
  "ability_name": "formidable-forms/update-field",
  "parameters": {
    "id": "{FIELD_ID}",
    "options": [
      {"label": "Low", "value": "low"},
      {"label": "Medium", "value": "medium"},
      {"label": "High", "value": "high"}
    ]
  }
}
```

Notes:
- `form_id` is optional — it is derived from the field automatically.
- `options` accepts both plain strings (`"Option 1"`) and objects with separate label/value pairs.
- Cache clearing is automatic — no manual transient deletion or `wp_cache_flush()` needed.
- The ability handles PHP serialization of the `options` column correctly.

### Examples by Field Type

**Radio buttons (pick one):**

```php
[
  0 => ["label" => "Yes", "value" => "yes"],
  1 => ["label" => "No", "value" => "no"],
]
```

**Checkboxes (pick multiple):**

```php
[
  0 => ["label" => "Email", "value" => "email"],
  1 => ["label" => "Phone", "value" => "phone"],
  2 => ["label" => "SMS", "value" => "sms"],
]
```

**Dropdown (pick one from list):**

```php
[
  0 => ["label" => "Option 1", "value" => "option_1"],
  1 => ["label" => "Option 2", "value" => "option_2"],
  2 => ["label" => "Option 3", "value" => "option_3"],
]
```

**With image choices (image field):**

```php
[
  0 => ["label" => "Choice 1", "value" => "choice_1", "image" => "url_or_id"],
  1 => ["label" => "Choice 2", "value" => "choice_2", "image" => "url_or_id"],
]
```

## "Other" Write-In Option for Choice Fields

Choice fields (radio, checkbox, dropdown) can include an "Other" option that lets users enter custom values.

### How Formidable Recognizes "Other"

Formidable identifies "Other" by checking if the **option key** starts with `"other_"`. From `FrmFieldsHelper::is_other_opt()`:

```php
public static function is_other_opt( $opt_key ) {
    return $opt_key && str_starts_with( $opt_key, 'other_' );
}
```

When rendering options, Formidable iterates by option key, and for keys matching `other_`:
1. Adds the CSS class `frm_other_trigger` to the option
2. Renders a hidden text input with class `frm_other_input` (initially hidden via `frm_pos_none`)
3. JavaScript (formidablepro.js) shows/hides the text input when "Other" is selected

### Requirements

1. **Option key must start with `"other_"`**
2. **Use object-based (keyed) options format** — NOT an array, because array format doesn't preserve the `other_` key prefix:

```json
{
  "dog": {"label": "Dog", "value": "Dog"},
  "cat": {"label": "Cat", "value": "Cat"},
  "other_1": {"label": "Other", "value": "Other"}
}
```

Do NOT use array format for fields with an "Other" option — this won't work:

```json
[
  {"label": "Dog", "value": "Dog"},
  {"label": "Other", "value": "Other"}
]
```

3. **Enable in field_options:** `{"other": "1"}`

Note: passing "Other" as a regular array option (e.g. via a generic REST payload) fails because the option lacks the `other_` key prefix, so the frontend JavaScript never treats it as the special "Other" option.

### Example: Pet Type Field

```json
{
  "ability_name": "formidable-forms/update-field",
  "parameters": {
    "form_id": "1492",
    "id": "12918",
    "options": {
      "dog": {"label": "Dog", "value": "Dog"},
      "cat": {"label": "Cat", "value": "Cat"},
      "other_1": {"label": "Other", "value": "Other"}
    },
    "field_options": {"other": "1"}
  }
}
```

### Frontend HTML Structure (for verification)

```html
<div class="frm_radio" id="frm_radio_12918-other_1">
  <label for="field_lb0tk-other_1">
    <input type="radio" name="item_meta[12918]" id="field_lb0tk-other_1" value="Other" />
    Other
  </label>
  <label for="field_lb0tk-other_1-otext" class="frm_screen_reader frm_hidden">Other</label>
  <input type="text" id="field_lb0tk-other_1-otext"
         class="frm_other_input frm_pos_none"
         name="item_meta[other][12918]" value="" />
</div>
```

The `frm_pos_none` class hides the input; JavaScript removes it when "Other" is selected.

## AI Fields

AI fields generate content using OpenAI/GPT based on input from other fields. They watch specified fields and generate responses when those fields change.

### Required Settings in field_options

- `system` — System prompt (instructions for the AI)
- `watch_ai` — Array of field IDs to monitor (must be an array, e.g. `array(13086, 13084)`, NOT a string `"13086, 13084"`)
- `ai_question` — Question template using field ID shortcodes like `[13086]`
- `ai_model` — Model to use (e.g., `gpt-3.5-turbo`, `gpt-4`)
- `hide_ai` — Hide AI response initially (optional)

### Critical Rules

- **Copy the full field_options structure from a reference AI field** and add your AI settings. AI fields have 70+ field_options keys inherited from the parent field type; missing keys cause settings to not persist or display in the form editor. Never create minimal field_options.
- **ai_question uses field ID shortcodes**: `[13086]` — NOT field keys like `[lwrli]` (this is different from view templates!)
- **Save via MCP** — the abilities handle PHP serialization and cache clearing automatically
- **API key required**: The site must have OpenAI/AI credentials configured in Formidable settings

### Creating an AI Field

1. **Create the field** with `create-field`:

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {"form_id": "1517", "type": "ai", "name": "Generated Story", "field_order": 4}
}
```

2. **Read a reference AI field's full field_options** via MCP (`list-fields` on a form with an existing AI field — response `data` is an object keyed by field_key).

3. **Merge in the AI settings and save with `update-field`** (`field_options` persists correctly; serialization and cache clearing are automatic):

```json
{
  "ability_name": "formidable-forms/update-field",
  "parameters": {
    "id": "{AI_FIELD_ID}",
    "field_options": {
      "...": "full field_options copied from the reference AI field, plus:",
      "system": "You are a creative storyteller. Generate engaging stories.",
      "watch_ai": [13086, 13084, 13085],
      "ai_question": "Write a [13086] story featuring [13085] who is [13084].",
      "ai_model": "gpt-3.5-turbo"
    }
  }
}
```

### ai_question Shortcode Reference

```
"Write a [13086] story about [13085]"     ✓ CORRECT (uses field IDs)
"Write a [category] story about [name]"   ✗ WRONG (uses field names/keys)
```

The question template can include field ID shortcodes, static text/formatting, and multiple field references. On submission, the AI field watches the specified fields; when any change, the question template is constructed with actual values, the system prompt guides the AI, and the response is stored in the AI field.

### Known Failure Mode

An AI field created without populated field_options shows the field label in the editor but blank AI settings (prompt, question, model). Fix: copy full field_options from an existing AI field, add the AI-specific settings, and save via `update-field` (cache clearing is automatic).

## Repeatable Sections

Formidable supports **two different repeater patterns**. Choose based on your needs.

**CRITICAL RULE for both patterns: `form_select` on the divider must ALWAYS be set to a child form ID.** The plugin checks `if ( ! empty( $field['form_select'] ) )` to decide whether to display the repeater icon; if empty, it shows the header icon instead.

### Pattern 1: Nested Forms Repeater (complex, reusable sub-forms)

Fields live in a **child form**; the parent form has a `divider` with `"repeat":"1"` and `"form_select"` pointing to the child form, plus an `end_divider` that renders add/remove buttons.

**Critical points:**
- Repeater fields go ONLY in the child form, NOT the parent form
- The parent form contains only: divider (with form_select), end_divider, and non-repeating fields
- Child form fields MUST have complete `field_options` (71+ keys, copied from a template/existing field) — NOT minimal serialized options
- End_dividers MUST have full field_options with `add_label`, `remove_label`, and repeater settings for buttons to render
- **Expected behavior:** child form fields do NOT appear in the parent form's field editor — they appear only in the child form editor and on the frontend when the repeater renders. This is correct, not a bug.

**Child form field configuration:**
1. Set `in_section` in field_options to the parent divider field ID
2. Copy FULL field_options from a template/existing field
3. `field_order` can be non-sequential within the child form (e.g., 8, 10, 12)
4. Preserve all field_options keys so the backend editor shows fields in the correct repeater sections

**End_divider field_options must include:**
- `"add_label": "Add"` — add button label
- `"remove_label": "Remove"` — remove button label
- `"minnum": 1` — minimum repeating rows
- `"maxnum": 10` — maximum repeating rows
- `"step": 1` — increment step
- `"format": "both"` — display both add and remove buttons
- Plus standard field_options (show_hide, blank validation, etc.)

**Structure/workflow:**

```bash
# 1. Create child form WITH parent_form_id in one call (CRITICAL - makes fields
#    display nested in parent editor; persisted directly by create-form)
#    ability: formidable-forms/create-form  {"name": "Repeater Items", "parent_form_id": 1492}
#    Result: child_form_id = 1495
#
#    For an EXISTING child form missing the link, use update-form instead:
#    ability: formidable-forms/update-form  {"id": 1495, "parent_form_id": 1492}

# 2. Add fields to the CHILD form (these repeat)
#    Include in_section in field_options AND copy full field_options from a template:
#    {"form_id": "1495", "type": "text", "name": "Item Name", "field_order": 8,
#     "field_options": {<full template options with "in_section": <divider_id>>}}
#    {"form_id": "1495", "type": "textarea", "name": "Description", "field_order": 10,
#     "field_options": {<full template options with "in_section": <divider_id>>}}

# 3. Create divider in PARENT form with form_select pointing to the child form
#    {"form_id": "1492", "type": "divider", "name": "Items Section",
#     "field_options": {"repeat": "1", "form_select": "1495"}, "field_order": 8}

# 4. Create end_divider in PARENT form to close the repeater
#    {"form_id": "1492", "type": "end_divider", "field_order": 9,
#     "field_options": {<full template options with add_label/remove_label + repeater settings>}}
```

### Pattern 2: Direct Parent Repeater (simple field groups)

Repeatable fields live directly in the **parent form** with `in_section` grouping. **Still create a child form**, but leave it empty — it exists only so `form_select` can reference it (required for the plugin to function and show the repeater icon).

**Structure:**
1. Create a child form (even though empty), passing `parent_form_id` (the parent form ID) directly to `create-form`
2. Create a divider in the parent form with `"repeat":"1"` and `"form_select": <child_form_id>` (MUST be set!)
3. Create repeater fields in the PARENT form with `in_section: <divider_id>` in field_options — any field type; keep field orders consecutive (no gaps)
4. Create an end_divider in the parent form with `add_label`/`remove_label`

**Example: Radio Options repeater with 4 radio fields**

```bash
# 1. Create child form (empty, just for form_select reference) WITH parent_form_id
#    ability: formidable-forms/create-form  {"name": "Radio Options", "parent_form_id": 1492}
#    Returns: child_form_id = 1505
#    (For an existing child form: formidable-forms/update-form {"id": 1505, "parent_form_id": 1492})

# 2. Divider with repeat + form_select (returns divider_id = 13020)
#    {"form_id": "1492", "type": "divider", "name": "Radio Options",
#     "field_options": {"repeat": "1", "form_select": "1505"}, "field_order": 54}

# 3. Radio fields in PARENT form with in_section: 13020
#    {"form_id": "1492", "type": "radio", "name": "1st Radio", "field_options": {"in_section": 13020}, "field_order": 56}
#    {"form_id": "1492", "type": "radio", "name": "2nd Radio", "field_options": {"in_section": 13020}, "field_order": 58}
#    {"form_id": "1492", "type": "radio", "name": "3rd Radio", "field_options": {"in_section": 13020}, "field_order": 60}
#    {"form_id": "1492", "type": "radio", "name": "4th Radio", "field_options": {"in_section": 13020}, "field_order": 62}

# 4. End_divider in parent form
#    {"form_id": "1492", "type": "end_divider",
#     "field_options": {"add_label": "Add", "remove_label": "Remove"}, "field_order": 64}
```

### Pattern Comparison

| Aspect | Nested Forms | Direct Parent |
|--------|--------------|---------------|
| Requires child form | Yes | Yes |
| Child form has fields | Yes | No (empty) |
| Fields visible in parent editor | No (only in child) | Yes |
| **form_select set?** | **Yes** | **Yes (REQUIRED!)** |
| Reusable | Yes | No |
| Complexity | Higher | Lower |
| Best for | Complex, reusable structures | Simple field groups |

## Lookup Fields (Pro)

Lookup fields pull options dynamically from another form's field, letting users select from another form's values.

**Critical parameters (in field_options):**
- `get_values_form` — The source FORM ID (NOT `form_select`)
- `get_values_field` — The source FIELD ID (NOT `form_field`)

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {
    "form_id": "1492",
    "type": "lookup",
    "name": "Animal Lookup",
    "field_options": {
      "get_values_form": "362",
      "get_values_field": "3671"
    },
    "field_order": 10
  }
}
```

This displays all values from field 3671 (Animal field) in form 362 (Animals form). Common mistake: using `form_select`/`form_field` — those won't work for lookup fields.

## Dynamic Fields (data type, Pro)

Dynamic (data) fields pull values from another form's field for dynamic population/display.

**CRITICAL: Data fields use THREE parameters with DIFFERENT purposes:**
- `form_select` — **The source FIELD ID** (REQUIRED! The backend checks whether this is empty to decide if the field is "configured"; the form builder uses it to populate the "Load Options From" UI)
- `get_values_form` — The source FORM ID
- `get_values_field` — The source FIELD ID (same value as `form_select`)

**Unlike repeaters — where `form_select` is a FORM ID — for data fields `form_select` MUST be a FIELD ID.** The builder code (`FrmProFieldData.php`) looks up a field record:

```php
if ( isset( $field['form_select'] ) && is_numeric( $field['form_select'] ) ) {
    $selected_field = FrmDb::get_row( 'frm_fields', array( 'id' => $field['form_select'] ), 'id, form_id' );
```

If `form_select` is empty or set to a form ID, the field lookup fails and the field shows "not configured" / a blank "Load Options From" dropdown, even if `get_values_form`/`get_values_field` are set.

**Correct configuration:**

```json
{
  "ability_name": "formidable-forms/create-field",
  "parameters": {
    "form_id": "1492",
    "type": "data",
    "name": "Animal Dynamic",
    "field_options": {
      "form_select": "3671",
      "get_values_form": "362",
      "get_values_field": "3671"
    },
    "field_order": 15
  }
}
```

**How to apply:**
- Set `form_select` to the source FIELD ID (critical!)
- Set `get_values_form` to the source FORM ID
- Set `get_values_field` to the source FIELD ID (same as form_select)
- Copy all field_options keys from a working lookup field as a template
- Cache clearing is automatic when saving via MCP
- Verify the "Load Options From" dropdown in the backend shows the selected field

**Lookup vs Dynamic:**
- **Lookup**: user selection (choice field); needs only `get_values_form` + `get_values_field`
- **Dynamic (data)**: dynamic value population (typically read-only/display); needs `form_select` (field ID) + `get_values_form` (form ID) + `get_values_field` (field ID)

## Calculations and Formulas

Fields compute values via the `calc` property in `field_options`.

**Syntax:**
- Field references: `[123]` (field id) or `[field_key]`
- Operators: `+`, `-`, `*`, `/` (write as `\/` in JSON)
- Comparisons: `[field] > 8`; ternary: `([field] > 8) ? 1 : 0`
- Math functions: `Math.pow(x,y)`, `Math.sqrt(x)`, `Math.ceil(x)`, `Math.floor(x)`, `Math.round(x)`
- Text concatenation: `"Hello [field1] [field2]"`

**Examples:**

```
"calc": "[price] * [quantity]"                 // multiply
"calc": "([7116]*(9\/5))+32"                   // temperature conversion
"calc": "Math.sqrt([value])"                   // square root
"calc": "(([score] > 8) ? 1 : 0) + 1"          // ternary scoring
```

## Conditional Logic

**Field-level** (show/hide fields based on other fields' values), in field_options:

```json
{
  "hide_field": ["8751"],      // controlling field ids (array)
  "hide_field_cond": ["=="],   // operators: ==, !=, <, >, <=, >=, LIKE, not LIKE
  "hide_opt": ["Hours"],       // comparison values (parallel to hide_field)
  "show_hide": "hide",         // "show" or "hide" when conditions match
  "any_all": "all"             // "any" (OR) | "all" (AND) for multiple conditions
}
```

**Action-level** (controls when form actions run):

```json
{
  "conditions": {
    "send_stop": "send",       // "send" = if true | "stop" = unless true | "" = always
    "any_all": "any",
    "0": {"hide_field": 10153, "hide_field_cond": "==", "hide_opt": "PayPal"}
  }
}
```

## Form Actions (Overview)

Form actions trigger on submission: email notifications, webhooks, user registration, payments, etc.

**Common action types:**
- `email` — Send notification email with form data
- `on_submit` — Show confirmation message or redirect
- `payment` — Process Stripe/Square payment
- `wppost` — Create WordPress post from entry
- `register` — Create WordPress user
- `quiz` — Score a quiz based on answers
- `quiz_outcome` — Show outcome based on answers

Each action includes `"conditions"` to control when it runs and `"event": ["create","update"]` for when it triggers.

### Action Ability Notes

- To modify an action, use `update-form-action` with `id` plus a partial `post_content` — it merges with the action's existing settings
- Verify action creation with `get-form-action` using the returned ID
- See `actions.md` for the full form-action reference

**Email action** — include `post_content` with email settings:

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

**Confirmation action** — include `success_msg` in `post_content`:

```json
{
  "form_id": "1429",
  "type": "confirmation",
  "post_content": {
    "success_action": "message",
    "success_msg": "You submitted the form!",
    "event": ["create"]
  }
}
```

## Form Options

Key form-level settings (in form `<options>`):
- `submit_value` — Submit button label
- `ajax_submit` — "1" for submit without page reload
- `antispam` — "1" for honeypot protection
- `on_submit_migrated` — "1" to use on_submit action (modern approach)
- `custom_style` — Style key to apply to form
- `single_entry_type` — ["user"] to limit one entry per user
- `chat` — ["1"] for conversational (chat) forms
- `logged_in` — "1" to require login
- `editable` — "1" to allow users to edit their entry

## Layout & Composite Fields

**Multi-page forms:** use the `break` field type to create page breaks.

**Product fields:** product choices include price in the options array. Quantity fields reference their product: `"product_field":"[3334]"`.

**Composite fields:** Name and Address fields use JSON for `default_value` and `placeholder`:
- Name: `{"first":"","middle":"","last":""}`
- Address: `{"line1":"","line2":"","city":"","state":"","zip":"","country":""}`

**Grid layout:** use `classes` in `field_options`:
- New: `frm1` through `frm12` (12-column grid)
- Legacy: `frm_half`, `frm_third`, `frm_fourth`, `frm_full`
- Always add `frm_first` to start a new row

## Formidable Applications (Pro)

Applications bundle forms, views, and pages into reusable collections. Manage them entirely through the MCP application abilities — never write to the taxonomy tables directly.

### Application Abilities

- `formidable-forms/create-application` — parameters: `name` (required), `description` (optional); returns the application ID
- `formidable-forms/delete-application` — parameters: `application_id`
- `formidable-forms/add-item-to-application` — parameters: `application_id`, `item_id`, `item_type` (`form`, `view`, or `page`)
- `formidable-forms/remove-item-from-application` — same parameters as add-item
- `formidable-forms/list-application-items` — parameters: `application_id`

The abilities manage counts and metadata (form/view/page counts, timestamps, term relationships) internally — no manual count or metadata updates are needed.

### Complete Workflow: Application with Form, View, and Entries

**1. Create the form:**

```json
{
  "ability_name": "formidable-forms/create-form",
  "parameters": {"name": "High score form", "description": "Track arcade high scores"}
}
```

**2. Create fields** with `create-field` (use specific types: name, email, number, etc.).

**3. Create a view** with `create-view` — it supports `content`, `limit`, and `status`, and sets all required postmeta automatically (no manual `wp_insert_post` or postmeta writes needed).

**4. Create the application:**

```json
{
  "ability_name": "formidable-forms/create-application",
  "parameters": {"name": "High scores", "description": "Arcade high score tracker"}
}
```

**5. Add the form and view to the application:**

```json
{
  "ability_name": "formidable-forms/add-item-to-application",
  "parameters": {"application_id": 44, "item_id": 1514, "item_type": "form"}
}
```

```json
{
  "ability_name": "formidable-forms/add-item-to-application",
  "parameters": {"application_id": 44, "item_id": 10631, "item_type": "view"}
}
```

Pages work the same way with `"item_type": "page"`. To remove an item, call `remove-item-from-application` with the same parameters.

**6. Verify** with `list-application-items` (`{"application_id": 44}`) — confirm the form and view appear.

**7. Add sample entries** via the MCP entry-creation ability.

### Storage Model (background only — do NOT write to these tables)

For context on how applications are stored (useful when read-debugging):

- Applications are **WordPress taxonomy terms** in the `frm_application` taxonomy
- **Metadata structure:** forms in `_frm_form_id` term meta (multiple values allowed); views/pages in `term_relationships`; counts in `_frm_form_count`, `_frm_view_count`, `_frm_page_count`
- **Retrieval logic:** `FrmProApplication::get_forms_for_application($id)` queries `_frm_form_id` metadata; `FrmProApplication::get_posts_for_application($id)` queries `term_relationships` with a tax_query on `frm_application`
- Views are stored as posts with `post_type: "frm_display"` (NOT `frm_views`); the application retrieves views by querying `frm_display`
- **No caching issues:** unlike forms, applications need no cache clearing after creation — the React admin UI fetches data via AJAX (`frm_get_data_for_application` action)

All writes to this structure go through the application abilities above; verify with MCP `list-application-items`.
