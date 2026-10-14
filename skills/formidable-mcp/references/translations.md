# Translations (requires the WPML compatibility add-on, with WPML itself active)

Read this when: listing what's translatable on a form, or reading/creating/updating/deleting a specific string's translation. Source: the translation ability schemas — **not yet end-to-end verified against a live WPML install** (no run of `list-translatable-strings` → `create-translation` → confirm-in-frontend has been recorded here). Confirm behavior against a real `list-translatable-strings` call before relying on assumptions beyond what's below.

**Requires two things active at once:** the WPML compatibility add-on for Formidable, *and* WPML itself (String Translation) configured with at least one secondary language. Without both, these abilities are unavailable or return nothing.

## What this manages

Every normally-translatable string in a form — labels, descriptions, choices, validation messages, at both the form level and the field level — backed by WPML's own String Translation tables (`icl_strings`, `icl_string_translations`). This is **not** a general multilingual/WPML content ability set; it only covers Formidable form strings, and only through WPML.

## Abilities

| Ability | Description | Notes |
|---|---|---|
| `list-translatable-strings` | List every translatable string for a form — requires `form_id`, optional `search` | readonly, idempotent |
| `get-translation` | Get one string's translation in a given language — requires `string_id` + `language` | readonly |
| `create-translation` | Add a translation for a `string_id` + `language`; **errors if one already exists** | not idempotent |
| `update-translation` | Update an existing translation for a `string_id` + `language`; **errors if none exists** | not idempotent |
| `delete-translation` | Delete a single translation row by `translation_id` — deletes only that language's translation, not the source string or its other translations | destructive |

## Two IDs, easy to mix up

- **`string_id`** — the id of the *source string* (a row in WPML's `icl_strings`). Returned by `list-translatable-strings` as each item's `id`. Used by `get-translation`, `create-translation`, `update-translation`.
- **`translation_id`** — the id of one *specific translation* (a row in WPML's `icl_string_translations`). Returned by `get-translation`/`create-translation`/`update-translation` as `translation_id` in their response. Used only by `delete-translation`.

There is **no bulk "delete all translations of this string"** ability — that would require unregistering the source string entirely, which this ability set intentionally doesn't expose. To clear every language for one string, call `delete-translation` once per known `translation_id`.

## Typical sequence

1. `list-translatable-strings` (`form_id`) — see every string and its `string_id`. Use `search` to narrow a long form.
2. `get-translation` (`string_id` + `language`) — check whether a translation already exists for the target language, and see its current value.
3. Depending on step 2: `create-translation` (none existed) or `update-translation` (one did) with `string_id` + `language` + the translated text.
4. `delete-translation` (`translation_id`) if a translation needs removing later — note this takes `translation_id`, not `string_id`.

## Create vs update — don't guess, check first

`create-translation` and `update-translation` are strict about which state they expect (error on the wrong one), so step 2 above isn't optional — always `get-translation` before writing, rather than assuming a translation does or doesn't exist yet.

## Verifying in a browser

WPML determines the front-end display language from the site's language switcher / URL structure, not from anything Formidable-specific. After writing a translation via MCP, load the form on the translated-language URL (Playwright) and confirm the specific string changed — reading the translation back via `get-translation` only confirms the row was written, not that WPML is actually serving it on that page.
