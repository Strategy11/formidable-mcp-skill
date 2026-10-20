# Workflow definitions and runs

Use these abilities when the Formidable Workflows add-on is active and includes `FrmWfAbilitiesController`. Older builds expose no workflow MCP abilities. They share the existing Formidable MCP connection and `formidable-forms` category, including scoped connection files. No separate credentials, REST requests, or database writes are needed.

## Discover the installed feature set

Call `formidable-forms/get-workflow-schema` first. It returns `triggers`, `step_types` (label, availability, configuration fields, outcomes), `step_input_schema`, and `routing_choices`. Derive settings from this response rather than assuming every add-on is installed. `send_api` and `send_sms`, for example, depend on their corresponding add-ons.

The shared MCP toggle must be enabled, Formidable must provide its abilities helpers, and Pro must be active with a license inside its allowed period. Definition abilities require `frm_edit_forms`. Run inspection requires `frm_view_entries`, independently of definition editing. A Formidable version without the shared helpers leaves this optional integration off without affecting the workflow builder.

## Abilities

Every name below has the `formidable-forms/` prefix.

| Ability | Input | Result |
|---|---|---|
| `get-workflow-schema` | `{}` | Installed step configuration fields, triggers, and input shape |
| `list-workflow-templates` | `{}` | Starter templates with `slug`, `name`, `description`, `trigger_type`, and builder `steps` |
| `list-workflows` | Optional `form_id`, `is_active`, `page`, `page_size` | Array of definitions, newest first |
| `get-workflow` | `id` | One definition, stored `steps`, reusable `builder_steps`, and `problems` |
| `create-workflow` | Required `name`, numeric `form_id`. Optional settings and `steps` | Saved definition plus `activation_refused` |
| `update-workflow` | Required `id`. Only settings being changed | Saved definition plus `activation_refused` |
| `delete-workflow` | `id` | `{id, deleted}`. Cancels active runs and their timers through the engine, retaining audit history |
| `list-workflow-runs` | Optional `workflow_id`, `status`, `page`, `page_size` | `{runs, total, total_pages}` |
| `get-workflow-run` | `id` (run ID, not workflow ID) | Run summary with entry, workflow, form, status, current step, and timestamps |

IDs are positive integers. Page numbering starts at 1. Page size defaults to 50 and is capped at 200. `list-workflows` has no total count, so paginate until a page is short. Run summaries omit internal context and task access tokens. This initial integration does not expose task decisions, manual triggering, cancellation, or run logs as MCP abilities.

## Settings and activation

Writable settings: `name`, `form_id`, `trigger_type`, `is_active`, `hold`, `reject_disposition`, `hold_actions`, `steps`.

- Creation defaults to **inactive**, trigger `create`, hold on, disposition `rejected`. Creating or editing a definition does not start a run.
- Update is partial. Omitted settings and steps are preserved. An explicit `steps: []` removes all steps. A supplied steps array replaces the entire graph.
- `is_active` and `hold` are JSON booleans. `reject_disposition` is `rejected`, `draft`, or `delete`. Configuring global `delete` requires `frm_delete_entries`. Step-level role grants and destructive dispositions go through the builder's existing permission restrictions too.
- `hold_actions` is a list of numeric action IDs, intersected with the chosen form's real actions. Hold hides the entry and suppresses actions until the workflow finishes. With hold off, only the explicitly held actions wait.
- A workflow with blocking problems is saved **inactive**, even if `is_active: true` was requested. Inspect both `activation_refused` and `problems`, fix the configuration, then activate again. Do not describe a successful write as successful activation without reading these values.
- Save uses the builder's step sanitization and activation checks. Selected action-backed steps bind their actions to the step-only `frmwf_step` event, so these actions do not also fire at form submission.

## Step payloads: builder rows, not stored graphs

**Write `steps` using the builder-row shape.** `get-workflow` returns the persisted graph under `steps` and the writable representation under **`builder_steps`**. For a round trip, pass `builder_steps` as the next write's `steps`. Do not submit stored `next` or `position` objects.

Each row needs a stable, unique `id` and registered `type`. Use simple IDs such as `manager_review`, not the reserved routing words. Optional row properties:

- `label`, `description`, `color`.
- `config`, using the keys and types from discovery.
- `routing_default`: `continue`, `end`, `approve_finish`, `reject_finish`, or a step ID.
- `routing`: map of offered outcome slug to one of those route choices.
- `run_conditions`: comparison rows `{field_id, operator, value}`. `run_conditions_logic`: `and` or `or`. These gate whether the step runs. A conditional branch's own conditions belong in `config.conditions` instead.
- `pos_x`, `pos_y`: integer canvas coordinates.

Invalid or duplicate IDs, dangling routes, unknown config keys, and routes for outcomes the step does not offer return errors before writing. Preserve step IDs during updates so existing run pointers remain meaningful. `continue` follows list order and is stored as an explicit route after sanitization.

### Config value formats

The schema's field `type` determines the builder input format:

| Type | Input |
|---|---|
| `text`, `textarea`, `number`, `select` | Scalar builder value. Strings are convenient for numbers and `"0"`/`"1"` select values. Select option **keys** are values |
| `conditions` | `[{"field_id":"123","operator":">=","value":"1000"}]` |
| `assignees` | `[{"type":"role","id":"administrator"}]`. Types: `user`, `role`, `email`, `field` |
| `response_map` | `[{"path":"result.id","field_id":"123"}]` |
| `fields` | List of numeric editable field IDs |
| `outcome_set` | Approval decision slug list, for example `["approve","reject","revise"]` |
| `keyval` | **String**, one `key = value` per line, for example `"123 = Approved\n124 = Ready"` |
| `outcomes` | Choice button map as a **string**, for example `"legal = Legal review\nfinance = Finance review"` |

Use numeric IDs for fields and actions in settings. Role assignment is resolved at runtime. Choosing an `administrator` role assignee assigns its existing users; it does not create or promote anyone. Approval and User Input steps notify their assignees by email even without a separate Send Email step. External Approval assignees receive secure review links. User Input requires a logged-in WordPress user and does not support external email assignees.

## Example: manager approval with revision loop

Create the form and its fields through the existing form abilities first. Substitute its numeric ID for `123` and the numeric ID of an editable notes field for `456`. This definition uses a role assignee and a revision loop.

```bash
scripts/frm-mcp formidable-forms/create-workflow '{
  "name": "Purchase request review",
  "form_id": 123,
  "hold": true,
  "steps": [
    {
      "id": "manager_review",
      "type": "approval",
      "label": "Manager review",
      "config": {
        "assignees": [{"type": "role", "id": "administrator"}],
        "rule": "any",
        "outcomes": ["approve", "reject", "revise"]
      },
      "routing_default": "approve_finish",
      "routing": {
        "reject": "reject_finish",
        "revise": "collect_details"
      },
      "pos_x": 400,
      "pos_y": 100
    },
    {
      "id": "collect_details",
      "type": "user_input",
      "label": "Collect missing details",
      "config": {
        "assignees": [{"type": "role", "id": "administrator"}],
        "editable_fields": [456],
        "note_mode": "optional"
      },
      "routing_default": "manager_review",
      "pos_x": 700,
      "pos_y": 350
    }
  ]
}'
```

Read the saved workflow, inspect its problems, and activate using `update-workflow` with `{"id": WORKFLOW_ID, "is_active": true}`. Verify the saved active flag. Submit fictional entries through `create-entry` to exercise the form's trigger, then use `list-workflow-runs` to confirm the expected paused or completed status. Follow the browser skill for actual canvas and task UI verification, when that connection is available.

A run with status `complete` can have ended in approval or rejection. Check the entry's workflow status and status-field values when verifying the disposition. To seed sample entries without starting approval emails, create them while the workflow is inactive, then activate it for subsequent submissions.

For Send Email, Send API, or Send SMS steps, create the corresponding form action first and set the step's `config.action_id`. Use discovery to identify its exact step type and available settings. Read `actions.md` before configuring notifications or webhooks.
