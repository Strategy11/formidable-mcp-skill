# Coupons (Formidable Coupons add-on)

Read this when: creating or editing discount codes, assigning coupons to forms, or debugging a coupon that shows the wrong status or refuses to discount. Source: `formidable-coupons` plugin code + an end-to-end run on a live pricing form (coupon applied, entry submitted, usage counter incremented, limit exhaustion verified).

## Abilities

| Ability | Notes |
|---|---|
| `list-coupons` | `page`, `page_size` (default 20), `order` (asc/desc), `order_by` (`id`/`name`/`date`/`modified`), `search` (matches name **or** code), `form_id` (only coupons usable on that form) |
| `get-coupon` | `id` accepts the numeric ID **or the coupon code** |
| `create-coupon` | requires `name`, `code`, `amount` — but see the draft trap below, three fields is not enough to get a working coupon |
| `update-coupon` | `id` (ID or code); only the keys you send change |
| `delete-coupon` | `id` (ID or code); destructive |

`id` accepting a code everywhere means you rarely need `list-coupons` first — `get-coupon {"id": "SUMMER25"}` works.

## The two things a coupon needs to actually work

`create-coupon`'s required fields (`name`, `code`, `amount`) produce a coupon that **discounts nothing**. Two more things are needed, and neither is required by the schema:

### 1. A `start` date, or the coupon is a permanent draft

`FrmCouponsAppHelper::check_coupon_object_for_status()`:

```php
if ( empty( $coupon_data->amount ) || empty( $coupon_data->start ) ) {
    return 'draft';
}
```

Omit `start` and the coupon comes back `status: "draft"` and never applies — no error, no warning. The admin UI always sets a start date, so this is reachable only through the API. **Always send `start`** as `YYYY-MM-DD HH:MM` in the site timezone; use now (or the past) for a coupon that should work immediately.

### 2. At least one form in `allowed_form_ids`, and that form needs a Coupon field

`allowed_form_ids` is not stored on the coupon. It is derived from the `allowed_coupons` setting on each form's **coupon field** — assigning a coupon writes the coupon's ID into `field_options['allowed_coupons']` on that field.

Two consequences:

- **Empty `allowed_form_ids` means the coupon works on NO form**, not on all of them. `FrmCouponsFilterHelper::filter_coupons_for_form()` returns `array()` when the form has no coupon field or its `allowed_coupons` is empty.
- **A form with no Coupon field is silently dropped.** `assign_coupon_to_form()` starts with `FrmProFormsHelper::has_field( 'coupon', $form_id )` and `return`s if there isn't one. No error surfaces; the ID just never appears in `allowed_form_ids`. So `list-fields` the target form for a `coupon` field first, and **read `allowed_form_ids` back** after the write to confirm the assignment landed.

`allowed_form_ids` **replaces** the whole assignment set rather than adding to it — send the full list every time. Omit the key to leave assignments alone.

### Working create call

```json
{
  "name": "Summer Sale 25",
  "code": "SUMMER25",
  "amount": "25%",
  "start": "2026-06-01 00:00",
  "end": "2026-08-31 23:59",
  "limit": 100,
  "minimum_order_value": 50,
  "allowed_form_ids": [1429]
}
```

## Amount and discount type

`amount` is a flat amount or a percentage — the trailing `%` is the only difference, and it is what sets the read-only `discount_type`:

- `10` → `discount_type: "flat"`, takes 10 off the total
- `"10%"` → `discount_type: "percent"`, takes a tenth off (1–100)

There is no separate type parameter. Send `amount` as a string when using a percentage.

## Status is computed, never set

There is no `status` input. It is derived on every read, in this order (`check_coupon_object_for_status`):

| Status | Cause |
|---|---|
| `draft` | empty name, empty code, empty `amount`, **or empty `start`** |
| `invalid` | `post_content` isn't decodable JSON (corrupt row) |
| `scheduled` | `start` is in the future |
| `expired` | `end` is set and in the past |
| `limit_reached` | `uses` has hit `limit` |
| `active` | none of the above |

`status_label` is the same value translated for display. Reading `status` back after a write is the cheapest check that a coupon is live — do it every time.

## Usage and limits

- `uses` counts entries that submitted with the code. It is read-only and increments on real front-end submissions (verified: two submissions → `uses: 2`).
- `limit` is the maximum number of entries that may use the coupon. Empty or `0` means unlimited.
- Exhaustion genuinely blocks the discount, not just the reported status: once `uses >= limit`, applying the code on the front end leaves the total unchanged and shows an error. Note the front-end message is **"Invalid coupon code"** rather than anything about the limit — pre-existing add-on wording, and misleading when debugging.
- Lowering `limit` below the current `uses` immediately flips the status to `limit_reached`.

## Editing a used coupon

Once a coupon has been used on an entry, its `code` and `amount` are frozen — those keys are rejected on `update-coupon`. Everything else (dates, limit, minimum, form assignments) stays editable. Create a new coupon rather than trying to repoint an old one.

Deleting a coupon leaves submitted entries alone: they keep the code and discount they were submitted with.

## What a coupon needs on the form side

A coupon only ever applies through a **`coupon` field** on the form (`create-field` type `coupon`). For the discount to be visible there also has to be something to discount:

- a `product` field whose options carry prices — **options need a `price` key**, `{"label": "Widget", "price": "100", "value": "widget"}`. `{label, value}` alone renders `data-frmprice=""` and a permanently $0.00 total. The full option shape is `{label, price, value, image, limit}`, and `create-field`/`update-field` both accept `price` even though the schema description doesn't mention it.
- optionally a `quantity` field pointing at the product (`"product_field": "[3334]"`)
- a `total` field for the discounted total

Verified end to end: Widget ×2 = $200.00 → `SUMMER25` applied → $150.00, entry stored `E2EQUARTER — $50.00 Off (25%)` with total `$150.00`.

## Verifying in a browser

Formidable's price calculation listens for real input events. Programmatically setting a field's `value` does not fire them and leaves the total at $0.00 — dispatch `input`/`change` events, and drive the Apply button via JS click (`browser_click` times out on the stability wait). See `formidable-playwright` for the pattern.
