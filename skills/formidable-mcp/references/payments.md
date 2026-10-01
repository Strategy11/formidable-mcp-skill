# Payments (Stripe / Square / PayPal / Authorize.net)

Read this when: adding a payment field to a form, creating/configuring a payment gateway action, or listing/refunding/cancelling payment and subscription records. Source: `FrmFormActionsController::get_form_actions()`, the payment/subscription ability schemas in `mcp-protocol.md`, and `templates.md`'s form-template XML notes — **not** an end-to-end verified run, because exercising a payment action requires live gateway credentials (see the warning below). When working with an unfamiliar payload shape, read an existing payment action on a real form first (`list-form-actions` → `get-form-action`) rather than trusting this file blindly.

**Never submit a test payment against a connected merchant account.** Payment actions (`stripe`, `square`, `paypal`, `payment`) charge a real gateway. Verify configuration by reading the action back (`get-form-action`) and inspecting the rendered field in a browser — don't complete a checkout to confirm it works.

## Three separate layers

Payments in Formidable span three things that are easy to conflate:

1. **A payment field on the form** — collects the card/billing UI. Lite has `credit_card`; Pro adds `payment-gateway` (a richer, gateway-aware field).
2. **A payment gateway action on the form** — the `stripe` / `square` / `paypal` / `payment` action type, which wires a field's collected amount to a gateway, charges it on submit, and can set up recurring billing. This is what you create/edit via MCP.
3. **Payment and subscription records** — read-only transaction/subscription rows created by the gateway's own checkout flow after a real charge. MCP can list, read, delete, refund, and cancel these — but never create or edit them directly.

## Layer 1: Payment fields

| Field type | Tier | Notes |
|---|---|---|
| `credit_card` | Lite | Basic payment field |
| `payment-gateway` | Pro | Gateway-aware payment field |

Like any field, create via `create-field` with `type` set to one of the above, on the target `form_id`. Pair it with a `total`/`product`/`quantity` setup (same pattern as `coupons.md` § "What a coupon needs on the form side") when the amount needs to be computed from line items rather than fixed.

## Layer 2: Payment gateway actions

### Registered types and per-form limits

On a fully-loaded install (verified via `FrmFormActionsController::get_form_actions()`), the active payment action types are `stripe`, `square`, `paypal`, `payment`. Each is `limit => 1` — one payment action per form, same as `wppost`, `register`, `quiz`. Create it with `create-form-action`, `form_id` + `type` + `post_content`, the same call shape as every other action type (see `actions.md`).

### `payment` (Stripe / Square / Authorize.net gateway)

`post_content` keys (from `templates.md`'s template-XML schema — confirm against a live `get-form-action` before relying on any key not listed here):

| Key | Notes |
|---|---|
| `gateway` | `["stripe"]` \| `["square"]` \| `["authnet"]` |
| `amount` | reference to a `total`/fixed amount field |
| `credit_card` | the `credit_card`/`payment-gateway` field's ID |
| `currency` | e.g. `"USD"` |
| `type` | `"single"` \| `"recurring"` |
| `interval`, `interval_count` | recurring billing cadence (only relevant when `type: "recurring"`) |
| `billing_first_name`, `billing_last_name`, `email`, etc. | billing field mappings |

### `stripe` / `square` / `paypal` (standalone gateway action types)

These are registered as their own action types (distinct from the generic `payment` type above) and follow the same `post_content` shape family — gateway credentials/mode, amount source, and event triggers. Read an existing action of the specific type first; this skill has no verified working payload for these three yet.

### Form-level payment defaults

`update-form`'s `options` object carries site-wide payment defaults used when an action doesn't override them: `currency`, `business_email`, `return_url`, `cancel_url` (see `templates.md` § "Form Options").

### `event` values

Payment actions accept `event: ["create"]` like other action types, plus `"payment-success"` is available to **other** actions (e.g. `gated_content`) that need to fire only after a successful charge rather than on every submission — see `actions.md` § "Gated content" for the `event` table.

## Layer 3: Payment and subscription records (Lite core, no add-on required)

Read/manage transaction records from whichever gateway processed them. **No create/edit** — a payment or subscription is created by the gateway's own checkout flow, never via MCP.

| Ability | Description | Notes |
|---|---|---|
| `list-payments` | List payments — `form_id`, `status`, `page`, `page_size`, `order_by`, `order` | readonly, idempotent |
| `get-payment` | Get one payment by `id` | readonly |
| `delete-payment` | Delete a payment record | destructive |
| `refund-payment` | Refund a payment through its original gateway (dispatches on the payment's `paysys`: `stripe`/`square`/`paypal`) | destructive, not idempotent |
| `list-subscriptions` | List subscriptions — same params as `list-payments` | readonly, idempotent |
| `get-subscription` | Get one subscription by `id` | readonly |
| `delete-subscription` | Delete a subscription record | destructive |
| `cancel-subscription` | Cancel a subscription through its original gateway (dispatches on `paysys`) | destructive, not idempotent |

Payment object fields: `id`, `item_id`, `action_id`, `receipt_id`, `invoice_id`, `sub_id`, `amount`, `status`, `paysys`, `begin_date`, `expire_date`, `created_at`, `test`.

Subscription object fields: `id`, `item_id`, `action_id`, `sub_id`, `amount`, `first_amount`, `interval_count`, `time_interval`, `fail_count`, `end_count`, `next_bill_date`, `status`, `paysys`, `created_at`, `test`.

`refund-payment` and `cancel-subscription` are **destructive and not idempotent** — they reach out to the live gateway (Stripe/Square/PayPal) and reverse a real transaction. Confirm the `id` with `get-payment`/`get-subscription` first, and treat these like any other irreversible action against a shared system: don't run them without the user's go-ahead on a real record.

`test` on both objects flags gateway test-mode transactions — check it before assuming a record reflects real money.

## Verifying a payment action's configuration (no live charge required)

1. `create-form-action` / `update-form-action` with the payload above.
2. `get-form-action` to read the stored `post_content` back and confirm every key landed.
3. Load the form in a browser (Playwright) and confirm the payment field renders — card element mounts, amount displays — without submitting.
4. For an existing site with real transaction history, `list-payments`/`list-subscriptions` filtered by `form_id` is the read-only way to confirm the action is actually being exercised in production, without generating new records yourself.
