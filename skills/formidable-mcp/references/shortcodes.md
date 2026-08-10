# Shortcodes

Read this when: composing email/confirmation form-action content, writing View content, building redirect URLs or field default values, or embedding forms/Views/stats/graphs on pages — and you need to know exactly which Formidable shortcodes are valid in that context and their full syntax.

Conventions used throughout:
- `x` = a field ID or field key; both work in every shortcode here. **Prefer keys in shortcode content** (`[formidable id=x]`, `[display-frm-data id=x]`, field-value shortcodes) — since keys are derived from field names, `[preferred-shift]` says what it points at where `[13756]` does not. This is a readability preference: Formidable's importer rewrites ID shortcodes in content as well, so IDs are not "less portable" here.
- **This preference stops at shortcodes.** Stored settings that hold a field reference — `hide_field` conditional logic, `calc`, `form_select`, `in_section`, view `order_by`/`where`/`date_field_id`, quiz `enable` — require the numeric field ID and silently ignore a key. See repeaters.md § "Keys in CONTENT, Numeric IDs in SETTINGS". Entry payloads are the forgiving case — they take either form at every level.
- **In View content, always reference fields by field KEY (e.g. `[lwrli]`), never by field name** (see entries-and-views.md). Field IDs also work. Field names produce blank output.
- In email/confirmation actions, field IDs and keys are interchangeable; the built-in customization panel inserts IDs.
- **Prefer dashes over underscores in shortcode tags** where both work — `[created-at]`, not `[created_at]`. Exactly seven tags support it, attributes never do, and conditional closing tags reject it; see § "Dashes vs underscores" in section 2 before applying this anywhere.
- Everything here traces to the official Formidable knowledgebase. Items marked *(unconfirmed)* were not verifiable in the KB — do not treat as fact.
- See actions.md for creating email/confirmation actions via MCP (this file covers the shortcode *content* that goes inside them).

## Quick-Reference Master Table

Contexts: **Page** = page/post/widget · **View** = View content · **HTML** = form Customize HTML · **Email** = email action body/subject/recipients · **Conf** = confirmation message / redirect URL · **DV** = field Default Value box.

| Shortcode | Purpose | Page | View | HTML | Email | Conf | DV | Pro? |
|---|---|---|---|---|---|---|---|---|
| `[formidable id=x]` | Publish a form | ✓ | ✓ | – | – | – | – | No (some params Pro) |
| `[display-frm-data id=x]` | Publish a View | ✓ | ✓ (nested) | – | – | – | – | Yes (Views) |
| `[frm-entry-links id=x]` | Editable entry list | ✓ | – | – | – | – | – | Yes |
| `[formresults id=x]` | Entries table | ✓ | – | – | – | – | – | Yes |
| `[frm-show-entry id=x]` | Single-entry table (x = entry ID) | ✓ | ✓ | ✓ (HTML fields) | – | – | – | Yes |
| `[frm-search]` | Front-end search bar | ✓ | ✓ (Before Content) | – | – | – | – | Yes |
| `[x]` field value | Saved value of field x | – | ✓ | – | ✓ | ✓ | – | No |
| `[x show=... sep=... format=...]` | Field formatting options | – | ✓ | – | ✓ | ✓ | – | Some (clickable, truncate) |
| `[id]` / `[key]` | Entry ID / entry key (⚠ field ID/key inside form HTML) | – | ✓ | ✓ (field meaning) | ✓ | ✓ | – | No |
| `[ip]`, `[created-at]`, `[updated-at]`, `[updated-by]`, `[post-id]`, `[form_name]` | Entry metadata | – | ✓ | – | ✓ | ✓ | `[ip]` only | No |
| `[browser]`, `[referrer]` | Submitter user agent / referring URL | – | – | – | ✓ | – | – | No |
| `[siteurl]`, `[sitename]` | Site URL / site title | – | ✓ | – | ✓ | ✓ | – | No |
| `[admin_email]`, `[default-email]`, `[default-from-email]` | Admin/global-settings emails | – | – | – | ✓ (incl. recipients) | – | – | No |
| `[admin-link]` | Edit-entry link in wp-admin — **email bodies only** | – | – | – | ✓ | – | – | No |
| `[default-message]` | Dynamic all-fields table | – | – | – | ✓ | ✓ | – | No |
| `[default-html]` / `[default-plain]` | Static snapshot of default message | – | – | – | ✓ (editor insert) | – | – | No |
| `[if x]...[/if x]`, `[else]` | Conditional content | – | ✓ | `[if description]` only | ✓ | ✓ (+ redirect URLs) | ✓ (`[if get]`) | Yes |
| `[frm-condition]...[/frm-condition]` | Compare two dynamic values | ✓ | ✓ | – | ✓ | ✓ | ✓ | Yes |
| `[frm_gated_content id=x]` | Gated-content access links (§5; on the token-generating form only) | – | – | – | ✓ | ✓ | – | No (`expired_time` Pro) |
| `[foreach n]...[/foreach n]` | Loop repeater rows | – | ✓ | – | ✓ | – | – | Yes |
| `[editlink]` | Edit link (auto entry ID) | – | ✓ | – | – | – | – | Yes |
| `[deletelink]` | Delete link (auto entry ID) | – | ✓ | ✓ | – | – | – | Yes |
| `[detaillink]` | View detail-page URL — **Views only** | – | ✓ | – | – | – | – | Yes (Views) |
| `[evenodd]` | Alternating odd/even class | – | ✓ | – | – | – | – | Yes (Views) |
| `[entry_count]` | Total entries in View (Before/After Content) | – | ✓ | – | – | – | – | Yes (Views) |
| `[event_date]`, `[end_event_date]` | Calendar-View event dates | – | ✓ (calendar) | – | – | – | – | Yes (Views) |
| `[frm-entry-edit-link id=x]` | Edit link, explicit entry ID | ✓ | ✓ | – | – | – | – | Yes |
| `[frm-entry-delete-link id=x]` | Delete link, explicit entry ID | ✓ | – | – | – | – | – | Yes |
| `[frm-entry-update-field]` | AJAX single-field update link | ✓ | ✓ | – | – | – | – | Yes |
| `[frm-field-value field_id=x]` | Pull one value from an entry | ✓ | ✓ | – | ✓ | – | ✓ | Yes |
| `[frm-stats id=x type=...]` | Field statistics | ✓ | ✓ | ✓ (fields) | ✓ | – | ✓ | Yes |
| `[frm-math]...[/frm-math]` | Math on saved data | ✓ | ✓ | – | ✓ | – | ✓ | *(Pro not explicitly stated)* |
| `[frm-graph fields=x]` | Graphs | ✓ | ✓ | ✓ (HTML fields) | – | – | – | Yes |
| `[frm-set-get name="v"]` | Set a param for later `[get]` | ✓ (before form/View) | ✓ | – | – | – | – | *(Pro not explicitly stated)* |
| `[get param="name"]` | Read URL / passed param | – | ✓ (content+filters) | ✓ (submit) | ✓ | ✓ | ✓ | Yes |
| `[date]`, `[time]`, `[email]`, `[login]`, `[display_name]`, `[first_name]`, `[last_name]`, `[user_id]`, `[user_role]`, `[user_meta]`, `[post_title]`, `[post_author_email]`, `[post_meta]`, `[server]`, `[auto_id]` | Dynamic default values (also resolve in action content) | – | – | ✓ | ✓ | ✓ | ✓ | No |
| `[input]`, `[field_name]`, `[description]`, `[label_position]`, `[required_label]`, `[required_class]`, `[error_class]` | Field-box HTML tags | – | – | ✓ (only) | – | – | – | No |
| `[form_name]`, `[form_description]`, `[form_key]` | Before/After Fields boxes | – | – | ✓ (only) | – | – | – | No |
| `[button_label]`, `[button_action]` | Submit button box | – | – | ✓ (only) | – | – | – | No |

---

## 1. Field-Value Shortcodes & Formatting Parameters

The workhorse of email bodies, confirmation messages, and View content: `[x]` outputs the saved value of field `x` (field ID or key). Blank fields output nothing — wrap in conditionals (section 3) to hide labels for blank fields.

Common pattern in emails: `[25 show="field_label"]: [25]` → `What is your name?: John`

### All formatting parameters (`/knowledgebase/advanced/`)

Contexts: Views, email notifications, success/confirmation messages, post/page content, form HTML, View detail pages — unless a narrower context is noted.

| Option | Syntax | Notes |
|---|---|---|
| Separator | `[x sep=", "]` | Custom delimiter for checkbox/multi-value fields. Default comma. `sep` is a *parameter*, not a standalone `[sep]` shortcode. List example: `<ol><li>[x sep="</li><li>"]</li></ol>` |
| Date format | `[x format="d-m-Y"]` | PHP `date()` characters. Works with date fields, `[created-at]`, `[updated-at]`. `[x format="D, F j, Y"]` → "Mon, September 21, 2016"; `l, M d, y` → "Monday, Sep 21, 16" |
| Field label | `[x show="field_label"]` | The field's label instead of the value |
| Field description | `[x show="description"]` | Field description / HTML content |
| Saved value | `[x show="value"]` | Saved value instead of displayed label — essential for fields using **separate values** |
| No auto-P | `[x wpautop=0]` | Remove automatic `<p>` tags (paragraph/rich-text fields). Contexts: Views, posts, email notifications |
| Clickable links | `[x clickable=1]` | Turn URLs/emails into clickable links. **Premium** |
| Remove links | `[x links=0]` | Strip hyperlinks from output |
| Sanitize | `[x sanitize=1]` | Lowercase + spaces→dashes (for HTML classes/IDs) |
| Remove accents | `[x remove_accents=1]` | Strip accent marks. Combine: `[x remove_accents=1 sanitize=1]` |
| Sanitize URL | `[x sanitize_url=1]` | URL-safe encoding. **Auto-applied to field shortcodes inside redirect URLs**; disable with `[x sanitize_url=0]`; preserve ampersands with `[x sanitize_url=0 keepjs=1]`. Example: `your-site.com/?pass_field=[x sanitize_url=1]` |
| Truncate | `[x truncate=40]` | Limit to N characters. **Premium.** Custom link text: `[x truncate=100 more_text="Read More"]`; remove the "more" link: `[x truncate=100 no_link=1]` |
| Time ago | `[x time_ago=3]` | Elapsed time from a saved date. Units: `y`/`year`, `m`/`month`, `w`/`week`, `d`/`day`, `h`/`hour`, `minute`, `s`/`seconds`, or a number 1–7 = how many units to show. `[created-at time_ago=3]` → "2 weeks 1 day 23 hours". **Works only in Views, emails, and success messages — not form calculations** |
| Number format | `[x decimal=2 dec_point="." thousands_sep=","]` | Currency: `$[x decimal=2 dec_point="." thousands_sep=","]`. European: `[x decimal=2 dec_point="," thousands_sep="."]` |
| Strip HTML | `[x striphtml=1]` | Removes all HTML tags |
| Keep JS | `[x keepjs=1]` | Preserves JavaScript/iframes (iframe display needs a custom PHP filter) |

### Dynamic (linked-entry) field lookups

Dynamic fields (Pro) store a value linked to a source entry; it auto-updates if the source changes. Contexts: confirmation messages, email notifications, Views. Replace `x` with the Dynamic field's ID:

| Shortcode | Result |
|---|---|
| `[x]` | Linked entry's value as configured |
| `[x show="y"]` | Field `y` from the **linked** entry |
| `[x show="created-at"]` | Creation date of the linked entry |
| `[x show="id"]` | Linked entry's ID |
| `[x show="user_email"]` | Email of the linked entry's submitter — supports all User ID `show=` options (section 11) |
| `[x show="label"]` | Option label text (separate values/labels) |
| `[x show="y" show_info="z"]` | Three-level lookup: `y` = a Dynamic field in the linked form, `z` = field ID in that third form (or `created_at`, `id`, `user_email`) |

Conditional form: `[if x show=y like="something"]...[/if x]`.

---

## 2. Entry Metadata & Site Shortcodes

Available in both Views and form-action content (email/confirmation) unless noted (source: `/knowledgebase/insert-fields/`, `/knowledgebase/email-notifications/`).

| Shortcode | Output |
|---|---|
| `[id]` | Entry ID. ⚠ Inside form Customize HTML, `[id]` means the *field's* ID instead (section 10) |
| `[key]` | Entry key. Same caveat inside Customize HTML |
| `[ip]` | Submitter's IP address (public IPv4) |
| `[created-at]` | Submission date/time. Default rendering like "2021-09-20 at 9:05 pm". `[created-at format='H:i:s']` → "21:05:04"; `[created-at format='g:i a']` → "9:05 pm". `[created_at]` is the same tag (see § "Dashes vs underscores") |
| `[updated-at]` | Last-updated date/time (relevant when editing enabled); same `format=` support |
| `[updated-by]` | Display name of the user who last edited the entry |
| `[post-id]` | ID of the post created by the entry (only if the form creates posts) / post containing the form |
| `[form_name]` | Name of the form |
| `[siteurl]` | WordPress site URL (Settings → General) |
| `[sitename]` | Site/blog title |
| `[browser]` | User agent / browser info — documented on the email-notifications page (email context) |
| `[referrer]` | Referring URL — email context |
| `[admin_email]` | WordPress admin email (Settings → General). Usable in To/CC/BCC/From/Reply-To |
| `[admin-link]` | Link to edit the entry in wp-admin. **Documented only on the email-notifications page — treat as email-body-only.** Not a general/View helper |
| `[default-email]` | Admin email set in Formidable → Global Settings |
| `[default-from-email]` | Default sender from Global Settings |

### Dashes vs underscores

Both engines normalize a dashed tag to its underscored form before resolving it, so either spelling renders identically — **this is not a Pro-only feature**:

- Lite, `FrmFieldsHelper::get_shortcode_value()` — a blanket `str_replace( '-', '_', $tag )`.
- Pro, `FrmProContent::maybe_replace_dash()` — a whitelist: `created-at`, `updated-at`, `created-by`, `updated-by`, `post-id`, `parent-id`, `is-draft`.

Pro's whitelist is the narrower of the two, so treat those seven as the portable set.

**Prefer the dashed spelling in shortcode content.** It reads better, and it is what Formidable's own UI emits (the Dynamic-field `show=` dropdown writes `show="created-at"`; Lite reserves `created-at`, not `created_at`, as a field key in `prevent_numeric_and_reserved_keys()`).

Three limits, all verified by rendering against a live entry:

1. **Only those seven tags.** Every other underscored tag (`[form_name]`, `[user_agent]`, `[post_status]`…) is outside Pro's whitelist — a dash there survives into the lookup and the shortcode prints literally. Parity is what the whitelist buys: where a tag resolves at all, both spellings resolve the same; where it does not, neither spelling helps.
2. **Tag position only.** Attribute names and values are matched exactly and must stay underscored: `order_by="created_at"`, `x_axis="created_at"`, `created_at_greater_than="-1 month"`, and the magic comparison value in `[if updated_at greater_than="created_at"]` (compared with `===` against `'created_at'`). This is separate from stored settings, which are not shortcodes at all and always use `created_at` (view `order_by`, API payloads, DB columns).
3. **⚠ Conditionals: the closing tag does not accept a dash.** `check_conditional_shortcode()` builds the closer from the *already-normalized* tag, so it searches for `[/if created_at]`:

   ```
   [if created-at]…[/if created-at]   ✗ renders literally, the whole block leaks to the page
   [if created-at]…[/if]              ✓ the bare closer is the documented fallback
   [if created_at]…[/if created_at]   ✓ matched pair
   ```

   Keep conditionals underscored on both ends — a matched pair survives someone later editing one half.

### `[default-message]` — dynamic all-fields table (email + confirmation)

Inserts a dynamically generated table of all completed fields (labels + values). Virtual/hidden field values ARE included.

| Parameter | Example | Effect |
|---|---|---|
| `plain_text="1"` | `[default-message plain_text="1"]` | Remove HTML table formatting (text only) |
| `user_info="1"` | `[default-message user_info="1"]` | Append IP address, browser (user agent), and referring URL |
| `include_blank="1"` | `[default-message include_blank="1"]` | Include fields left blank (normally omitted) |
| `include_extras="page, section, html"` | `[default-message include_extras="section, html"]` | Include normally-excluded field types: page breaks, section headings, HTML fields |
| `include_fields="10,15"` | | Only show listed fields (IDs or keys) |
| `exclude_fields="10,15"` | | Hide listed fields (IDs or keys) |
| `direction=rtl` | `[default-message direction=rtl]` | Reverse column order (right-to-left) |
| `font_size="25px"` | | Table font size |
| `text_color="b642f4"` | | Text color (hex, no `#`) |
| `border_width="1px"` | | Table border width |
| `border_color="000000"` | | Border color (hex, no `#`) |
| `bg_color="ffffff"` | | Background color (hex) |
| `alt_bg_color="eeeeee"` | | Alternating row background (hex) |
| `array_separator=", "` | | Separator for checkbox/multi-select values |
| `format="text"` / `"json"` / `"array"` | | Alternate output format |

Combined example: `[default-message plain_text="1" include_blank="1"]`

### `[default-html]` / `[default-plain]`

Insert the *current* default message structure as **static** editable HTML / plain text into the editor — a snapshot to customize, not a dynamic shortcode. Does NOT auto-update when fields change (unlike `[default-message]`).

---

## 3. Conditionals

### `[if x]...[/if x]` (Pro)

Contexts: View content (listing + detail), email bodies/subjects/recipients, confirmation messages, **redirect URLs**, and `[if description]` inside form field HTML. Opening and closing tags must use the same field ID/key. With no comparison parameter, the condition is "field is not blank":

```
[if x]This text is hidden if field x is blank.[/if x]
```

#### All 10 comparison operators

| Parameter | Meaning | Example |
|---|---|---|
| *(none)* | Field is not blank | `[if x]content[/if x]` |
| `equals` | Exact match | `[if x equals="something"]content[/if x]` |
| `equals=""` | Field is blank | `[if x equals=""]content[/if x]` |
| `not_equal` (also `not_equals`) | Not an exact match | `[if x not_equal="something"]content[/if x]` |
| `not_equal=""` | Field is not blank | `[if x not_equal=""]content[/if x]` |
| `like` | Contains (partial match) | `[if x like="something"]content[/if x]` |
| `not_like` | Does not contain | `[if x not_like="something"]content[/if x]` |
| `greater_than` | > (numbers, dates, times) | `[if x greater_than="3"]content[/if x]` |
| `greater_than_or_equal_to` | ≥ | `[if x greater_than_or_equal_to="10"]content[/if x]` |
| `less_than` | < | `[if x less_than="-1 month"]content[/if x]` |
| `less_than_or_equal_to` | ≤ | `[if x less_than_or_equal_to="42"]content[/if x]` |

#### `[else]`

```
[if x equals="something"]Content here [else]Show this content instead.[/if x]
```

#### Date/time math

`greater_than`/`less_than` (and `_or_equal_to` variants) accept relative values: `+1 day`, `+1 week`, `+1 month`, `-1 week`, `-1 month`, and `NOW`; also `created_at` / `updated_at` as comparison values.

```
[if x less_than="NOW"]Current time is past the saved time.[/if x]
[if created_at greater_than="-1 week"]Entry was created less than 1 week ago[/if created_at]
[if updated_at greater_than="created_at"]Updated at greater than [updated_at][/if updated_at]
```

#### Combining & nesting

Different parameters combine with AND logic in one tag:

```
[if x greater_than="3" less_than="5"]Content[/if x]
```

Nesting is allowed (use different field IDs so tags pair correctly):

```
[if 300 greater_than="0"][if 301 equals="enabled"]Your content here[/if 301][/if 300]
```

#### `show=` inside conditionals

Separate-values fields (radio/checkbox/dropdown) — compare the saved value, not the label:

```
[if x show=value equals="black shirt 25"]Show content[/if x]
```

Dynamic fields — compare a field of the linked entry:

```
[if x show=y like="something"]Content[/if x]
```

#### Non-field subjects

```
[if created_at]...[/if created_at]     [if updated_at]...[/if updated_at]
[if created_by]...[/if created_by]     [if updated_by]...[/if updated_by]
[if is_draft]Shown when the entry is a draft.[/if is_draft]
[if is_draft equals=0]Shown when NOT a draft.[/if is_draft]
[if get param="something"]...[/if get]
[if entry_position ...]...[/if entry_position]        (Views only)
```

#### `[if get]` — URL parameter conditionals

Closing tag is `[/if get]`.

```
[if get param="something" equals="hello"]Shown when the URL contains ?something=hello[/if get]
[if get param="something"]Shown when ?something= has any value[/if get]
```

Conditional default value with fallback (field Default Value box):

```
[if get param="param_name"][get param="param_name"][else]Show this content instead[/if get]
[if get param="fname"][get param="fname"][else][first_name][/if get]
```

Compare a **field value** to a URL parameter (`equals="param"` is literal; `param=` names the URL key):

```
[if x equals="param" param="level"]Shown when field x matches the ?level= value[/if x]
```

#### `entry_position` (Views only)

Position of the entry within the View's listing.

```
[if entry_position equals=3]Include an ad here[/if entry_position]
[if entry_position equals=1]<div class="featured">This is the first entry.</div>[/if entry_position]
[if entry_position less_than=4]<div class="featured">This is featured.</div>[/if entry_position]
[if entry_position not_equal=1], [/if entry_position][100]      <!-- comma-separated list, no stray comma -->
```

Every Nth entry (via frm-condition + frm-math):

```
[frm-condition source=frm-math decimal=1 content="[entry_position] % 3" equals="0"]Incremental content here
```

#### Worked examples (verbatim from docs)

Conditional redirect URL (Form Settings → On Submit → Redirect):

```
http://[if x equals="Yes"]site-a.com[/if x][if x equals="No"]site-b.com[/if x]
http://[if x equals="editor"]site.com/editor[else]site.com/customer[/if x]
```

File-upload conditionals (file fields save URLs, so use `like`):

```
[if 12 like="example.jpg"]Show this content[/if 12]
[if 12 like=".jpg"]Shown when the file URL contains .jpg[/if 12]
```

Quiz feedback:

```
[if x equals="something"]Correct[/if x]
[if x not_equal="something"]Incorrect. The correct answer is something.[/if x]
```

Conditional HTML attribute / CSS class:

```
<td [if 25 equals="red"]style="background-color:red"[/if 25]>[25]</td>
<span class="frm_show_[if 100 equals=Passed]green[/if 100][if 100 equals=Failed]red[/if 100]">[100]</span>
```

Hide a label when the field is blank (typical email pattern):

```
[if 25]Name: [25]<br>[/if 25]
```

#### Limitations / gotchas

1. **A parameter can appear only once per tag.** `[if x like="a" like="b"]` does NOT work — use two `[if]` blocks or nesting.
2. `[if get]` **cannot** be combined with `equals=param` — no built-in way to compare two URL parameters.
3. `[if get]` cannot compare against View-generated values — use `[frm-condition]`.
4. Checkboxes: use `like="value"` to match one selected option.
5. **Stray blank lines:** put the opening `[if]` tag at the end of the previous line so hidden blocks don't leave gaps:

```
Name: [990][if 992 equals="A"]
Option A[/if 992][if 992 equals="B"]
Option B[/if 992]
```

6. Deeper custom logic: `frmpro_fields_replace_shortcodes` hook.

### `[frm-condition]` — Compare Two Values (Pro)

Contexts: Views, pages/posts, emails, default values — anywhere shortcodes are processed. Unlike `[if x]`, it can compare two dynamic/computed values (including values generated inside a View), and works **outside** Views.

```
[frm-condition source=SOURCE comparison_operator=VALUE]content shown when true[/frm-condition]
```

| Parameter | Purpose |
|---|---|
| `source` | Where the first value comes from: the name of any other shortcode — `frm-field-value`, `frm-stats`, `frm-math`, a custom shortcode — or `param` |
| `equals` / `not_equal` / `greater_than` / `less_than` / `like` / `not_like` | The six documented operators (`contains` is NOT an operator here) |
| `param` | URL parameter name, when `source=param` |
| `content` | Content that would normally go *inside* the source shortcode (e.g. the frm-math expression) |
| *(passthrough)* | Any parameter of the source shortcode may be included (`field_id`, `entry`, `user_id`, `id`, `type`, `decimal`, …) and is passed to it |

Worked examples (verbatim):

```
[frm-condition source=frm-field-value field_id=391 entry=[id] equals="[390]"]your content here[/frm-condition]

[frm-condition source=frm-field-value field_id=304 entry=[id] like="[305]"]Is member state[/frm-condition]
[frm-condition source=frm-field-value field_id=304 entry=[id] not_like="[305]"]Is not member state[/frm-condition]

[frm-condition source=frm-field-value field_id=210 entry=[id] greater_than="[211]"]Show if greater than first field[/frm-condition]
[frm-condition source=frm-field-value field_id=210 entry=[id] less_than="[211]"]Show if less than first field[/frm-condition]

[frm-condition source=frm-stats id=text-field type=count greater_than=10][frm-stats id=text-field type=count][/frm-condition]

[frm-condition source=frm-field-value field_id=72 user_id=current less_than=param param=total_cost]You've exceeded your monthly limit.[/frm-condition]

[frm-condition source=param param=color]shown if the color param is set[/frm-condition]
[frm-condition source=param param=color equals="yellow"]shown if ?color=yellow[/frm-condition]

[frm-condition source=frm-math content="[100] * [102]" greater_than="10"]show if result is greater than 10[/frm-condition]

[frm-condition source=frm-stats id=100 type=count user_id=current greater_than=0]Registration form: completed[/frm-condition]
[frm-condition source=frm-stats id=100 type=count user_id=current equals=0]Registration form: needs to be filled out[/frm-condition]
```

Gotchas:
- Standard WordPress shortcodes (like frm-stats) **can't be used inside the `content` param** — pass them via `source` instead.
- `[id]` resolves at View render time when comparing within the same entry.
- Test the inner stat/math shortcode on its own before wrapping it in a condition.

---

## 4. Email Action Content (Send Email)

See actions.md for creating the action itself (`email_to`, `email_message`, `email_subject`, `event` keys). This section covers what goes *inside* those settings.

### Recipients — To / CC / BCC / Reply-To

Accepted formats — **only these two** (after shortcode resolution): 

- `email@example.com`
- `Name <email@example.com>` — "The only formats that can be used are `name <email@example.com>` and `email@example.com`"

Building recipients:

- Multiple, comma-separated: `email1@example.com, email2@example.com`
- Submitter's email field: `[112]` (an Email Address field's ID) — this is how you build an **autoresponder** (To = the submitter's email field)
- User ID field: `[113 show="user_email"]`
- Dropdown/radio with separate values holding emails: `[x show="value"]`
- Name + email fields combined: `[114] <[112]>` — Reply-To example from the docs: `[5092] <[5093]>` (name field 5092, email field 5093)
- `[admin_email]` and `[default-email]` work as recipients
- Conditionals may switch recipients, as long as the final resolved text is still a valid email format

Gotchas: any other format breaks sending. Programmatic routing hook: `frm_to_email`.

### Subject line

- Supports field and metadata shortcodes: `New request from [25]`
- If left blank, the default is: `[Form name] Form submitted on [Your site name]`
- Keep it plain text — no HTML in subjects

### Message body

- Valid: field shortcodes with all formatting params (section 1), entry metadata & site shortcodes (section 2), `[default-message]`/`[default-html]`/`[default-plain]`, conditionals (section 3), `[foreach]` for repeaters (section 6), `[frm-stats]`/`[frm-math]` (section 8), dynamic-default shortcodes (section 9), `[admin-link]`.
- Field shortcodes for empty fields output nothing; hide their labels with `[if 25]Name: [25]<br>[/if 25]`.
- Virtual Field values can be inserted via their field shortcode even though they never display on the form; they are also included in `[default-message]`.

### Writing readable HTML email bodies (MCP-authored)

Goal: an `email_message` a non-developer can open and edit later. Verified behavior of the send pipeline (`FrmEmail::set_message()` → `add_autop()`):

- **HTML emails (the default, `plain_text` off) get `wpautop()` applied to the whole body at send time.** So you can — and should — write clean, multi-line, indented HTML: blank lines between blocks become `<p>` paragraphs, and single newlines inside a run of inline text become `<br>`. You do **not** need to hand-write `<p>` wrappers or `<br>` for paragraph spacing in MCP-authored bodies. (The KB's "use `<br>`, hard returns aren't line breaks" note describes the rich-text editor, not the raw HTML you send through MCP, which is autop'd.)
- **`wpautop` is block-aware**, so a readable indented `<table>` / `<tr>` / `<td>` / `<h2>` / `<div>` structure passes through untouched — no stray tags inside your table. Verified: a hand-indented notification table rendered exactly as written.
- **Gotcha — never wrap a rich-text/paragraph/textarea field shortcode in your own block tag.** Those field *values* are themselves auto-paragraphed, so `<p><strong>Notes:</strong> [ksir6]</p>` renders as invalid nested `<p>…<p>value</p></p>` with a stray `</p>`. Fixes (both verified): add `wpautop=0` to the field — `<p><strong>Notes:</strong> [ksir6 wpautop=0]</p>` — to keep it inline, or leave the field unwrapped on its own line and let autop paragraph it. A plain `<div>` wrapper does **not** fix it.
- **The body round-trips byte-for-byte through the MCP** — indentation, newlines, `[if]` conditionals, and inline styles are stored exactly as sent (no kses, slashing, or autop at write time; autop happens only at send). So what you write is what a later editor sees.
- **Email HTML must use inline `style=` attributes** — email clients strip `<style>` blocks and ignore external/linked CSS. This is the opposite of Views (where you should prefer the Custom CSS setting — see entries-and-views.md "Styling views"). For emails, keep readability by using a simple structure, minimal inline styles, and `[default-message]` for a plain all-fields table when you don't need a custom layout.

### HTML vs plain text gotchas

- Emails are HTML by default; the rich-text editor supports images, links, fonts, inline CSS — but email-client HTML support is limited.
- "Send Emails in Plain Text" (per-action setting) makes hard returns work and stops HTML rendering. Pair with `[default-message plain_text="1"]`. In plain-text mode the body is run through `strip_tags()`, so any HTML you wrote is discarded — don't mix the two.
- Does NOT work in emails: JavaScript, forms, most CSS layout; `time_ago` works only in Views/emails/success messages; **Views-only shortcodes (`[detaillink]`, `[entry_count]`, `[event_date]`, `[editlink]`, …) do not resolve in emails** — use `[admin-link]` for a backend entry link, or build a front-end link manually, e.g. `[siteurl]/entry-page/?entry=[key]`.
- Hooks: `frm_rich_text_emails`, `frm_email_message` (preheaders), `frm_notification_attachment` (attachments; file uploads attach via the action's "Attach file uploads" option).

### Other actions

The same field/metadata shortcodes resolve in other form-action settings (Create Post action fields, webhook/API payloads, registered action text inputs). The Form Action Automation add-on schedules email/SMS actions without changing shortcode syntax (`frm_autoresponder_time`).

---

## 5. Confirmation Actions (On Submit)

Types: **Show Message**, **Redirect to URL**, **Show Page Content** (in actions.md: `success_action` = `"message"` / `"redirect"` / `"page"`). Trigger: entry created (Lite) / created or updated (Pro). With no confirmation action, the default message from Formidable → Global Settings → Messages is used.

### Show Message

- Rich text editor; HTML and inline CSS supported.
- All field shortcodes (`[25]`, `[field_key]`, show/format params), entry metadata (`[id]`, `[key]`, `[created-at]`…), site shortcodes (`[siteurl]`, `[sitename]`…), and conditionals work here. Virtual Field values can be displayed or used in conditionals.
- Field IDs are discoverable via the three-dot (customization) menu in the message editor.
- Option to show a blank form below the message for repeat submissions.
- Styling hook: `frm_main_feedback`; content filter: `frm_success_filter`.

### Redirect to URL

- **Passing field values in the query string:** `https://example.com/page/?name=[25]&email=[26]` (IDs or keys). **`sanitize_url=1` is applied automatically to field shortcodes inside redirect URLs** — values are URL-encoded without extra work. Disable with `[x sanitize_url=0]`.
- `[siteurl]` for portable URLs: `[siteurl]/page-1/`
- Redirect path from a separate-values field: `[siteurl]/[1222 show=value]` — saved values must exactly match page slugs.
- Entry metadata works: `[siteurl]/thanks/?entry=[id]` or `?entry=[key]` (pair with `[get param]` / `[frm-field-value entry="..."]` on the target page).
- **Delay redirect:** toggle "Delay redirect and show message", set seconds (default 8), customize the interim message (shortcodes work in it). Filter: `frm_redirect_delay_time`.
- **Conditional redirects**, two mechanisms:
  1. Action-level conditional logic (Pro): multiple confirmation actions with All/Any rule groups; first matching redirect action wins.
  2. Inline conditionals in the URL: `http://[if 45 equals="Yes"]site-a.com[/if 45][if 45 equals="No"]site-b.com[/if 45]`

### Multiple-action behavior & gotchas

- Show Message + Show Page Content → both display. Multiple Redirect actions → only the first matched redirect runs. Message/content mixed with redirect → messages show ~8 seconds, then redirect.
- With AJAX submission enabled, the confirmation view has no access to URL params — disable AJAX submit or use code.
- Show Page Content: disable AJAX submit so that page's JavaScript (tabs/accordions) loads.
- Filters: `frm_redirect_url`, `frm_get_met_on_submit_actions`, `frm_get_run_success_action_args`, `frm_on_submit_action_options`.

### `[frm_gated_content]` — gated-content access links

Renders access links/tokens for a **Gated Content action** (schema and token lifecycle in `actions.md`). `id` is the gated content **action post ID** (returned by `create-form-action`), not a form or entry ID.

| Shortcode | Output (all verified) |
|---|---|
| `[frm_gated_content id="10916"]` | `<ul class="frm-gated-content-list">` of `<a>` links to **all** items, labeled with the item title |
| `[frm_gated_content id="10916" item="0"]` | Single `<a>` link to one item — `item` is **0-indexed** |
| `[frm_gated_content id="10916" item="0" show="url"]` | Plain URL, no link tag (`show="url"` without `item` gives a `<ul>` of plain URLs) |
| `[frm_gated_content id="10916" show="access_token"]` | The raw token string only |
| `[frm_gated_content id="10916" show="expired_time"]` | **Pro.** Human-readable duration of the configured expiry (e.g. "2 hours"); empty when the action has no `expired_hours` |

Placement rules (why a blank output happens):

- Works **only in confirmation (On Submit) and email actions on the same form as the gated content action** — the raw token is held in a per-request cache plus a ~5-minute transient scoped to the submitting user/IP, and is never stored in the DB. Anywhere else (pages, Views, other forms, later requests) it renders empty.
- The gated action fires at priority 8, before On Submit and Send Email, so the token is always ready for these shortcodes — including after a payment redirect.
- Blank output in an email/confirmation usually means the trigger events don't match (e.g. the gated action fires on `update` but the email on `create`) or the action `id` is wrong.

---

## 6. View Content Helpers

Remember: reference fields by **field key** (or ID) in View content, never by name (entries-and-views.md).

### View-only helpers (`/knowledgebase/insert-fields/`)

| Shortcode | Purpose / syntax |
|---|---|
| `[detaillink]` | URL of the View's Detail Page for the entry: `<a href="[detaillink]">Details</a>`. If the form creates posts, links to the single post page instead. No parameters documented. **Views only** — one word, no hyphen |
| `[evenodd]` | Alternating row classes: `<div class="[evenodd]">` — odd listings get class `odd`, even get `even` |
| `[entry_count]` | Total number of entries displayed by the View. Place in the View's **Before Content or After Content** box. No parameters documented |
| `[event_date]` | Date of a repeating event (calendar Views): `[event_date format="Y-m-d"]` |
| `[end_event_date]` | End date of a recurring event |
| `[if is_draft]Draft[/if is_draft]` | Draft indicator |

### `[foreach]` — loop over repeater rows (Pro)

Contexts: View content and email bodies. Documented on the Repeater field page (`/knowledgebase/repeatable-section/`; the `/using-foreach/` URL is 404).

```
[foreach REPEATER_ID] ...row content... [/foreach REPEATER_ID]
```

`REPEATER_ID` = the Repeater (repeating section) field's ID. Field shortcodes inside the loop are **child-field** IDs, outputting the current row's value only. The closing tag must repeat the repeater ID.

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `sep` | Any string | none | Separator inserted between iterations |
| `order` | `"asc"` / `"desc"` | `asc` | Iteration direction over rows |

```
[foreach 100]
[101]: [102], [103]
[/foreach 100]
```
Output like "John Smith: Pepperoni pizza, Dr. Pepper" per row.

```
[foreach 100 sep=", "][103][/foreach 100]        → "Dr. Pepper, Water, Coca-Cola"

[foreach 5651 order="desc"]
[5653]
[/foreach 5651]
```

Table layout:

```
<table>
<tr>
<th>[101 show="field_label"]</th>
<th>[102 show="field_label"]</th>
<th>[103 show="field_label"]</th>
</tr>
[foreach 100]
<tr>
<td>[101]</td>
<td>[102]</td>
<td>[103]</td>
</tr>
[/foreach 100]
</table>
```

Without foreach, a bare child-field shortcode outputs ALL of that field's values across rows together: `[101 show="field_label"]: [101]`.

Limitation: a View built **directly from the Repeater field** (child form as data source) offers ordering/filtering that `[foreach]` inside a main-form View does not — prefer that for complex needs.

### `[editlink]` — edit link inside Views (Pro)

Auto-detects the entry ID from the View row. Requires "Allow front-end editing of entries" (Form Settings → Permissions); renders only for users with permission. Not for standalone pages — use `[frm-entry-edit-link]` there.

| Parameter | Required | Default | Notes |
|---|---|---|---|
| `page_id` | Yes (redirect editing) | none | ID of the page where the form is published |
| `label` | Optional | "Edit" | Link text. `label=0` outputs only the raw URL, no HTML |
| `class` | Optional | none | CSS class(es) |
| `title` | Optional | value of `label` | Hover text |
| `prefix` | Optional | none | **In-place editing**: replaces a container's content with the edit form. Container div id = prefix + entry ID |
| `fields` | Optional | all | Comma-separated field IDs; edit only these in place. **Only works with `prefix`** |
| `exclude_fields` | Optional | none | Fields to exclude from in-place editing. **Cannot be combined with `fields`** |
| `cancel` | Optional | "Cancel" | Cancel-link label for in-place editing |
| `start_page` | Optional | 1 | Start page for multi-page forms |

```
[editlink label="Edit" page_id=y]
[editlink label="Edit" class="my_edit_class" page_id=y]

<div id="frm_container_[id]">
Content here
</div>
[editlink label="Edit" prefix="frm_container_"]

[editlink label="Edit" prefix="frm_container_" fields="100,101,102"]
```

Gotchas: for in-place editing, place the edit link **outside** the container div; disable AJAX submission and remove CAPTCHA so updated values display immediately; rich-text HTML is stripped for non-admins (`frm_allowed_form_input_html` hook to allow more tags). A hidden User ID field is required when restricting editing to the entry creator.

### `[deletelink]` — delete link inside Views / form HTML (Pro)

| Parameter | Required | Default | Notes |
|---|---|---|---|
| `label` | Yes | none | **If omitted, no HTML is returned at all** |
| `id` | Optional | auto-detected | Entry ID; auto from the View row / form context |
| `page_id` | Optional | current page | Post-deletion destination. **Required with AJAX (`prefix`)** — auto-detection unavailable during AJAX |
| `confirm` | Optional | "Are you sure you want to delete this entry?" | Confirmation popup text |
| `title` | Optional | value of `label` | Hover tooltip |
| `class` | Optional | none | CSS classes |
| `prefix` | Optional | none | AJAX delete with fade-out; wrapping div id = prefix + entry ID, and the shortcode must be **inside** the container |

```
[deletelink label="delete" prefix="frm_container_"]
[deletelink label="Delete Draft" class="my_custom_class"]
```

AJAX delete with fade-out:

```html
<div id="frm_container_[id]">
Insert content here
[deletelink label="delete" prefix="frm_container_"]
</div>
```

Delete Draft link (Customize HTML → Submit button; form must allow logged-in users to save drafts):

```
[if save_draft]<a href="#" class="frm_save_draft" [draft_hook]>[draft_label]</a>
[deletelink label="Delete Draft" class="my_custom_class"][/if save_draft]
```

### `[frm-entry-update-field]` — AJAX single-field update link (Pro)

Contexts: Views and pages/posts. Front-end editing must be enabled; only users with editing permission see the link.

| Parameter | Required | Default | Notes |
|---|---|---|---|
| `id` | Yes | none | Entry ID. Use `id=[id]` inside a View for the current row |
| `field_id` | Yes | none | Field ID or key to update |
| `value` | Yes | none | New value. Can reference another field: `value="[100]"` |
| `label` | Optional | "Update" | Link text |
| `class` | Optional | none | CSS class(es) |
| `message` | Optional | none | Success message after the update |
| `title` | Optional | value of `label` | Hover attribute |

```
[frm-entry-update-field id=[id] field_id=y value="Updated"]
[frm-entry-update-field id=x field_id=y value="[100]"]
[frm-entry-update-field id=x field_id=y value="Complete" label="Mark as Complete" message="Done!"]
```

Gotchas: **if the field's current value already equals `value`, the link is not rendered**; updates via AJAX (no reload); **does not support post fields**.

### Page/post variants (explicit entry ID)

`[frm-entry-edit-link]` — same behavior/params as `[editlink]` plus:
- `id` (required): entry ID, **or** `id="current"` on posts *generated by* a Formidable form
- `page_id` (required); `form_id` (optional, slightly reduces processing time)

```
[frm-entry-edit-link id=123 label="Edit" page_id=25]
[frm-entry-edit-link id=current page_id=200]
[frm-entry-edit-link id=456 label="Edit Entry" page_id=25 form_id=12]
```

`[frm-entry-delete-link]` — same params as `[deletelink]` but `id` and `page_id` are required (and `label` still required):

```
[frm-entry-delete-link id=x label="Delete your entry"]
[frm-entry-delete-link id=x page_id=y confirm="Permanently delete your entry?"]
[frm-entry-delete-link id=x page_id=y class="my_class my_class_2"]
```

---

## 7. Publishing Shortcodes (pages/posts)

### `[formidable]` — publish a form (Core: Lite + Pro)

```
[formidable id=x]
```
`x` = form ID **or key** (key useful on multisite).

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `id` | Form ID or key | required | Which form |
| `title` | `"1"` | off | Show form title |
| `description` | `"1"` | off | Show form description |
| `minimize` | `"1"` | off | Remove extra whitespace (when another plugin/theme double-filters content) |
| `entry_id` | Entry ID, or `last` | — | Load an entry for front-end editing (requires front-end editing enabled; Pro) |
| `readonly` | `disabled` | — | Allow editing of read-only fields |
| `fields` | Field IDs/keys, e.g. `"10,11,12"` | all | Show only listed fields. `fields=""` shows only the submit button. A section/embedded-form parent ID includes its nested fields |
| `exclude_fields` | Field IDs/keys | none | Hide listed fields (same nesting behavior) |
| `page` | Page number `"2"`, or a param name `page="start-page"` | 1 | Starting page of a multi-page form |
| *any custom param* | Any string, e.g. `my_param="value"` | — | Pass a value into the form; read with `[get param="my_param"]` in a field default value |

```
[formidable id=x title="1" description="1" minimize="1" entry_id=y readonly=disabled fields="10,11,12"]
[formidable id=x my_param="value"]
```

Gotchas: publishing the **same form twice on one page** creates duplicate HTML IDs → JS conflicts (calculations, datepickers, conditional logic, repeaters break). PHP: `FrmFormsController::show_form( x, '', true, true )` or `FrmFormsController::get_form_shortcode( array(...) )`.

### `[display-frm-data]` — publish a View (requires Views/Pro)

```
[display-frm-data id=x filter=limited]
```

**The parameter name is always `id=`, even when passing a key/slug** — there is no separate `key=` parameter for this shortcode. `[display-frm-data key=my-slug]` silently fails ("There are no views with that ID") because `key` isn't a recognized attribute at all; use `[display-frm-data id=my-slug]` instead, passing the slug as the *value*. Confirmed via live test after `key=` broke a Dashboard sidebar. This is unlike `[formidable]`, which does accept a form key as the value of its `id=` parameter — don't assume the two shortcodes behave identically just because both list "ID or key" in their docs.

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `id` | View ID or key/slug (always this parameter name, never `key=`) | required | Which View |
| `filter` | `limited` or `1` | none | `limited`: process WP content filters (recommended). `1`: run ALL content filters — only if another plugin needs it. Without it, shortcodes inside the View content may render unprocessed |
| `entry_id` | Entry ID(s), comma-separated | — | Show only specific entries; **overrides other View filters** |
| `user_id` | User ID | — | Only that user's entries; overrides the View's UserID filters |
| `limit` | Integer | View setting | Override entry limit |
| `page_size` | Integer | View setting | Override pagination size |
| `offset` | Integer | View setting | Skip N entries; each instance can use its own |
| `order_by` | Field ID/key, `created_at`, or `"rand"` | View setting | Override sort field |
| `order` | `"ASC"` / `"DESC"` | — | Direction; must be paired with `order_by` |
| `drafts` | `1` or `"both"` | drafts excluded | `1` = include drafts; `both` = drafts + completed |
| `wpautop` | `0` / `1` | — | Control auto `<p>` insertion when `filter=limited` |
| *any custom param* | Any string | — | Pass a value into the View; read with `[get param="param_name"]` in View content/filters |

```
[display-frm-data id=x filter=limited entry_id="123"]
[display-frm-data id=x filter=limited order_by="created_at" order="ASC"]
[display-frm-data id=x filter=limited my_param="value"]
```

Gotchas: with multiple Views on one page, Views lower on the page inherit param values from Views above them — pass explicitly blank params to later Views. AJAX-pagination "undefined" errors are often Cloudflare auto-minify stripping the `<!-- FRM-VIEW` comment. Prefer `filter=limited` over `filter=1`. PHP: `FrmViewsDisplaysController::get_shortcode( array( 'id' => x, 'filter' => 'limited' ) )`.

#### Nested Views — one View inside another (parent/child across two forms)

A View reads from exactly one form. To show related entries from a second form, put a `[display-frm-data]` for the child View inside the parent View's content. Both forms need a **shared field** holding identical data (a code, a unique ID, a Dynamic field, or a User ID field) — that value is what links a parent to its children. KB: `/knowledgebase/advanced-view-concepts/`.

Three pieces have to line up:

1. **Child View** — filter it on the shared field, comparing against a made-up param name: `where = <shared field id>`, `where_is = "="`, `where_val = "[get param=pass_code]"`. The param name is arbitrary but must match step 2 exactly.
2. **Parent View content** — embed the child, passing the parent row's shared value into that param: `[display-frm-data id=<child_view_id> pass_code="[<parent_shared_field_key>]"]`. For a User ID shared field add `show=ID` so the numeric ID is passed, not the display name.
3. **Page** — publish the parent: `[display-frm-data id=<parent_view_id> filter=limited]`.

Verified working end-to-end (Formidable 6.33.1 / Views 5.11), companies → employees keyed on a text code:

```
Child View (form B) content:      <li>[nv_emp_name] — [nv_emp_role]</li>
Child View filter:               where=13408, where_is="=", where_val="[get param=pass_code]"
Parent View (form A) content:     <h3>[nv_co_name]</h3>[display-frm-data id=10942 pass_code="[nv_co_code]"]
Page:                            [display-frm-data id=10943 filter=limited]
```

Each parent rendered only its own children (ACME → its 2 employees, Globex → its 3). Nesting also works in the parent's **Detail Page** content — the same `[display-frm-data … pass_code="[field]"]` line inside `detail_content` renders correctly when an entry is opened via `[detaillink]`.

Verified behaviors and traps:

- **`[entry_count]` inside the nested child counts the filtered subset**, not the child form's total — it printed 2 under ACME and 3 under Globex. Put it in the child's `before_content`.
- **An unparameterized child View shows EVERY entry, it does not come up empty.** When `[get param=pass_code]` resolves to nothing the filter is dropped rather than matching zero rows, so the child View's own permalink (`/frm_display/<slug>/`) leaks the whole child form, and `empty_msg` never fires. If the child is only ever meant to appear nested, give it `status: private` or `draft` — embedded rendering still works (see `gotchas.md`), while the standalone permalink stops serving it.
- **Param values leak downward on a shared page** (the documented multi-View gotcha, confirmed): a second `[display-frm-data id=<same child>]` with no param on the same page inherited the first instance's `pass_code` and showed that parent's children. Pass the param explicitly (even blank) to every later instance.
- **`filter=limited` was not actually required for the nesting to run** on this version — the child rendered inside the parent without it. Keep using it (the docs call for it and it governs which WP content filters run), but when a nested View comes up empty, look at the param name and the child's filter before blaming `filter`.
- **The parent View's own permalink (`/frm_display/<slug>/`) renders the nesting correctly — no WP page needed.** Verified (teams → quiz attempts): a published parent whose content embeds `[display-frm-data id=<child> team_code="[<key>]"]` rendered each parent's filtered children and per-parent `[entry_count]` for an anonymous visitor, while the private child's permalink 404'd. Handy for verification even when the final destination is a page.
- Repeater/embedded-form rows are a different mechanism — use `[foreach n]…[/foreach n]` inside the View (§6), not a nested View.

### `[frm-export-view]` — CSV download link for a table View (Export View add-on)

```
[frm-export-view view=x label="Export as CSV"]
```
`x` = View ID or key. Renders a signed, cookie-free CSV download link (~24h expiry) for a table-shaped All-Entries/Dynamic View. Renders nothing for visitors when misconfigured (config errors show only to users with `frm_edit_displays`) and nothing when the View has no entries. Usually unnecessary: with the View option `show_export_view: "1"` the link auto-appends below the rendered View. Full setup (View options, table-type requirement, CSV format) in `entries-and-views.md` § "CSV export button on a view".

### `[frm-entry-links]` — editable entry list (Pro)

```
[frm-entry-links id=x]
```
`x` = form ID. Lists entries (default link text = creation date), linked for editing. Requires front-end editing enabled; edit/delete show per permissions.

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `id` | Form ID | required | Which form's entries |
| `field_key` | Field ID or key | creation date | Which field's value is the link text |
| `type` | `list`, `select`, `collapse` | `list` | Bulleted list / dropdown / collapsible |
| `user_id` | `current`, `0`, or user ID | `current` | Whose entries; `0` = all users |
| `order` | `ASC`, `DESC`, or raw `"ORDER BY meta_X DESC"` | ASC by date | Sort |
| `page_id` | Page ID | same page | Page containing the editing form |
| `show_delete` | Text | not shown | Show a delete link with this label |
| `confirm` | Text | none | Deletion confirmation popup |
| `link_type` | `page`, `admin`, `scroll` | `page` | Front-end page, wp-admin, or scroll to a View on the same page |
| `drafts` | `1`, `2`, `3`, `"2,3"`, `"both"`, `"all"` | excluded | `1`=drafts, `2`=in-progress, `3`=abandoned, combine with commas; `both`=drafts+completed; `all`=every status |
| `class` | CSS class(es) | none | Extra classes |

```
[frm-entry-links id=x field_key=adjh29]
[frm-entry-links id=x field_key=y type=select]
[frm-entry-links id=x show_delete="Delete" confirm="Permanently delete your entry?"]
[frm-entry-links id=x link_type=admin]
[frm-entry-links id=x drafts="2,3"]
```

Gotchas: `link_type=scroll` needs a View on the same page whose container ID matches the field key; make the `field_key` field required or blank values yield invisible links.

### `[formresults]` — entries table (Pro)

```
[formresults id=x]
```
`x` = form ID. Displays all entries in a table. **Table presentation is not customizable** — use a View for custom layout.

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `id` | Form ID | required | |
| `cols` | Number | 99 | Max columns |
| `fields` | Field keys/IDs, may include `id` | all | Columns to show: `fields="id,25,26,27"` |
| `google` | `0`/`1` | `0` | Google-powered sortable/paged table |
| `pagesize` | Number | 20 | Rows per page — **only with `google=1`** |
| `sort` | `0`/`1` | `1` | Column sorting (with `google=1`) |
| `style` | `0`/`1` | `1` | `0` disables built-in styling |
| `no_entries` | Text | "No Entries Found" | Empty message |
| `clickable` | `0`/`1` | `0` | Clickable links in values |
| `drafts` | `1`, `"both"`, `0` | `0` | Include drafts |
| `user_id` | ID, username, or `"current"` | all | One user's entries |
| `edit_link` | Text | not shown | Edit-link label (pair with `page_id`) |
| `page_id` | Page ID | — | Page holding the edit form |
| `delete_link` | Text | not shown | Delete-link label |
| `confirm` | Text | none | Deletion confirmation (pair with `delete_link`) |

```
[formresults id=x google=1 pagesize=10]
[formresults id=x edit_link="Edit" page_id=592]
[formresults id=x delete_link="Delete" confirm="Are you sure?"]
```

### `[frm-show-entry]` — single entry table (Pro)

```
[frm-show-entry id=x]
```
`x` = **entry ID** (not form ID). Inside a View, use `id=[id]` for the current entry. Contexts: pages/posts, View content, HTML fields inside forms. Presentation only customizable via the styling params below — use a View for full control.

| Parameter | Values | Default | Purpose |
|---|---|---|---|
| `id` | Entry ID (or `[id]` in a View) | required | Entry to display |
| `plain_text` | `0`/`1` | `0` | `1` = plain text instead of table |
| `user_info` | `0`/`1` | `0` | Include submitter info (IP, browser, etc.) |
| `include_blank` | `0`/`1` | `0` | Include empty fields |
| `include_extras` | `"page, section, html"` | excluded | Include page breaks, section headings, HTML fields |
| `include_fields` / `exclude_fields` | Field IDs | all / none | Filter shown fields |
| `show_image` | `0`/`1` | `0` (URL) | Display uploaded images |
| `show_filename` | `0`/`1` | `0` | Show upload file names |
| `add_link` | `0`/`1` | `0` | Link uploads to the file |
| `direction` | `rtl` | ltr | RTL table |
| `font_size`, `text_color`, `border_width`, `border_color`, `bg_color`, `alt_bg_color` | CSS size / hex (no `#`) | defaults | Table styling |
| `line_breaks` | `0`/`1` | `1` | `0` disables auto line breaks |
| `format` | `text`, `json`, `array` | `text` | Output format (`array` only meaningful in PHP) |
| `array_separator` | Text/HTML, e.g. `"<br/>"` | comma | Multi-value separator |

```
[frm-show-entry id=[id]]
[frm-show-entry id=x plain_text=1 user_info=1]
[frm-show-entry id=x include_extras="page, section, html"]
[frm-show-entry id=x show_image=1 add_link=1]
[frm-show-entry id=x font_size="25px" text_color="b642f4" border_width="1px" border_color="000000" bg_color="ffffff" alt_bg_color="eeeeee"]
```

---

## 8. Stats, Math, Graphs, Search

### `[frm-stats]` — field totals & statistics (Pro)

```
[frm-stats id=x type=count]
```
`id` = **field** ID or key (not form ID); `type` required. Contexts: pages, posts, Views (dynamic values like `[id]` / `[376]` work in filters), form fields (default values / HTML fields), emails.

`type` values: `total`, `count`, `average` (or `mean`), `median`, `star` (average as star-rating graphic), `maximum`, `minimum`, `unique` (count of unique entries), `deviation` (standard deviation). These match the MCP `get-stats` ability types (entries-and-views.md).

Optional parameters:

| Parameter | Purpose | Example |
|---|---|---|
| `user_id` | Filter to a user; ID or `current` | `user_id=current` |
| `entry` | Restrict to entry IDs/keys | `entry="250,252,255"` |
| `parent_id` | Repeater child entries of a parent entry | `parent_id="120"` |
| `limit` | Max entries included | `limit=5` |
| `decimal` | Max decimal places (no trailing zeros) | `decimal=2` |
| `dec_point` / `thousands_sep` | Number formatting characters | `dec_point=","` |
| `drafts` | `1` = drafts only, `both` = drafts + submitted; default excluded | `drafts=both` |
| `created_at_greater_than` / `created_at_less_than` | `Y-m-d` or strtotime string | `created_at_greater_than="-1 month"` |

Field-value filtering (fields in the **same form only**) — the field ID is the parameter name:

| Filter | Example |
|---|---|
| Equals | `25="Yes"` |
| Not equal | `25_not_equal="Yes"` |
| Greater than | `25_greater_than="10"` |
| Greater than or equal | `25_greater_than_or_equal_to="10"` |
| Less than | `25_less_than="10"` |
| Less than or equal | `25_less_than_or_equal_to="10"` |
| Contains | `25_contains="Activity"` |
| Does not contain | `25_does_not_contain="Activity"` |
| Dynamic (URL param) | `25_greater_than="[get param=param_name]"` |

```
[frm-stats id=378 type=count 378="[376]"]                       <!-- per-course count, inside a View -->
[frm-stats id="x" type="total" created_at_greater_than="-1 month"]
[frm-stats id=x type=total 25_greater_than="10" 25_less_than="20"]
```

Gotchas: multiple field filters combine, but the **same filter can't be used twice** in one shortcode (for OR logic, add two stats with `[frm-math]`); stats filter only by same-form fields (Repeater stats can't filter by parent-form fields, and vice versa); drafts excluded by default; conditional display → wrap with `[frm-condition source=frm-stats ...]`. PHP: `FrmProStatisticsController::stats_shortcode( array( 'id' => x, 'type' => 'count' ) )`.

### `[frm-math]` — math on saved data *(Pro requirement not explicitly stated in KB)*

For calculations on static numbers and **previously-saved** data. NOT for real-time in-form calculations (use Field Calculations for that). Contexts: Views, pages/posts, emails, default field values.

```
[frm-math] math expression [/frm-math]
```

Allowed content: numbers; nested shortcodes such as `[frm-stats ...]`; field shortcodes like `[100]` (valid inside Views, emails, success messages). Operators (PEMDAS): `+`, `-`, `*`, `/`, `%` (modulo), nestable `()`.

| Parameter | Values | Purpose |
|---|---|---|
| `error` | `debug`, custom text, or empty string | What shows when the expression errors |
| `clean` | `0` (default) / `1` | Strip non-math characters; v6.15+ also strips HTML tags |
| `decimal` | Integer | Decimal places to round to |
| `dec_point` / `thousands_sep` | Character | Number formatting |

Errors occur with: letters/non-math punctuation (commas/periods excepted), unmatched parentheses, missing values (`3 + * 2`). Empty content alone does not error.

```
$ [frm-math decimal=2] [100] [/frm-math]

[frm-math] ([frm-stats id=100 101=[42] type=total] +
[frm-stats id=150 151=[42] type=total] +
[frm-stats id=160 165=[42] type=total])/3 [/frm-math]

[frm-math] [frm-stats id=25 25="bronze" type=count] +
[frm-stats id=25 25="gold" type=count] [/frm-math]              <!-- OR-logic stat workaround -->
```

In conditionals — either pass the expression via `content=` (field shortcodes + literal numbers only; other WP shortcodes not allowed inside `content`):

```
[frm-condition source=frm-math content="[100] * [102]" greater_than=10]...[/frm-condition]
[frm-condition source=frm-math content="[entry_position] % 3" equals="0"]every 3rd entry[/frm-condition]
```

or save the result as a param first:

```
[frm-set-get param=remaining_spaces][frm-math] 100 - [frm-stats id=18 type=count] [/frm-math][/frm-set-get]
```

### `[frm-graph]` — graphs (Pro)

Uses Google Charts (HTML5/SVG); graphs are live — they auto-update as entries change. One of these is required:

```
[frm-graph fields="x,y,z"]    <!-- field IDs/keys, comma-separated; order = display order -->
[frm-graph form="x"]          <!-- form ID/key; graphs submissions over time -->
```

Graph types (`type`): `column` (**default**), `hbar`, `pie`, `line`, `area`, `scatter`, `stepped_area`, `histogram`, `table`, `geo` (world map — Country fields only: dropdown, Lookup, Dynamic dropdown).

X-axis: `x_axis` (field ID, `created_at`, `updated_at`), `group_by` (`month`/`quarter`/`year`), `include_zero` (`1`/`0`), `is_stacked` (`1`, multi-field graphs only), `data_type` (`count`/`total`/`average`/`minimum`/`maximum`), `x_title`, `x_title_size` (px), `x_title_color` (hex), `x_labels_size` (px), `x_slanted_text` (`0` = horizontal; slanting on by default), `x_text_angle` (degrees), `x_show_text_every` (N), `x_min`/`x_max`, `x_order` (`desc` reverse-alphabetical, `field_opts` field-option order).

Y-axis: `y_title`, `y_title_size`, `y_title_color`, `y_labels_size`, `y_min`/`y_max`.

Title: `title` (set `title=""` to hide), `title_size`, `title_font`, `title_bold` (`1`/`true`), `title_italic`, `title_color`, `truncate` (char limit for default titles; default `40`).

Display & styling: `colors` (comma-separated hex), `bg_color`, `grid_color` (horizontal grid), `x_grid_color` (vertical grid), `height` (px; default `400`), `width` (px, or percent for responsive: `width="100%"`), `chart_area` (`height:100%, width:100%, top:10, left:20`), `is3d` (`true`, pie only), `pie_hole` (`0`–`.9`, pie/donut), `curve_type` (`function` = smooth, line only), `no_data` (custom empty message), `pagesize` / `sort_column` (`0`/`1`) / `sort_ascending` (`1`) (table type only).

Animation: `animate` (`0`/`1`), `animation_duration` (ms; default `1000`), `animation_easing` (`linear`, `in`, `out` (default), `inAndOut`).

Legend/tooltip: `show_key` (`1` default show / `0` hide), `legend_position` (`top`/`bottom`/`left`/`right`), `legend_size` (px), `tooltip_label`.

Filtering: `user_id` (ID or `current`), `entry` (IDs/keys), `drafts` (`1` drafts only / `both`; default excluded), `created_at_greater_than` / `created_at_less_than` (`Y-m-d` or strtotime), `limit` (shows highest values), and field-ID filters: `y="Yes"`, `y_not_equal="Pending"`, `y_greater_than` / `y_greater_than_or_equal_to`, `y_less_than` / `y_less_than_or_equal_to`, `y_contains="Morning"`. URL-param filter `y=[get param='url-filter']` — **works in Views only**, not directly on pages.

strtotime examples from the docs: `-1 month`, `first day of 6 months ago`, `first day of January last year`, `yesterday`, `monday this week`, `monday last week`, `first day of march this year`, `first day of june last year` + `last day of june last year`, `first day of this month`.

Worked examples (verbatim):

```
[frm-graph fields="254" x_axis="253" type="stepped_area" title="My Graph" x_title="X axis title" y_title="Y axis title" data_type="total" bg_color="#ebf0fa" colors="#FF0000" grid_color="#9900cc"]

[frm-graph fields="255" type="column" title="Favorite Color" colors="#21759B, #1C9E05, #EF8C08, #FF0000"]

[frm-graph fields="255" width="100%" title="My Pie Graph" type="pie" show_key="1" legend_position="left" is3d="true"]

[frm-graph fields="255" type="pie" pie_hole=".4" title="" show_key="1" legend_position="bottom"]

[frm-graph fields="253,255,256" x_axis="created_at" x_slanted_text="0" type="line" curve_type="function" width="100%" chart_area="height:40%,width:60%" title="Curve Line Graph" title_bold="true" show_key="1" legend_size="20" y_title="# of Submissions" x_title="Date Created"]

[frm-graph fields="258" type="geo" colors="#2A48F4, #1DA7F0, #1AEFE9, #16EE97, #13EC44, #80EA0C, #D2E809, #E7AA06, #E65303, #E50005"]

[frm-graph fields="5507" x_axis="5506" type="geo" data_type="total"]

[frm-graph fields="401,402,403" x_axis="405" is_stacked="1" title="Hours by member" data_type="average" show_key="1"]

[frm-graph fields="100" x_axis="101" type="line" title="Weight Tracking" data_type="average" user_id="current"]

[frm-graph fields="100" x_axis="created_at" type="line" title="Revenue Per Day" data_type="total"]

[frm-graph fields="100" x_axis="created_at" created_at_greater_than="2021-03-01" created_at_less_than="2021-03-31" group_by="month" data_type="count" type="line" title="Entries for March"]

[frm-graph fields="1491" data_type="total" created_at_greater_than="first day of this month"]

[frm-graph fields="1491" data_type="total" 1492_greater_than="first day of this month"]
```

Contexts: pages/posts (Formidable Chart block or classic Shortcode Builder — neither exposes all parameters, write manually for full control), Views, widgets, HTML form fields. PHP: `FrmProGraphsController::graph_shortcode( array( 'fields' => x ) )`. Hooks: `frm_google_chart`, `frm_graph_data`, `frm_no_data_graph`, `frm_graph_value`, `frm_graph_id`.

**Verified in a View (dev site):** graphs work in a View's `before_content`/`after_content` and content boxes. Two shortcodes placed in `before_content` of a classic view rendered correct aggregates on first load with no console or PHP errors:

```
[frm-graph fields=13322 x_axis=13320 type="column" data_type="average" title="Avg price by category" width="100%" height="300"]
[frm-graph fields=13320 type="pie" show_key="1" width="100%" height="300"]
```

- `fields=<number field>` + `x_axis=<choice field>` + `data_type="average"` → one bar per option, averaging the number field. A choice field alone with `type="pie"` → count-per-option pie.
- Prefer `before_content`/`after_content` for summary graphs so they render **once**, not per entry row.
- Rendered markup is `<div id="chart__frm_<type><n>">…<svg>` — when verifying with Playwright, assert an `svg` exists inside `[id^="chart_"]` and allow ~2s for the Google Charts loader first.
- Graphs load Google Charts from `gstatic.com` at render time — offline/airgapped environments render nothing.
- Empty output usually means filters excluded all entries or the field has no data — set `no_data="..."` to tell "no data" apart from a broken shortcode.
- **Graphs do not render in PDFs** (`[frm-pdf]` output excludes them — see `pdfs.md`).

### `[frm-search]` — front-end search bar (Pro/Views)

```
[frm-search]
```

| Parameter | Purpose | Example |
|---|---|---|
| `post_id` | ID of the page/post containing the View/entry list to search — required when the search bar lives on a different page | `[frm-search post_id=x]` |
| `label` | Search button text | `[frm-search label="Search"]` |
| `views` | Restrict which Views on the page are searched (View IDs, comma-separated) | `[frm-search views="x,y,z"]` |

Placement: page/post (Shortcode block or classic Formidable button → Search), a View's **Before Content** box, widgets (with `post_id`). Formidable styling wrapper:

```html
<div class="with_frm_style"><div class="frm_submit">[frm-search]</div></div>
```

CSS targets: `#frm_search` (input), `.searchsubmit` (button). Gotchas: searches Views, entry lists, and general page content — NOT categories, taxonomies, or custom fields. Hook `frm_search_any_terms` for all-terms matching. PHP: `FrmProEntriesController::get_search( array( 'post_id' => x ) )`.

### `[frm-letter-filter]` — A–Z alphabet filter links (Views add-on)

*Verified in code (`FrmViewsAppController::letter_filter`, registered by `FrmViewsHooksController`).* Outputs an "All" link plus A–Z links as a `frm_plain_list frm_inline_list` UL; each letter links to `?<param>=<letter>` on the current page.

```
[frm-letter-filter]                <!-- default param: lname -->
[frm-letter-filter param=field_name]
```

Single attribute: `param` (default `lname`) — the URL parameter name the letter is written to. The shortcode only emits the links; **filtering happens in the View**: add a View filter like *field starts with `[get param='<param>']`*. If a `FrmUsrDirController::letter_filter` (User Directory add-on) exists, that implementation takes over the shortcode name.

---

## 9. Dynamic Values: Set/Get Params, Defaults, `[frm-field-value]`

### `[frm-set-get]` — set a param for later retrieval *(Pro requirement not explicitly stated in KB)*

Sets a named parameter (like a URL param, without the URL) that `[get param=...]` can read in forms/Views lower on the page.

```
[frm-set-get param_name="value"]                                <!-- the attribute NAME is the param name -->
[frm-set-get param=param-name]enclosed content[/frm-set-get]    <!-- complex value from shortcode output -->
```

```
[frm-set-get param_name="value"]
[formidable id=x]

[frm-set-get contact_email="[26]"]          <!-- in View content: set from field 26 -->
[formidable id=x]

[frm-set-get param=total_cost]
[frm-stats id=100 type=total user_id=current]
[/frm-set-get]

[frm-condition source=frm-field-value field_id=72 user_id=current less_than=param param=total_cost]Message[/frm-condition]
```

Gotchas: params set **inside a View cannot be read with `[get param]` in the same View** — place `[frm-set-get]` above the View (classic editor) or split into separate Views; on **Gutenberg** pages `[get param]` may not work after `[frm-set-get]` — the docs link a custom `[show_param]` code snippet as a workaround (`[show_param]` is NOT a built-in shortcode; see section 12). Mixing enclosed and non-enclosed forms on one page may produce unintended results.

### `[get param=...]` — read a URL / passed parameter (Pro)

```
[get param="param_name"]
[get param="job" default="Default Value"]
```

- `param` (required): URL parameter / WP Query variable name. `default` (optional): fallback when blank/absent.
- URL `examplesite.com/form/?job=cashier` + `[get param="job"]` → `cashier`.
- Form-to-form passing: Form A redirect `https://examplesite.com/application/?project=[id]`; Form B field default `[get param="project"]`.
- View-to-form: View link `...?project=[id]`, Form B Dynamic-field default `[get param="project"]`.
- Conditional default: `[if get param="param_name"][get param="param_name"][else]Show this content instead[/if get]`

Contexts: field Default Value boxes, View content/filters, form settings, Customize HTML (submit button). Gotchas: **always set a default when the param filters sensitive entries** (a missing param would expose everything); avoid reserved WP query keywords (e.g. `name`) as param names; **page caching breaks auto-population for logged-out users**.

### Dynamic default value shortcodes (`/knowledgebase/using-dynamic-default-values-in-fields/`)

Go in a field's **Default Value** box; also resolve in hidden fields, form HTML, emails, Views. Populate on page load; user-data values require login. Defaults do NOT replace values when editing an existing entry.

| Shortcode | Syntax / parameters | Notes | Pro |
|---|---|---|---|
| `[date]` | `[date]`, `[date format="Y-m-d"]`, `[date offset='+3 days' format='Y-m-d']` | `format` = PHP date() chars; `offset` = any PHP `strtotime()` string (`'+1 month'`, `'-1 week'`, `'next monday'`) | No |
| `[time]` | `[time]`, `[time format='h:i A' round=30]` | `round` = round to nearest N minutes | No |
| `[email]` | `[email]` | Logged-in user's email | No |
| `[login]` | `[login]` | Logged-in username | No |
| `[display_name]` | `[display_name]` | Profile display name | No |
| `[first_name]` / `[last_name]` | | From user profile | No |
| `[user_id]` | `[user_id]` | Numeric user ID | No |
| `[user_role]` | `[user_role]` | WordPress role | No |
| `[user_meta]` | `[user_meta key="meta_name"]` | e.g. `[user_meta key="user_url"]`, `[user_meta key="user_description"]` | No |
| `[post_id]` | `[post_id]` | ID of post/page containing the form | No |
| `[post_title]` | `[post_title]` | Title of that post | No |
| `[post_author_email]` | `[post_author_email]` | Post author's email | No |
| `[post_meta]` | `[post_meta key="field_name"]` | e.g. `[post_meta key="_visibility"]` | No |
| `[ip]` | `[ip]` | Visitor's public IPv4 (not local/private IP) | No |
| `[server]` | `[server param="PARAM_NAME"]` | Any PHP `$_SERVER` key: `[server param="REQUEST_URI"]` (current URL), `[server param="HTTP_REFERER"]` (previous page — on multi-page forms the field must be on the **first page**) | No |
| `[auto_id]` | `[auto_id start=1]`, `[auto_id step=2 start=2]`, `abc_[auto_id start=1]_xyz` | Auto-increment per entry. `start` default 1, `step` default 1. Prefix/suffix allowed but **no numbers directly adjacent to the shortcode**. Not guaranteed unique under simultaneous submits — mark the field Unique. **Does not work inside repeaters** | No |
| `[get param=""]` | see above | | **Yes** |

Extra gotchas: reserved WordPress keywords in shortcodes/keys cause unexpected behavior; page caching blocks dynamic population for logged-out visitors; programmatic alternative: `frm_get_default_value` filter. A more secure User ID default: a **Virtual Field** with `[user_id]` as default — stored server-side, not editable via DevTools.

### `[frm-field-value]` — get a value from an entry (Pro)

Contexts: pages/posts, Views, email bodies, and — most commonly — field **Default Value** boxes (including populating Dynamic fields). Frequently used as the `source` of `[frm-condition]`.

```
[frm-field-value field_id=x user_id=current]
```

Required: `field_id` (field ID or key; keys are unique across all forms). With no selector, pulls from the most recent entry by anyone.

Entry selectors (use one):

| Param | Purpose | Example |
|---|---|---|
| `user_id` | Most recent entry by a user; `current` = logged-in user (requires login) | `user_id=current` |
| `ip` | Most recent entry from an IP; `ip=1` = current visitor's IP (works logged-out) | `ip=1` |
| `entry` | Entry ID, entry key, or the **name of a URL parameter** carrying the id/key. Can combine with `user_id="current"` as a security check | `entry="140"`, `entry="entry-key"`, `entry="pass_entry"` (reads `?pass_entry=`) |

Formatting / output:

| Param | Default | Notes |
|---|---|---|
| `default` | none | Fallback when no value exists: `default="Your name"` |
| `format` | WP date settings | Date/time format, e.g. `format="Y-m-d"` — needed when pre-populating date fields |
| `show` | display value | `id` (saved ID from Dynamic/User ID fields), `value` (saved value for separate-values fields), or Address sub-parts: `line1`, `line2`, `city`, `state`, `zip`, `country` |
| `clickable` | off | `1` = clickable links |
| `html` | `1` | File uploads: `0` returns the URL only |
| `truncate` | none | Character count; **`truncate=1` truncates to 50 chars, not 1** |
| `more_text` | "..." | Truncation suffix: `more_text="...Read More"` |
| `sanitize` / `sanitize_url` / `remove_accents` | off | `1` to enable (same behavior as section 1) |

```
[frm-field-value field_id=x user_id=current format="Y-m-d"]
[frm-field-value field_id=x entry="pass_entry"]
[frm-field-value field_id=x entry="entry_key" user_id="current"]
[frm-field-value field_id=x truncate=100 more_text="...Read More"]
[frm-field-value field_id=x user_id=current show=id]      <!-- auto-populate a Dynamic field -->
```

Auto-populate an Address field (one line per subfield Default Value box):

```
[frm-field-value field_id=155 show=line1]
[frm-field-value field_id=155 show=line2]
[frm-field-value field_id=155 show=city]
[frm-field-value field_id=155 show=state]
[frm-field-value field_id=155 show=zip]
[frm-field-value field_id=155 show=country]
```

Gotchas: **does not work with repeater fields**; blank or `0` parameter values are treated as missing; for conditional logic wrap via `[frm-condition]`. PHP: `FrmProEntriesController::get_field_value_shortcode( array( 'field_id' => x, 'user_id' => 'current' ) )`.

---

## 10. Form HTML Tags (Customize HTML)

Available **only inside the Customize HTML section** of form Settings. ⚠ Here `[id]` and `[key]` mean the *field's* ID/key, not the entry's.

### Field box shortcodes

| Shortcode | Purpose |
|---|---|
| `[id]` | ID of the corresponding field |
| `[key]` | Key of the corresponding field |
| `[field_name]` | Name/label of the field |
| `[description]` | Field description (only if one is set) |
| `[label_position]` | Label position class |
| `[required_label]` | Required-field label (usually an asterisk) |
| `[input]` | The input element itself (`<input>/<select>/...`) |
| `[input opt=1]` | A single radio/checkbox option (1-indexed). "Other" option: `[input opt=other_2]` |
| `[input label=0]` | Hide option labels for radios/checkboxes |
| `[required_class]` | Class applied to required fields |
| `[error_class]` | Class applied when the field has an entry error |

### `[input]` custom attributes

Any HTML attribute added to `[input]` is passed to the input element:

```
[input aria-required="true"]          accessibility
[input autofocus="autofocus"]         cursor on load
[input tabindex="1"]                  tab order
[input readonly="readonly"]           e.g. block typing in date pickers
[input class="any-class"]             extra CSS classes
[input autocomplete="off"]            disable browser autocomplete
[input onkeyup="this.value = this.value.toUpperCase();"]   force uppercase
[input data-only-countries="us,ca"]   phone field: limit country flags
[input data-country-order="us,ca"]    phone field: country order
```

### Conditional inside field HTML

```
[if description]<div class="frm_description">[description]</div>[/if description]
```

### Before Fields / After Fields boxes only

| Shortcode | Purpose |
|---|---|
| `[form_name]` | Form name — "may only be placed in the before or after fields" |
| `[form_description]` | Form description (if one was added) |
| `[form_key]` | Form key |
| `[deletelink]` | Delete-entry link. **Requires** "allow users to delete entries" in form settings |

### Submit button box

| Shortcode | Purpose |
|---|---|
| `[button_label]` | The label selected for the Submit button |
| `[button_action]` | The submit action — **must not be removed** when editing Submit button HTML |

Draft-related tags usable here (verbatim from the deletelink docs): `[if save_draft]`, `[draft_hook]`, `[draft_label]` — see the Delete Draft example in section 6.

Notes: resetting a field's HTML box clears it; defaults refill on save. Success-message positioning uses form-level CSS classes (not shortcodes): `frm_below_success`, `frm_plain_success`. The html-tags page does **not** document `[entry_key]`, `[frmurl]`, `[sitename]`, `[siteurl]`, or `[collapse_this]` for this context — unconfirmed there.

---

## 11. File Upload & User ID Display Options

### File Upload field display (Pro field)

Uploaded files are WP media attachments; the field stores **attachment IDs** but the plain shortcode outputs URLs. Contexts: confirmation messages, emails, Views (and `[frm-field-value ... html=0]` for URL-only in defaults).

| Shortcode | Result | Notes |
|---|---|---|
| `[x]` | URL(s) of the uploaded file(s) | Raw URL path |
| `[x show_image=1]` | Show the image (icon for non-images) | Default size: thumbnail |
| `[x size=thumbnail show_image=1]` | Thumbnail (typically 150x150) | Sizes follow WP media settings |
| `[x size=medium show_image=1]` | Medium size | |
| `[x size=full show_image=1]` | Full size | |
| `[x add_link=1]` | Link to the full-sized image/file | Often `[100 add_link=1 show_image=1]` |
| `[x add_link=1 new_tab=1]` | Open in new tab | `new_tab=1` **requires** `add_link=1` |
| `[x show_filename=1]` | Display the filename | |
| `[x show=id]` | Attachment ID(s) | |
| `[x sep="delimiter"]` | Separator between multiple files | |
| `[x class="classname"]` | Add a CSS class to the file HTML | e.g. `[100 class="custom-upload"]` |

Multi-file bulleted list:

```
<ul>
    <li>[100 sep="</li><li>"]</li>
</ul>
```

WordPress gallery of uploaded images:

```
[gallery ids="[100 show=id sep=',']" link="file"]
```

Image linked to a URL from another field (field 10 = URL, field 20 = upload):

```
<a href="[10]">[20 show_image=1]</a>
```

Default image when no file uploaded:

```
[if 100][100 show_image="1"][/if 100]
[if 100 equals=""]<img src="default.png" alt="" />[/if 100]
```

### User ID field display

The User ID field silently stores the logged-in user's numeric ID (hidden on the front end) but **displays the username by default**. Contexts: confirmation messages, emails, Views. `x` = the User ID field's ID:

| Display | Syntax | Notes |
|---|---|---|
| Username (default) | `[x]` | |
| Numeric user ID | `[x show="ID"]` | |
| First name | `[x show="first_name"]` | Falls back to login if empty; `blank="1"` outputs blank instead |
| Last name | `[x show="last_name"]` | Same fallback / `blank="1"` |
| Display name | `[x show="display_name"]` | |
| Login name | `[x show="user_login"]` | |
| Email | `[x show="user_email"]` | Key building block for email recipients (section 4) |
| Author archive link | `[x show="author_link"]` | Links to the user's post archive |
| Avatar | `[x show="avatar" size="250"]` | `size` in px; requires Settings → Discussion → Show Avatars |
| Website | `[x show="user_url"]` | From WP profile |
| Role(s) | `[x show="roles"]` | |
| Any user meta | `[x show="address"]` | Replace `address` with any user-meta key |

The same `show=` options work through Dynamic fields (`[dynamic_field_id show="user_email"]`, section 1). Developer hook: `frm_setup_new_fields_vars` (render User ID as a dropdown for admins on the front end).

---

## 12. Shortcodes that do NOT exist (don't invent these)

Explicitly flagged in the research as absent from the current knowledgebase — never emit these:

| Bogus / misplaced shortcode | Use instead |
|---|---|
| `[entry-detail-link]`, `[detail-link]` | `[detaillink]` (one word, Views only) |
| `[detaillink]` in emails/confirmations | Views only. In emails use `[admin-link]` (backend) or build a link: `[siteurl]/entry-page/?entry=[key]` |
| `[admin-link]` anywhere outside email bodies | Only documented on the email-notifications page. For front-end lists linking to admin entries: `[frm-entry-links id=x link_type=admin]` |
| bare `[count]` | `[entry_count]` (View Before/After Content) or `[frm-stats id=x type=count]` |
| `[show_param]` | Not built-in — it's a custom code snippet the docs link for the Gutenberg `[frm-set-get]` limitation. Don't emit unless the site has installed that snippet |
| `[sep]` as a standalone shortcode | `sep` is a *parameter*: `[x sep=", "]` |
| `[x offset=...]` on field shortcodes | `offset` exists only on `[date offset='+3 days']` |
| `[x default=...]` on field shortcodes | Not documented on the advanced page; `default` belongs to `[frm-field-value]` and `[get param]` |
| `[x show=count]`, checkbox index syntax, `inline_edit` | Verified absent from the advanced-options page |
| `[entry_key]`, `[frmurl]`, `[collapse_this]` in form HTML; `[sitename]`/`[siteurl]` in form HTML | Not documented on the html-tags page — unconfirmed for that context (`[sitename]`/`[siteurl]` ARE valid in Views/emails/confirmations) |
| `contains` as an operator in `[if]` / `[frm-condition]` | Use `like` (and `not_like`) |
| `[if x like="a" like="b"]` | Same parameter can't repeat in one tag — use two blocks or nesting |
| Views-only helpers in action content: `[editlink]`, `[entry_count]`, `[event_date]`, `[evenodd]`, `entry_position` | Do not resolve in emails/confirmations |
| `[foreach]` without the ID in the closing tag | Must be `[/foreach 100]`, matching the opening ID |
| `/knowledgebase/using-foreach/` | 404 — `[foreach]` is documented on the repeatable-section page |

Also *(unconfirmed, do not upgrade to fact)*: the KB does not explicitly state Pro requirements for `[frm-math]` and `[frm-set-get]`; both are documented alongside Pro-only features.
