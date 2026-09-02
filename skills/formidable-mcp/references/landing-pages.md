# Form Landing Pages (Formidable Landing Pages add-on)

Read this when: giving a form its own standalone page at the site root, editing that page's content or design, or debugging a landing page that doesn't render. Source: `formidable-landing` plugin code + an end-to-end run (page created, rendered on the `frm_landing_page` template, submission accepted from it, upsert and delete invariants checked in the DB).

## The one rule that shapes everything: a form has at most one landing page

The relationship is 1:1. That is why the write ability is an **upsert** rather than a create:

| Ability | Use |
|---|---|
| `list-landing-pages` | `page`, `page_size` (default 25), `status` (`publish`/`private`/`draft`), `order` |
| `get-landing-page` | `form` (ID or key) **or** `id` (post ID). Returns 404 when the form has none — this is the way to ask "does this form have a landing page?" |
| `save-landing-page` | **The write to use.** Requires `form`; creates when the form has none, updates when it has one. Never produces a second page. Idempotent — same input twice changes nothing |
| `update-landing-page` | By landing page `id` only. Cannot move a page to a different form. Prefer `save-landing-page` unless you already hold the post ID |
| `delete-landing-page` | `form` or `id`, plus `force` (default `true`) |

`save-landing-page` returns two extra keys beyond the page object: `created` (true when it created rather than updated) and `form_embed_injected` (see below). Verified: calling it again with the same `form_key` returned the same id with `created: false`.

## Two switches, both required to serve the page

A landing page renders on the front end only when **both** are true:

- `status` is `publish` — `private` and `draft` are not served
- `enabled` is `true` — the add-on's on/off toggle in the form settings

`enabled: false` takes the page off the front end without deleting it, which is the right way to temporarily retire one. A published-but-disabled page is the most common "why is this 404ing" cause.

## Where the settings actually live

Split across two places, which matters when verifying in the DB:

**On the post** (`frm_landing_page` post type): `title`, `slug` (`post_name`), `status`, `content`.

**On the form's `options`** (written through `FrmForm::update`, so hooks and caches fire): `enabled` → `landing_page_id` (holds `'1'` or `''` — despite the name, nothing reads it as an ID), `layout` → `landing_layout`, `bg_image_id` → `landing_bg_image_id`, `opacity` → `landing_opacity`.

So the design settings are per-form, not per-post, and `update-landing-page` by post ID still writes them onto the owning form.

## Slugs compete with the whole site

Landing pages are served **from the site root**, so the slug shares a namespace with every page and post on the site. Consequences:

- A slug already in use, or a WordPress reserved word, is **rejected** with `frm_landing_slug_taken` — it does not get silently suffixed.
- Omitting `slug` derives one from the form name, falling back to `sanitize_title( $form->form_key )`. If nothing usable can be derived you get `frm_landing_invalid_slug` asking for an explicit slug.
- Slugs are run through `sanitize_title()`, so send something already slug-shaped to avoid surprises.
- `title` defaults to the form name, or to the slug when the form is unnamed.

## Content: the form embed is guaranteed

`content` is optional and the add-on makes sure the page always shows its form:

1. **Omitted on create** → content becomes just the canonical block embed:
   ```html
   <!-- wp:formidable/simple-form {"formId":"1429","title":"1","description":"1"} -->
   <div>[formidable id="1429" title="1" description="1"]</div>
   <!-- /wp:formidable/simple-form -->
   ```
2. **Omitted on update** → the existing content is kept untouched.
3. **Supplied HTML that already embeds the assigned form** → kept verbatim, `form_embed_injected: false`. The check counts both the shortcode and the form block, and matches on either the form **ID or key**. An embed of a *different* form does not count.
4. **Supplied HTML with no embed of that form** → your HTML is kept and the embed is **appended** after a blank line, `form_embed_injected: true`.

So to control where the form sits on the page, include the embed yourself at the position you want. Verified both ways: extra HTML around a hand-written embed survived verbatim, and prose with no embed came back with a working form appended.

**Sanitization:** content is passed through `wp_kses_post()` unless the calling user has `unfiltered_html` — the same treatment the block editor gives. Block delimiter comments and the form shortcode survive; `<script>` tags and event-handler attributes do not.

## Design

`layout` is an enum: `default`, `block`, `left`, `right`. `bg_image_id` is an attachment ID, with `0` meaning "fall back to whatever the form's style supplies". `opacity` is clamped to 0–100.

## Delete

`delete-landing-page` hard-deletes by default and switches the form's `landing_page_id` toggle off at the same time, leaving the form with genuinely no landing page. Verified clean: post gone, zero orphan form options, URL 404s.

This is **better behaved than the add-on's own delete button**, which only trashes the post and leaves the toggle on — so the next form-settings save regenerates a page. Prefer the ability.

`force: false` trashes instead, and a trashed page **still counts as the form's landing page** — `save-landing-page` will update that trashed post rather than create a fresh one. Use `force: false` only when you intend to restore it.
