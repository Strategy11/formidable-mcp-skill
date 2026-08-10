# Form Template XML Schema

Read this when: creating or editing Formidable XML templates (export/import format), writing field_options JSON, calculations, conditional logic, form actions, views, or styles.

## Key Concepts

### Template Types
- **Form templates**: one `<form>` + form actions (email, on_submit, payment, etc.)
- **View templates**: one form + form actions + one or more display Views (frm_display)
- **Style templates**: single style `<view>` with `post_type=frm_styles` (no form)

### XML Structure
All templates use a WXR-like envelope with `<channel>` containing `<form>` and `<view>` items.
Text/JSON goes in `<![CDATA[ ... ]]>` tags. JSON in CDATA is typically single-escaped (`\"`).

## Critical ID Rules

1. **id** and **field_key** must be unique within the file; both are valid for references
2. Actions/views use `<menu_order>` = parent form id
3. `in_section` must equal the divider field id (or `"0"` for top-level)
4. `quantity.product_field` must point to the product field id
5. Field conditions use **parallel arrays** (`hide_field` / `hide_field_cond` / `hide_opt`)
6. Action conditions use **object form** (`{"0":{...}}`) except `quiz_outcome` (array of rules)

## Field Options (field_options JSON)

Common to most fields:
- `blank` — required error message
- `invalid` — validation error message
- `classes` — grid classes (frm1-frm12, frm_half, frm_third, etc.)
- `label` — `"hidden"` | `"none"` | `"inline"` | `"right"` | `""` (top)
- `placeholder` — help text (string, or JSON for composite fields)
- `unique_msg` — for unique validation
- `read_only` — display only (used with calc)
- `calc` — calculation formula
- `calc_dec` — decimal places for calc
- `hide_field`, `hide_field_cond`, `hide_opt`, `show_hide`, `any_all` — conditional logic

Composite fields (name, address) use `default_value` and `placeholder` as JSON with sub-keys.

## Calculations (calc syntax)

- Field references: `[123]` (id) or `[field_key]`
- Operators: `+ - * /` (write division as `\/` in JSON/CDATA)
- Comparisons/ternary: `([4193] > 8) ? 1 : 0`
- Math functions: `Math.pow()`, `Math.sqrt()`, `Math.ceil()`, `Math.floor()`, `Math.round()`
- Text concatenation: `"Contact: [1387] [1388]"`

## Field Types (Comprehensive List)

**Lite fields**: text, textarea, name, email, url, phone, number, hidden, password, checkbox, radio, select, html, user_id, captcha, credit_card, submit, gdpr, product, quantity, total

**Pro fields**: file, date, time, rte, address, summary, scale, star, range, toggle, data, lookup, divider, break, form, ranking, likert, nps, signature, ai, tag, payment-gateway, quiz_score, ssa-appointment, virtual, coupon

**Special fields**:
- `divider` with `"repeat":"0"` (static section) or `"repeat":"1"` (repeatable)
- `end_divider` — closes a repeatable section
- `break` — page break for multi-page forms
- `quiz_score` — displays computed quiz score

## Form Options (options JSON)

- `submit_value` — submit button label
- `ajax_submit` — submit without page reload
- `antispam` — honeypot/antispam
- `on_submit_migrated` — 1 = use on_submit action (not legacy)
- `custom_style` — attach a style (1 / style key / `"formidable-style"`)
- `single_entry_type` — `["user"]` / `["ip"]` / `["cookie"]` (limit one entry per...)
- `chat` — `["1"]` for conversational forms
- `submit_conditions` — conditional submit button display
- Payment defaults: `currency`, `business_email`, `return_url`, `cancel_url`

## Conditional Logic

**Field-level** (show/hide a field based on other fields):
```json
{
  "hide_field": ["8751"],      // controlling field ids
  "hide_field_cond": ["=="],   // operators per field
  "hide_opt": ["Hours"],       // values to compare
  "show_hide": "hide",         // "show" or "hide" when conditions match
  "any_all": "all"             // "any" (OR) | "all" (AND)
}
```

**Action-level** (conditions for when actions run):
```json
{
  "conditions": {
    "send_stop": "send",  // "send" (if true) | "stop" (unless true) | "" (always)
    "any_all": "any",
    "0": {"hide_field": 10153, "hide_field_cond": "==", "hide_opt": "PayPal"}
  }
}
```

Operators: `==`, `!=`, `<`, `>`, `<=`, `>=`, `LIKE`, `not LIKE`

## Form Actions (post_type=frm_form_actions)

Action types (by `<excerpt>`): email, on_submit, payment, register, twilio, wppost, paypal, quiz, quiz_outcome

### email
- `event`: `["create","update"]`
- `email_to` — `[admin_email]`, `[fieldid]`, or an address
- `email_subject`, `email_message` — `[default-message]` renders all fields
- `cc`, `bcc`, `reply_to`, `from`
- `inc_user_info`, `plain_text`, `autoresponder` (with schedule)
- `conditions` — when to send

### on_submit (confirmation)
- `success_action` — `"message"` | `"redirect"` | `"page"`
- `success_msg` — displayed message
- `success_url` — for redirect
- `success_page_id` — for page
- `show_form` — show form again after submit

### payment (Stripe/Square/Authorize.net)
- `gateway` — `["stripe"]` | `["square"]` | `["authnet"]`
- `amount` — total field ref
- `credit_card` — credit_card field id
- `currency`, `type` (`"single"` | `"recurring"`)
- `interval`, `interval_count` — recurring cadence
- Billing fields: `billing_first_name`, `billing_last_name`, `email`, etc.

### wppost (create WordPress post)
- `post_type` — `"post"` | `"product"` etc.
- `post_title`, `post_content`, `post_excerpt` — field ids
- `post_status`, `post_category`, `post_custom_fields` — map form fields

### quiz (scored) — requires the separate "Formidable Quizzes" add-on (Business+)

This is a distinct add-on (`formidable-quizzes` plugin) from core Formidable's documented "build your own quiz with calculations" approach (see the alternative below). One `create-form-action` call configures a working scored quiz — it runs the action's own `update()`, which inserts the `quiz_score` field the form needs.

**Full `post_content`, ready to send:**
```json
{
  "event": ["create", "update"],
  "quiz_type": "scored",
  "show_result": "score",
  "negative_score": "",
  "enable": ["457", "458"],
  "quiz": {
    "457": {"id": "457", "score": "10", "corrects": ["Paris"]},
    "458": {"id": "458", "score": "10", "corrects": ["Pacific"]}
  },
  "conditions": {"send_stop": "send", "any_all": "any"}
}
```

- `enable` — the question field IDs included in scoring. A field is only counted toward the maximum score when it appears here **and** has a `quiz` entry.
- `quiz` — one entry per scored question. The **inner `id` is what matters**: scoring looks a question up by `id`, never by the outer key. The add-on rewrites the outer keys to its own sequence on every save (that is deliberate — it strips field IDs out of keys so they survive import), so keying by field ID as above is fine and reading back different keys is not corruption. Do not try to reconstruct the key scheme.
  - `score` — points awarded for this question when answered correctly.
  - `corrects` — array of the correct option's underlying VALUE (not label) for radio/dropdown/checkbox fields, or the literal correct text for text fields. Use meaningful values (`value: "Paris"` matching `label: "Paris"`); reusing one encoded value across questions still matches, but makes the wp-admin "Scored Quiz" panel show numbers where answer text belongs.
  - Reading the action back may show placeholder entries for non-question fields (`{"id":"456","score":"1","compare_method":"equal","corrects":[""],"max_score":"1"}`). Harmless — leave them, and don't construct them yourself.
- `show_result` — **not a boolean.** Valid values: `""` (use default settings), `"score"`, `"user_answers"`, `"correct_answers"`. Anything else falls through to the score display rather than the value you intended, so send one of these.
- Keep the field IDs in `enable` and in each `quiz` entry's `id` consistent with the form's real field IDs. Either string or integer form works.
- `update-form-action` merges `post_content` per top-level key, so sending just `{"show_result": "user_answers"}` leaves `quiz` and `enable` intact. If you need to change the questions themselves, send the whole `quiz` map — a merge replaces that key wholesale rather than merging inside it.
- The add-on injects its own read-only `quiz_score` field (type `quiz_score`, not creatable via `create-field`) when the action is created. Its entry meta is `{"<field_key>": "80/100", "<field_key>-value": "80"}` — use the field key alone (e.g. `[gafp2]`) in shortcodes/graphs/stats for the `"80/100"` display or for `frm-stats`/`frm-math`, which read the numeric prefix.
- **Rescoring existing entries**: scoring only fires on the events listed in `event`. To backfill entries created before the action existed, include `"update"` in `event`, then `update-entry` each one resending its question-field answers — that recompute is what updates the score field. Writing the quiz_score field directly does not stick; the add-on overwrites it from the answers on save.
- Verify with a real browser submission (fill, submit, then read the entry via `list-entries`) before calling a quiz done — the score is computed at submit time, so a config error shows up there and nowhere earlier.

#### Alternative: core Formidable's documented calc-based quiz (no add-on required, always reliable)

Formidable's own KB (`how-to-create-a-quiz-form`) describes a simpler, fully-documented, non-add-on approach:
1. Radio/checkbox questions with separate label/value pairs: correct answer's value = point value (e.g. `1`), wrong answers' value = `0`.
2. A read-only `number` field with `field_options.calc` summing the question field IDs, e.g. `"calc": "[457]+[458]+[459]"`.
3. Confirmation message referencing the calc field, with `[if x greater_than_or_equal_to="N"]Pass[else]Fail[/if x]` for pass/fail text.

This is simpler and has no known bugs, but only use it when the user hasn't specifically asked for the native Quiz add-on. **Known limitation of calc fields**: they only compute client-side via JS on real browser submissions — entries created directly via the `create-entry`/`update-entry` MCP abilities do NOT get calc fields populated automatically; you must compute and set them explicitly when seeding sample data. Also: Formidable's calc engine only reliably evaluates to numbers — a string ternary (`? "Pass" : "Fail"`) silently fails/evaluates to `0`, not the string; use a numeric flag (`1`/`0`) and a `[if]` conditional for text output instead.

### quiz_outcome (personality/outcome)
One action per outcome; `conditions` is an **array** of rule objects (not object form)

## Views (post_type=frm_display)

Display submitted entries. Layout in `<content>` as box JSON or `frm_dyncontent`.

Key postmeta:
- `frm_form_id` — source form id
- `frm_type` — `"id"` (single) | `"all"` (listing) | `"dynamic"`
- `frm_show_count` — `"all"` | `"one"` | `"dynamic"`
- `frm_grid_view` / `frm_table_view` — layout mode
- `frm_options` JSON — `page_size`, `limit`, `grid_column_count`, grid gaps/classes

View shortcodes:
- `[field_key]` — output field value
- `[if field_key]...[/if field_key]` — conditional block
- `[frm-stats id=field_key type=star]` — aggregates
- `[detaillink]`, `[editlink]`, `[deletelink]`, `[created-at]`

## Styles (post_type=frm_styles)

Style JSON key groups (all CSS strings):
- Form/layout: `theme_css`, `center_form`, `form_width`, `form_align`, `border_radius`
- Colors: `title_color`, `label_color`, `text_color`, `border_color`, `bg_color`, `submit_bg_color`, error/success/disabled variants
- States: `*_active`, `*_error`, `*_disabled`, `*_hover`
- Sections: `section_*`, `collapse_icon`, `repeat_icon`
- Custom: `custom_css`, `enable_style_custom_css`, `use_base_font_size`

Colors are hex without `#` (`"2563eb"`) or `rgb()`/`rgba()` strings.

## Global Shortcodes / Placeholders

- Form/site: `[form_name]`, `[form_description]`, `[sitename]`, `[admin_email]`, `[get param=...]`
- Field values: `[123]` or `[field_key]` in emails/actions
- Custom HTML: `[id]`, `[key]`, `[field_name]`, `[input]`, `[required_label]`, `[error]`, `[if description]...[/if description]`

## "Other" Write-In Option for Choice Fields

Choice fields (radio, checkbox, dropdown) can include an "Other" option for custom values.

**Critical:** The option key MUST start with `"other_"` — Formidable's `is_other_opt()` checks the key prefix.

**Format:** Use a **keyed object**, NOT an array:
```json
{
  "dog": {"label":"Dog","value":"Dog"},
  "other_1": {"label":"Other","value":"Other"}
}
```

**Don't use array format** — it loses the key:
```json
[{"label":"Dog"}, {"label":"Other"}]  // ❌ Won't work
```

**Setup:**
1. Pass options as a keyed object with at least one key starting with `"other_"`
2. Set `"other":"1"` in field_options
3. Formidable renders a hidden text input (class `frm_other_input`, hidden with `frm_pos_none`)
4. JavaScript shows/hides it when "Other" is selected

## Gotchas & Best Practices

1. JSON in CDATA: escape `"` as `\"`, write `/` as `\/`
2. Choice fields with "Other": use keyed object format; key must start with `"other_"`
3. Choice fields without "Other": can use array format
4. For a working total: use a `total` field OR a `read_only` number with calc
5. Functional forms should include `on_submit` (confirmation) + `email` (notification) actions
6. Repeatable sections: divider with `"repeat":"1"`, child fields set `"in_section": <divider id>`
7. Multi-page forms: use the `break` field type for page breaks
8. Quantity fields shown conditionally when a product is selected
9. Product choices include `price` in options
