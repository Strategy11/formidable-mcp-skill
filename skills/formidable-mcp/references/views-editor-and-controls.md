# Views: blocks, Pretty mode, visitor controls, visibility, and pagination

Read before building a block-based View or configuring the new Views controls. These settings were checked against the Views implementation and round-tripped through MCP on a QA build in October 2026. Feature availability depends on the installed build; do not infer frontend support merely from an accepted options object.

## Content storage and Gutenberg

Use `create-view` / `update-view`; set `options.use_blocks: 1`. A grid still stores boxes and layouts as described in `entries-and-views.md`; Gutenberg belongs **inside each box**, and in Before Content, After Content, Detail Content, or visibility Else content. It does not replace the grid layout model.

Wrap each block-enabled content region in the Views markers:

```html
<!-- frm:blocks -->
<!-- wp:group {"className":"pizza-photo","layout":{"type":"default"}} -->
<div class="wp-block-group pizza-photo">
<!-- wp:formidable/view-field {"field":"pizza-photo","html":true,"options":"size=large"} -->
<div class="wp-block-formidable-view-field">[pizza-photo html="1" size=large]</div>
<!-- /wp:formidable/view-field -->
</div>
<!-- /wp:group -->
<!-- /frm:blocks -->
```

The field key above is illustrative. Use the actual key returned by `list-fields`. Prefer the Formidable **Field Value** block for dynamic values, including images, and native headings, paragraphs, groups, columns, and buttons for surrounding structure. Avoid putting the entire template into a Custom HTML block: individual blocks give Pretty mode useful edit targets.

For entry photographs, use a **file upload field** and the Field Value block with `html: true`; `options: "size=large"` avoids stretching the default 150px thumbnail into a card photo. The saved shortcode and block attributes must agree. Prefer this to a static Media/Image block for each entry. Images in choice controls are a separate feature and use attachment IDs in their `images` map.

`create-entry` / `update-entry` can import a publicly accessible file URL into a file field. Verify that the returned `meta` includes a site-local image URL and a `<field-key>-value` attachment ID. The importer checks the URL **path extension**: extensionless image services may stay external URL values rather than becoming uploads. Use a genuine image URL ending in `.jpg`, `.jpeg`, `.png`, etc. A remote QA server cannot download `dev-site.local` files. If source photos are local-only, use accessible replacements or a user-provided reachable source; do not claim the original files were migrated.

### Views blocks

| Block | Attributes and saved content |
|---|---|
| `formidable/view-field` — Field Value | `field`, `options`, `show`, `html` (boolean), `format`, `separator`. Saves `<div class="wp-block-formidable-view-field">[field-key …]</div>`. `options` holds additional shortcode options such as `decimal=2` or `wpautop=0`. |
| `formidable/view-condition` — Conditional Content | `field`, `operator` (default `equals`), `value`, `options`. Saves `[if field-key equals="value"]` followed by serialized inner blocks and `[/if field-key]`. This is **entry-level** conditional content. |
| `formidable/view-shortcode` — View Shortcode | `shortcode` string; use for View helpers that do not have a dedicated block. |
| `formidable/view-stats` — View Statistic | `field`, `type` (default `count`), `scope` (`all` / `page`), `animate` (boolean), `decimal` (string). Saves a `wp-block-formidable-view-stats` div containing `[frm-view-stats …]`; shortcode field attribute is **`id`**, not `field`. Count needs no field. |
| `formidable/view-graph` — View Chart | `field`, `type` (default `column`), `scope`, `animate`, `xAxis`, `dataType`. Saves a `wp-block-formidable-view-graph` div containing `[frm-view-graph fields="…" type="…" scope="all" animate="1" x_axis="…" data_type="…"]`. |

Statistic calculations include `count`, `total`, `average`, `minimum`, and `maximum`. Chart types include `column`, `bar`, `line`, `pie`, `area`, and `table`. Chart `dataType` chooses the calculation, whereas `type` chooses the chart presentation. For example, a numeric ticket-price `field`, category `xAxis`, and `dataType: "average"` plots average ticket price by category. The Conditional Content block can use a nested View Shortcode block containing `[else]` for an alternative branch. View Shortcode saves its shortcode directly, with no extra div wrapper.

Use the saved markup emitted by the current block implementation when adding unfamiliar options. Do not invent an image attribute on Field Value or use a heading tag as its saved root: its saved root is a div. A surrounding Group class can style the value as a card title.

The embedded editor supports core paragraph, heading, list/list-item, image, buttons/button, group, columns/column, shortcode, HTML, separator, and spacer blocks. It also loads available registered Formidable blocks such as `formidable/simple-view`, `formidable/simple-form`, `formidable/calculator`, and `frm-charts/graph`; add-ons and installed registrations determine availability. A View Search & Filters block (`formidable/view-controls`, `viewId` string) can place configured controls on a page.

### Pretty mode click-to-edit

Pretty mode is an **admin template editor**, not inline entry editing for frontend visitors. Rendered cells and Before/After regions become edit targets. Clicking rendered content selects the corresponding nested Gutenberg block; Enter or Space on a focused region opens editing too. The preview carries the clicked entry ID and region width so editing uses the relevant sample and sizing.

Preview block paths are temporary editor metadata; do not save `data-frm-block-path`, `data-preview-entry-id`, or `frm:preview-block` comments into templates. Do not add frontend edit links to simulate Pretty mode.

Use real serialized block trees and the enclosing `frm:blocks` markers. The renderer parses marked templates before substituting entry values, protects rendered regions from extra automatic paragraphs, and leaves classic content outside marked regions on its existing path. Keep wrappers balanced within each editable region when possible; split wrappers depend on the installed Gutenberg Custom HTML implementation.

### JSON and version differences

- `content` / `detail_content` responses may be JSON **strings or decoded box arrays**, depending on the site/build. Normalize by parsing only strings. For writes, the portable grid payload remains `content: JSON.stringify(boxes)`.
- Build box objects with ordinary strings containing real newlines and quotes, then JSON-encode once. Do not pre-escape HTML quotes or turn newlines into literal backslash-n text inside a box.
- Preserve returned box IDs on update and verify layouts after writing. Creating a View can renumber content boxes to odd IDs; custom nested layouts must reference the persisted IDs.
- Current Views synchronizes a detail layout on detail-content updates and adjusts detail routing; older API implementations required an explicit detail layout. Read back `list-view-layouts` instead of relying on the older behavior.

## Visitor controls

Configure `options.controls` as an ordered array. Read `list-fields` first: settings use **numeric field IDs**, while template shortcodes use field keys. Invalid field/type combinations or sort rules can be discarded when controls are sanitized for rendering. A read-back options value alone does not prove the control rendered.

Shared View options:

```json
{
  "controls_position": "above",
  "controls_auto_submit": 1,
  "controls_ajax": 1,
  "controls_summary": 1,
  "controls_style": 0,
  "controls_submit_button": {
    "label": "Find my match",
    "appearance": "outline",
    "size": "large"
  }
}
```

`controls_position: "manual"` suppresses automatic controls above the View; place them with `[frm-view-controls id=VIEW_ID]` or the View Search & Filters block. Other positions should not be assumed supported. `controls_style` selects a Formidable style ID; `0` uses the default path. Submit button appearance: `default`, `outline`, `link`; size: `default`, `small`, `large`. Set `controls_auto_submit: 0` to use an explicit Apply/Search action.

Common per-control settings are `type`, `label`, `key` (for URL-backed controls), `width` (`auto`, `full`, `half`, `third`, `quarter`), and `option_layout` (`wrap`, `stack`, `inline`, `grid`). Keys become unique sanitized URL parameters with an underscore prefix: key `category` reads **`_category`**, not `category`. Controls on the same page can consequently share a parameter if given the same key; use distinct keys when independent state is intended. Visitor values are checked against saved allowed options. Controls operate within the View's existing filters and access rules.

| Type | Important settings / behavior |
|---|---|
| `search` | `fields: [123,124]`, `placeholder`, `match: "contains"` / `"closest"`, `max_distance` (0–5). Uploads, passwords, credit cards, and structural fields cannot be searched. |
| `choice` | `field`, `display`, `all_label`, `show_counts`, `autocomplete`. Ordinary choice fields offer select/multiselect, radio/checkbox lists, pills (`radio`/`checkbox`), image variants, and appropriate switches. Star fields offer stars; toggles default to switches. Only displays supported by the field type are kept. `images` maps stored option values to local image attachment IDs. |
| Cascading choice | `parent` names an earlier choice control's **key**. Child becomes a select with counts, autocomplete off, and its request value is ignored until a parent is selected. |
| Choice switch | `values: ["Option A","Option B"]` defines the options matched when on; matches any listed option. Older singular `value` is accepted for compatibility. |
| `date` | `field` is a numeric date field ID or `created_at` / `updated_at`; `mode`: `single`, `range`, `multiple`, `year`, `month`; optional `placeholder`. Multiple dates are capped at 31. |
| `range` | Numeric `field`; `display`: `inputs` or `slider`; optional `default_min`, `default_max`. |
| `sort` | `display`: `select`, `radio_list`, `radio`; `options: [{key,label,rules:[{by:"123",order:"ASC_numeric"}]}]`. Rules allow numeric field IDs and `created_at`, `updated_at`, `id`, `item_key`; orders `ASC`, `DESC`, `ASC_numeric`, `DESC_numeric`. Also `show_default`, `default_label`, and table `click_headers`. |
| `page_size` | `sizes: [2,4,6]` (positive integers ≤100), `display`: `select`, `links`, `pills`. Overrides entries per page, not the View's total limit. |
| `preset` | `presets: [{key,label,values:{category:"Classic",sort:"lowest"}}]`. Values reference other control keys; only saved search/choice/date/range/sort controls can be set. |
| `refresh` | `button_display`: `icon`, `icon_label`, `label`; `button_shape`: `square`, `rounded`, `pill`, `circle`; `show_last_refresh`, `auto_refresh`, `refresh_interval`: 0/15/30/60/300 seconds. |
| `shuffle` / `reverse` | Keyed controls with action-button display/shape. Shuffle carries a validated seed for stable pagination; reverse flips the current ordering. |
| `active_filters` / `reset` | Show/remove current selections and clear filters. |
| `summary_card` | `operation`: `count`, `sum`, `average`, `minimum`, `maximum`; numeric `field` for operations other than count; `scope`: `all` or `page`; `decimals`, `prefix`, `suffix`, `show_scope`. Presentation: `value_size` small/medium/large, `alignment` start/center/end, `card_style` bordered/plain/accent, `spacing` normal/compact. |
| `html` | Sanitized `content`; no URL key or retained label. |
| `pagination` | Pager within the controls bar; see the separate pagination section below. |
| `jump_top` | `placement`: `after`, `manual`, `floating_start`, `floating_end`; `target`: `view` / `page`; `smooth`, `threshold` (0–2000). |
| `columns` / `csv` / `print` | Table column picker (`hidden_columns` uses box IDs), CSV export where the Export View add-on and table configuration support it, and printing. CSV export must not be assumed available on a grid. |
| `my_entries` | Filter to the logged-in user's entries; do not treat this visitor toggle as a substitute for a mandatory View access filter. |
| `user_preset` | Logged-in visitors can save/delete their own validated filter preferences (20 named presets per View/user). |
| `share` | Revocable read-only **HTML snapshots**, not a live public View. Creating/revoking requires login, `frm_edit_displays`, and edit permission for that View. Snapshots expire after a week; only one current snapshot is stored per View. Ordinary anonymous visitors cannot create them. |
| `pdf` | Requires the corresponding PDF integration; configure action display settings and verify availability on the target build. |

Calendar Views have their own navigation and do not use this visitor-controls path.

### Live metrics

View Statistic / View Chart blocks and summary controls calculate from the entries permitted by the View and matching its current controls. `scope: "all"` means **all matches across pages**, not every submission in the form; `scope: "page"` uses the current page. Use these scoped blocks when metrics must follow visitor filters. An ordinary global `[frm-stats]` or `[frm-graph]` is not automatically a View-scoped metric.

## Pagination settings

Keep these three concerns separate:

1. `limit`: the View's total maximum entries.
2. `options.page_size`: entries per page; `ajax_pagination` controls page loading. A `page_size` visitor control can override the page size.
3. `options.pagination_appearance`: the new shared pager presentation. It does **not** set page size or create additional entries.

Example:

```json
{
  "page_size": "2",
  "ajax_pagination": 1,
  "pagination_appearance": {
    "display": "numbers",
    "button_display": "icon_label",
    "button_shape": "pill",
    "appearance": "outline",
    "alignment": "center",
    "size": "medium",
    "window": 2,
    "edges": 1,
    "previous_next": 1,
    "pages": [],
    "apply_controls": 1,
    "apply_pagination": 1,
    "hide_pagination": 0
  }
}
```

| Setting | Values / meaning |
|---|---|
| `display` | `numbers`, `select` (page dropdown with Go), `previous_next` |
| `button_display` | `icon`, `icon_label`, `label` |
| `button_shape` | `rounded`, `square`, `pill`, `circle` |
| `appearance` | `filled`, `outline`, `link` |
| `alignment` / `size` | `start`, `center`, `end` / `medium`, `small`, `large` |
| `window` | 1–10 page numbers around the current page |
| `edges` / `previous_next` | Show edge page numbers / Previous and Next actions |
| `pages` | Optional positive page numbers, deduplicated, max 100 values |
| `apply_controls` | Reuse shared appearance for a Pagination visitor control |
| `apply_pagination` | Apply appearance to the View's separate pager; the shared-settings sanitizer enables this |
| `hide_pagination` | Hide the separate pager while retaining pagination state and any control-bar pager |

A `type: "pagination"` visitor control adds `label`, `width`, and `show_control` (whether it appears in the controls bar), alongside presentation settings. Shared `pagination_appearance` takes priority; when absent, the first saved Pagination control supplies the compatibility settings. `apply_controls: 0` leaves the visitor-control appearance independent. No appearance settings means the legacy pager remains on its original path; avoid adding default appearance settings during an unrelated edit.

The paginator only appears with more than one page. Verify with enough entries and no restrictive total `limit`. Query parameters use `frm-page-VIEW_ID=2`. Exercise both normal page URLs and AJAX behavior when a browser is available; server-rendered pagination alone does not verify the JavaScript interaction. Older load-more/infinite loading behavior is separate from the three new appearance display values.

**Appearance gotcha:** circle buttons use `aspect-ratio: 1` and navigation buttons inherit their font. A long `Previous` label therefore creates a much larger circle than a page number, and theme typography can exaggerate the result. For text pagination, prefer `button_shape: "rounded"`. When sizing needs to be independent of the theme, use View Custom CSS targeting `.frm-view-navigation-pagination .frm-view-navigation-button`: explicit `font-size: 16px`, `box-sizing: border-box`, `height: 44px`, `min-height: 44px`, `min-width: 44px`, `padding: 0 14px`, `line-height: 1`, and `aspect-ratio: auto`. Align `.frm-view-page-links` items centrally. Set distinct current-page colors with `[aria-current="page"]` and preserve a visible `:focus-visible` outline. Shape/size settings alone do not guarantee consistent dimensions under a theme's typography.

## View visibility rules

`options.visibility` decides whether the **whole View** renders before entry queries; it is distinct from entry filters and the Conditional Content block. A nonmatching visitor sees nothing or Else content. Else content can contain serialized blocks with Views markers.

```json
{
  "relation": "any",
  "groups": [
    {"relation":"all","rules":[
      {"source":"logged_in","key":"","operator":"==","value":"1","value2":""}
    ]},
    {"relation":"all","rules":[
      {"source":"url_param","key":"preview","operator":"==","value":"1","value2":""}
    ]}
  ],
  "else_type": "content",
  "else_content": "<p>Open the preview to see this collection.</p>"
}
```

The example allows logged-in visitors **or** anyone with `?preview=1`. It is useful for QA demonstrations, not a private-content gate. For restricted content choose actual user/capability rules. `else_type` is `none` or `content`.

Rules use `source`, optional `key`, `operator`, `value`, and `value2` (upper bound for between). Sources:

- User: `logged_in` (`1` / `0`), `user_role`, `user_capability`, `user_id`, `user_login`, `user_email`, `user_meta` (requires a meta `key`), `user_entry_count` (for this View's form).
- Request: `url_param` (requires parameter `key`), `post_id`, `ip`.
- Date/time: `date`, `weekday` (ISO 1=Monday to 7=Sunday), `time`.

Date/time observations use the WordPress site's timezone (`Y-m-d`, ISO weekday, and `H:i`), not the assistant's local timezone.

Operators are type-dependent: `==`, `!=`, `>`, `>=`, `<`, `<=`, `between`, `not_between`, `LIKE`, `not LIKE`, `LIKE%`, `%LIKE`, `in`, `not_in`, `regex`, `not_regex`, `empty`, `not_empty`. Yes/no, weekday, and capability sources allow only equality/inequality; `user_capability.value` is the capability name being checked. Date/time and numeric sources support ordered comparisons; text sources support contains/prefix/suffix/regex. Preserve regex escaping through JSON encoding.

`relation: "all"` / `"any"` applies independently inside each group and across groups. Empty groups/unknown rules are removed; no effective restrictions leaves the View open. Limits are 20 groups, 50 rules/group, and 1024 bytes per regex. Verify with a matching **and** a nonmatching request, including Else output. Authenticated branches require a real authenticated browser/session; MCP credentials alone do not make a public page request logged in.

## Verification checklist

- Read back View options, block serialization, fields, entry photo attachment IDs, and layouts through MCP.
- Verify public rendering: card count, real field values, no literal shortcodes/backslashes, full-size image URLs, and expected pager presentation.
- Exercise search, choice, sorting, page size, and page URLs; confirm filtered metrics reflect all matches versus the current page.
- Check both visibility branches. Use browser tools for Pretty-mode click targeting, Gutenberg validation, responsive layout, and AJAX interactions when available.
- Inspect the new portion of the target site's PHP log when accessible. Do not substitute a local site's log for a remote site's log or claim a clean remote log without access.
- If browser/log access is unavailable, state the verification boundary. Leave task-created background sessions stopped when done.
