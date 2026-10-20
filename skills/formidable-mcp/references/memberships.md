# Memberships (Formidable Memberships add-on)

Read this when: managing membership levels or inspecting memberships, groups, gifts and invitations. This covers all 11 abilities registered by `formidable-memberships`.

Source: the add-on's `docs/mcp.md`, `FrmMbrAbilities*Controller` registrations and callbacks, and `FrmMbrLevel`. The ability integration is version-dependent; do not assume an older installed add-on exposes it.

## Availability, permissions and calls

Requires the Memberships add-on, active Formidable Pro, Formidable's Abilities API and shared MCP setting, and a license not expired outside its grace period. Missing abilities can mean an inactive or outdated add-on, disabled MCP, or a Pro/license gate. Use [mcp-protocol.md](mcp-protocol.md) for connection and schema inspection.

Prefix every ability below with `formidable-forms/`. Level reads and writes require `frm_change_settings`; membership, group and gift reads require `frm_view_entries`.

All IDs here are positive JSON integers from list responses, not keys, slugs or entry IDs. Collections accept `page` (default 1) and `page_size` (default 20, range 1–200), return arrays ordered by descending ID, and continue until an empty array. Filters combine; omit a filter to leave it unrestricted. Schemas reject extra properties. Get/delete calls take `{"id":123}`. Missing records return structured 404 errors.

## Complete ability catalog

| Ability | Inputs and behavior |
|---|---|
| `list-membership-levels` | Paging; optional `active` (integer 0/1), `type` (`free`/`paid`) |
| `get-membership-level` | Required `id`; returns level configuration |
| `create-membership-level` | Required `name`; optional level settings below; returns saved level and `warnings` |
| `update-membership-level` | Required `id`; only supplied settings change; returns saved level and `warnings` |
| `delete-membership-level` | Required `id`; permanent deletion; returns deleted level; refuses referenced levels |
| `list-memberships` | Paging; optional `user_id`, `level_id`, `entry_id`, `group_id`, `status`, `payment_status` |
| `get-membership` | Required `id`; inspect one membership and its lifecycle/payment state |
| `list-membership-groups` | Paging; optional `owner_user_id`, `level_id` |
| `get-membership-group` | Required `id`; inspect a group's owner, membership, level and seats |
| `list-membership-gifts` | Paging; optional `level_id`, `purchaser_user_id`, `group_id`, `status`, `kind`; includes invitations |
| `get-membership-gift` | Required `id`; inspect gift/invitation metadata; no redemption code |

Status, payment-status and gift-kind filters are strings rather than schema enums. Use values observed in site records or the installed schema/documentation; do not invent state names. Numeric list filters accept 0, but 0 filters for that value rather than meaning “all.”

## Level settings

| Setting | Accepted value and meaning |
|---|---|
| `name` | Nonempty string, at most 255 characters |
| `slug` | Unique slug, at most 200 characters; defaults from name on creation |
| `type` | `free` or `paid` |
| `price` | Nonnegative number up to 99999999.99, or `null`; display price in **major currency units** |
| `wp_role` | Existing editable WordPress role; empty string means no role |
| `requires_approval` | Integer 0/1 |
| `approval_order` | `payment_first` or `approval_first` |
| `duration_days` | Integer 0–36500; 0 means lifetime |
| `restrict_behavior` | `hide` or `message` |
| `restrict_message` | Restricted-content message; allowed post HTML is preserved |
| `active` | Integer 0/1; whether the level accepts new members |
| `level_rank` | Nonnegative integer, maximum 2147483647 |
| `seats_included` | Nonnegative integer, maximum 2147483647 |
| `owner_uses_seat` | Integer 0/1 |

Creating a paid level does **not** configure a charge: payment actions determine the actual charge. Read [payments.md](payments.md) and [actions.md](actions.md) for related form configuration. Do not charge a card to verify a level.

Role changes follow the level editor's editable-role and promotion checks. Invalid roles fail validation. Assigning an administrator-tier role without `promote_users` is forbidden; a permitted save may return `warnings` with `code: "role_not_granted"`, meaning activation will not grant that role. Report the warning and choose a suitable less privileged role when that matches the user's request; a successful save alone does not prove members receive the requested role.

Example parameters for `create-membership-level`:

```json
{
  "name": "Annual Member",
  "slug": "annual-member",
  "type": "paid",
  "price": 120,
  "duration_days": 365,
  "requires_approval": 1,
  "approval_order": "payment_first",
  "restrict_behavior": "message",
  "restrict_message": "<p>An active membership is required.</p>",
  "active": 1
}
```

Read the saved level back with `get-membership-level` and inspect write-response warnings. `delete-membership-level` returns `frm_memberships_level_in_use` (409) when references remain. Prefer `update-membership-level` with `active: 0` when retiring a referenced level; deactivation controls new enrollment and is not an ability to cancel existing memberships.

## Inspecting operational records

Memberships expose user/level/entry/group links, approval and previous-level IDs, status and payment status, subscription ID, renewal flags/counts, and lifecycle dates (start, expiry, trial, pause, payment, past due, creation/update). `get-membership` takes the membership row's ID, not its `entry_id`; use `list-memberships` with `entry_id` to find it.

Groups expose `owner_user_id`, `owner_membership_id`, `level_id`, `seats_total`, `name` and creation/update dates. Gift/invitation records expose purchaser and redeemer IDs, entry/group/level links, recipient email, delivery method, status, kind, creation/redemption dates. **Redemption codes are excluded**; there is no ability to fetch a usable invitation link or secret code.

Memberships, groups and gifts have **list/get only**. Enrollment, approval, cancellation, renewal, group/seat changes, gift purchases, invitations and redemption use the product's normal form, payment and invitation workflows. Do not invent create/update/delete abilities for these records or simulate lifecycle transitions with database/REST writes. When a requested transition has no MCP ability, explain the boundary and the appropriate normal workflow.
