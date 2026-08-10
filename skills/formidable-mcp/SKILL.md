---
name: formidable-mcp
description: Create, query, and manage everything in Formidable Forms via MCP — forms, fields, repeaters, entries, views, styles, form actions (email/confirmation/webhook), applications, PDF downloads, templates, and troubleshooting known MCP bugs
---

## Overview

This skill covers all Formidable Forms work through the Formidable MCP adapter. It is self-contained and portable: everything needed to do the work correctly is in this file and the `references/` directory. Site-specific access details (credentials, URLs, local paths) intentionally live outside this skill — supply them via environment variables or your own project configuration, so the skill stays portable across sites. See `references/mcp-protocol.md` for setup.

## Routing: which reference to read

Read the reference file(s) for the task at hand BEFORE making MCP calls. Do not work from recall — these documents encode hard-won corrections; skipping them repeats solved mistakes.

| Task | Read |
|---|---|
| Create/edit forms, add fields, field types & options, form settings | `references/forms-and-fields.md` |
| Repeaters (repeatable sections) or nested/embedded forms | `references/repeaters.md` — **always**, this is the most error-prone area |
| Entries (submissions), views, field statistics | `references/entries-and-views.md` |
| **Styling a view, or laying one out as cards/columns** — card grids, column counts, view Custom CSS | `references/entries-and-views.md` § "Styling views" and § "Grid views" — **read before writing any view content**, see rule 9 |
| Nested views — showing a second form's related entries inside a view (parent/child, shared field) | `references/shortcodes.md` §7 `[display-frm-data]` → "Nested Views", plus view filters in `references/entries-and-views.md` |
| Styles / appearance / themes | `references/styles.md` |
| Email notifications, confirmations, webhooks | `references/actions.md` |
| Gated content — restrict private pages/posts/files/PDFs/Views behind a form submission, access tokens/links | `references/actions.md` (action + tokens) and `references/shortcodes.md` §5 (`[frm_gated_content]`) |
| Writing shortcodes — email/confirmation bodies, View content, form HTML, field defaults, conditionals, stats/graphs | `references/shortcodes.md` |
| Applications (Pro) | `references/applications.md` |
| PDF downloads — `[frm-pdf]` links in views/pages/emails, entry/View PDFs, email PDF attachments, Dompdf rendering constraints | `references/pdfs.md` |
| Graphs/charts (`[frm-graph]`), stats, search — full treatment is in the shortcodes reference | `references/shortcodes.md` §8 |
| MCP setup, session protocol, abilities catalog, auth, errors | `references/mcp-protocol.md` |
| Form template XML import/export | `references/templates.md` |
| Something behaves wrong / MCP call fails unexpectedly | `references/gotchas.md` |

## Universal rules (apply to every task)

1. **MCP exclusively.** All creates/updates/deletes go through Formidable MCP abilities. Never fall back to the REST API, and never write to the database directly.
2. **Every field gets a label** (accessibility requirement — no label-less fields).
3. **Use specialized field types** — `name`, `email`, `phone`, `url` — not generic `text`, whenever the data has a specialized type.
4. **Option fields have minimums:** radio buttons ≥ 2 options, dropdowns ≥ 2, checkboxes ≥ 1. Always provide options at creation.
5. **If the form has a `submit` field, it must keep the highest `field_order`** so it renders last — re-check when appending fields. Note `submit` is **not** a `create-field` type (the enum rejects it): forms created via MCP have no submit field, and their button text comes from `update-form` `options.submit_value`. Older forms often do have one.
6. **`form_select` is never empty** on divider (repeater) and dynamic (data) fields — see `references/repeaters.md` and `references/forms-and-fields.md`.
7. **Verify after writing.** After creating or changing anything, verify via MCP reads (and browser inspection for rendering) before declaring success.
8. **Cache:** if fields don't appear in the form editor after API changes, it's almost always browser cache — hard refresh first; server caches are cleared automatically by the API (see `references/forms-and-fields.md` for the manual wp-cli cache clear if needed).
9. **Never inline-style a view, and never hand-roll a CSS grid.** Put semantic class names in the view content and the rules in the View Custom CSS setting (`options.listing_page_custom_css`, auto-scoped to the view) — never `style=` attributes repeated per entry, never a `<style>` block inside `content`. For card/column layouts create the view as **`type: "grid"`** and set `options.grid_column_count`; do not build `display:grid` in a classic view's `before_content`, and do not try to set the column count from Custom CSS (Views writes it inline, so your rule silently loses). Frame styling — background, border, radius, padding, font size — belongs in a box's **`style` object**, not CSS: box 0 styles every card, a content box styles just that cell (the editor's "Cell Settings"). Both render inline, so Custom CSS cannot override them. Read `references/entries-and-views.md` § "Styling views" and § "Grid views" **before writing view content**; this is the single most commonly skipped rule here.
10. **Write markup like a person.** View content and form HTML get newlines and indentation — block tags on their own lines, nesting indented. Never emit one unbroken line of HTML. Keep inline runs unbroken though: a newline between inline elements becomes a `<br>`. See `references/entries-and-views.md` § "Write view content as readable HTML".
11. **Lay form fields out in rows.** Short related fields belong side by side via `field_options.classes` (`frm_first frm6` + `frm6`, thirds with `frm4`, etc.) — not stacked one per line. Long text, textareas, and uploads stay full width. See `references/forms-and-fields.md` § "Field layout".
12. **Keys in content, numeric IDs in settings.** Use field/form/view KEYS in shortcodes and entry payloads (`[preferred-shift]`, `[formidable id=my-form]`), and numeric field IDs in stored settings — conditional logic (`hide_field`), `calc`, `form_select`, `in_section`, lookup fields, view `order_by`/`where`/`date_field_id`, and action settings like quiz `enable`. A key in a setting is **silently ignored**, not rejected. IDs in settings are import-safe (Formidable remaps them), so portability is not a reason to avoid them. Details and the full list in `references/repeaters.md` § "Keys in CONTENT, Numeric IDs in SETTINGS". Entry payloads accept either form at every level; the one structural rule there is that repeater ROWS must be keyed `i0`, `i1`, … (see § "Writing Entry Data for Repeaters").
