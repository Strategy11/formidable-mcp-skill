# Bookings (Formidable Bookings add-on)

Read this when: configuring resources/staff, locations, services, hours, assignments or time-off; checking availability; inspecting bookings and waitlists. This covers all 29 abilities registered by `formidable-bookings`.

Source: the add-on's `docs/mcp.md`, `FrmBookAbilities*Controller` registrations and callbacks, and the resource/location/service models. The ability integration is version-dependent; do not assume an older installed add-on exposes it.

## Availability, permissions and identifiers

Requires the Bookings add-on, active Formidable Pro, Formidable's Abilities API and shared MCP setting, and a license not expired outside its grace period. Catalogue, schedule and availability operations use `FrmBookResourceController::user_can_manage()`, the resource-management permission used in admin. Booking/waitlist reads use `FrmBookAppHelper::can_view_bookings()` and preserve the current user's staff scope. Use [mcp-protocol.md](mcp-protocol.md) for connection and schema inspection.

Prefix every ability below with `formidable-forms/`. IDs are JSON integers from list responses; catalogue UUIDs are returned metadata, not substitutes for numeric input IDs. Get/update/delete catalogue calls use `id`; hours and assignments use `resource_id`; time-off get/update/delete require **both** `resource_id` and block `id`.

Collections accept `page` (default 1) and `page_size` (default 20, range 1–200), return arrays ordered by descending ID, and continue until empty. Filters combine; omit a filter to leave it unrestricted. Schemas reject extra properties. Missing records return structured errors; an empty staff-scoped list does not prove that no records exist site-wide.

## Complete ability catalog

| Ability | Inputs and behavior |
|---|---|
| `list-booking-resources` | Paging; optional `location_id`, `type` (`resource`/`staff`), `active` (integer 0/1) |
| `get-booking-resource` | Required `id` |
| `create-booking-resource` | Required `name`; optional resource settings below; staff use the same ability |
| `update-booking-resource` | Required `id`; supplied fields change; `settings` replaces the override map |
| `delete-booking-resource` | Required `id`; refuses resources/staff referenced by any booking |
| `list-booking-locations` | Paging; optional `active` (integer 0/1) |
| `get-booking-location` | Required `id` |
| `create-booking-location` | Required `name`; optional `address`, `active` |
| `update-booking-location` | Required `id`; optional `name`, `address`, `active` |
| `delete-booking-location` | Required `id`; permanent deletion |
| `list-booking-services` | Paging; optional `active` (integer 0/1) |
| `get-booking-service` | Required `id` |
| `create-booking-service` | Required `name`; optional `description`, `duration_minutes`, `rate_minor`, `active` |
| `update-booking-service` | Required `id`; optional service settings as above |
| `delete-booking-service` | Required `id`; permanent deletion |
| `get-booking-resource-hours` | Required `resource_id`; returns weekly segments |
| `set-booking-resource-hours` | Required `resource_id`, `hours`; replaces the whole week |
| `get-booking-resource-services` | Required `resource_id`; returns assigned service IDs |
| `set-booking-resource-services` | Required `resource_id`, `service_ids`; replaces the whole assignment set |
| `list-booking-time-off` | Required `resource_id`; optional paging |
| `get-booking-time-off` | Required `resource_id`, `id` |
| `create-booking-time-off` | Required `resource_id`, `start_datetime`, `end_datetime`; optional `reason`; creates a manual block |
| `update-booking-time-off` | Required `resource_id`, `id`; optional `start_datetime`, `end_datetime`; only manual blocks |
| `delete-booking-time-off` | Required `resource_id`, `id`; only manual blocks |
| `get-booking-availability` | Required `form_id`, `date`; optional `resource_id`, `staff_id`, `service_id`; read-only |
| `list-bookings` | Paging; optional `form_id`, `resource_id`, `staff_id`, `service_id`, `entry_id`, `status`, `payment_status` |
| `get-booking` | Required `id`; staff-scoped read |
| `list-booking-waitlist` | Paging; optional `form_id`, `resource_id`, `staff_id`, `status` |
| `get-booking-waitlist-entry` | Required `id`; staff-scoped read |

Catalogue writes return the saved record; successful deletes return the removed record. Updates preserve omitted fields, except the explicitly supplied replacement collections/maps described below.

## Resources, staff, locations and services

Resource inputs: `name` (nonempty, ≤255 characters), `type` (`resource`/`staff`), `location_id` (0 = none), `capacity` (integer ≥1), `buffer_before`/`buffer_after` (nonnegative minutes), `active` (integer 0/1), `user_id` (0 = no linked WordPress user), and `settings` (object). Nonzero location and user IDs must exist. Staff are resources with `type: "staff"`; `staff_id` in availability/bookings is a resource ID, not a WordPress user ID.

`settings` is a **complete replacement override map**, not a patch. Read the resource first, merge intended changes locally, and send the full desired map. Omit `settings` to preserve it; send `{}` to reset inheritance. Supported keys:

| Keys | Value |
|---|---|
| `duration` | Integer minutes ≥1 |
| `min_lead_minutes`, `max_advance_minutes`, `rate_unit_minutes`, `max_booking_minutes`, `min_booking_minutes` | Nonnegative integer minutes |
| `max_advance_days` | Nonnegative integer days |
| `reminder_hours`, `change_cutoff_hours` | Nonnegative integer hours |
| `rate_multiplier_pct` | Nonnegative integer percentage |
| `rate_minor` | Nonnegative integer hundredths of a major currency unit; `1250` means `12.50`; 0 inherits |
| `booking_mode_flexible`, `require_approval`, `ics_attach`, `allow_self_cancel`, `allow_self_reschedule`, `enable_waitlist` | Integer 0/1 |
| `checkin_time`, `checkout_time` | Site-local `HH:MM` |

Integer settings are capped at 2147483647 except `rate_minor`, capped at 999999999999. Resource `capacity` and buffers also cap at 2147483647. Calendar feed URLs and internal calendar identifiers are excluded from responses and are not accepted settings.

Locations accept `name` and `address` (each ≤255 characters) and `active` (integer 0/1). Services accept `name`, `description` (each ≤255 characters), `duration_minutes` (integer 0–2147483647), `rate_minor` (integer 0–999999999999), and `active` (integer 0/1). Names cannot be blank. Service duration/rate of 0 inherit from the resource. Membership level `price` uses major units; booking `rate_minor` uses integer hundredths—do not interchange them.

Deleting a location resets its resources' `location_id` to 0; deleting a service removes its resource/service assignments. Account for these side effects when fulfilling deletion requests and verify the affected catalogue relationships afterward.

Resource creation defaults to active and seeds a **full open week**. For staged setup, create with `active: 0`, replace its hours and assignments, verify, then activate when requested. Resource creation/update can report a settings-save failure **after** saving the resource itself; inspect catalogue state before retrying to avoid duplicates.

`delete-booking-resource` returns `frm_bookings_resource_has_bookings` (409) if **any** booking references it as resource or staff, including cancelled and past bookings. Use `update-booking-resource` with `active: 0` to retire it while retaining history.

## Weekly hours and service assignments

`set-booking-resource-hours` replaces every weekly segment. `hours: []` closes the resource. Each segment requires `weekday` (0 = Sunday, 6 = Saturday), `start_time`, `end_time` as `HH:MM:SS` with seconds exactly `00`. End must follow start; segments on the same weekday cannot overlap. At most 100 segments. All times use the site timezone; the schema does not accept `24:00:00`.

Example parameters for `set-booking-resource-hours` (replace 123 with the discovered resource ID):

```json
{
  "resource_id": 123,
  "hours": [
    {"weekday": 1, "start_time": "09:00:00", "end_time": "12:00:00"},
    {"weekday": 1, "start_time": "13:00:00", "end_time": "17:00:00"}
  ]
}
```

This opens **only Monday**, with a lunch break; it does not preserve other days. Read existing hours before editing one day and send the complete intended week. Verify with `get-booking-resource-hours`.

`set-booking-resource-services` takes `{"resource_id":123,"service_ids":[456,789]}`. Supply unique existing service IDs (at most 500); all must exist before saving. `service_ids: []` removes all assignments. Verify with `get-booking-resource-services`. Catalogue creation and resource/service assignment do not alone establish what a particular booking form offers: inspect/configure its fields using core abilities and [forms-and-fields.md](forms-and-fields.md).

## Time-off

Use site-local `YYYY-MM-DD HH:MM:SS` datetimes; end must be after start and both must be real dates. Create optionally accepts `reason` (≤255 characters). Updates can change dates only, not reason or resource ownership. Always identify a block using its own `id` together with its owning `resource_id`.

Read responses include `source`. Blocks from external calendar synchronization are read-only: update/delete returns `frm_bookings_external_time_off` (409). Manage those through the calendar source; do not recreate them as manual blocks. Verify manual edits with `get-booking-time-off` and deletion with a subsequent read/list.

## Availability and operational reads

`get-booking-availability` requires an existing **booking form** and a real site-local `date` (`YYYY-MM-DD`). Resource and staff IDs must be offered by that form; a service ID must be among its service options. Omit `service_id` when there is no service selection. Optional axis IDs accept 0, but for a specific resource/staff/service check send the actual offered IDs.

The response contains `form_id`, `date`, `timezone`, `waitlist` and `slots`. Each slot exposes local `start`/`end`, UTC `start_utc`/`end_utc`, and `state` (`free`/`full`). It uses the booking picker's shared rules and conflict checks, including form offerings, service, hours and resource/staff selection. It **does not reserve or hold** a slot; availability can change after the read.

Bookings expose entry/form/resource/staff/service IDs, local start/end datetimes, status, cancellation attribution, payment status, amounts/currency/rate information, customer email, reminder/hold and creation/update dates. Waitlist records expose entry/form/resource/staff links, local start/end, customer email, status, notification and creation/update dates. Use `entry_id` on `list-bookings` to find a booking linked to a Formidable entry; `get-booking` takes the booking ID.

Status/payment-status filters are strings, not schema enums. Read actual site values rather than guessing. Lists are intersected with the caller's staff scope; out-of-scope gets can return 403, and a caller with no matching staff scope can receive an empty list. Do not treat this as an unfiltered site-wide report.

Booking and waitlist records have **list/get only**. There are no abilities here to create, cancel, reschedule, approve or delete a booking, or add/promote/remove a waitlist record. Those operations belong to the product's normal booking workflows; do not invent ability names or bypass them with REST/database writes. Verify setup with catalogue/schedule reads and availability, without submitting a real booking or test payment unless explicitly requested.
