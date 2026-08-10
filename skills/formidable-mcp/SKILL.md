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
5. **The submit button must keep the highest `field_order`** on the form so it renders last — when appending fields, re-check this.
6. **`form_select` is never empty** on divider (repeater) and dynamic (data) fields — see `references/repeaters.md` and `references/forms-and-fields.md`.
7. **Verify after writing.** After creating or changing anything, verify via MCP reads (and browser inspection for rendering) before declaring success.
8. **Cache:** if fields don't appear in the form editor after API changes, it's almost always browser cache — hard refresh first; server caches are cleared automatically by the API (see `references/forms-and-fields.md` for the manual wp-cli cache clear if needed).
9. **Keys in content, numeric IDs in settings.** Use field/form/view KEYS in shortcodes and entry payloads (`[preferred-shift]`, `[formidable id=my-form]`), and numeric field IDs in stored settings — conditional logic (`hide_field`), `calc`, `form_select`, `in_section`, lookup fields, view `order_by`/`where`/`date_field_id`, and action settings like quiz `enable`. A key in a setting is **silently ignored**, not rejected. IDs in settings are import-safe (Formidable remaps them), so portability is not a reason to avoid them. Details and the full list in `references/repeaters.md` § "Keys in CONTENT, Numeric IDs in SETTINGS". Entry payloads accept either form at every level; the one structural rule there is that repeater ROWS must be keyed `i0`, `i1`, … (see § "Writing Entry Data for Repeaters").
