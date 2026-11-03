# Advanced Conditional Logic (Formidable Advanced Conditional Logic add-on)

Read this when: a form needs conditional logic beyond a plain show/hide with any/all, such as condition groups, "at least N", Site & User conditions, date or selection-count measures, regex, Require / Read-only / Set value / validation effects, choice rules, Continue to branches or Next-button rules. Also read it when checking or explaining why a rule does or doesn't match. Source: `formidable-advanced-logic` plugin code, its PHPUnit suite, and a full MCP round trip on a live site (write, read back, validate, explain, raw storage check).

Requires the Formidable Advanced Conditional Logic add-on, with MCP enabled and an active license. If these abilities are missing, check that the add-on is installed and up to date.

## Use these abilities, not raw `field_options`

`update-field` and `create-field` save `field_options` exactly as sent. The add-on's logic settings need the clean-up the form builder runs on save: renumbering groups, saving a single group without group data, computing comparison kinds, saving weekday names as numbers, converting calculation field keys to IDs, and keeping additional rules in their saved shape. The core field abilities skip all of it (see the active bug in `gotchas.md`). Writing `hide_group`, `hide_compare_*` or `adv_logic_rules` through `update-field` can store logic that renders, evaluates or validates differently from the same logic saved in the builder.

| Ability | What it does | Notes |
|---|---|---|
| `get-field-logic` | A field's main logic and additional rules in the readable shape below, plus `main_effects` and `rule_effects` (what this field can use) | readonly, idempotent |
| `update-field-logic` | Replace the main `logic`, the `rules`, or both, with the builder's clean-up. Returns the saved logic plus `issues` (rule-check results for that field) | idempotent. **All or nothing**: a rejected part saves nothing and the error names it (`logic.conditions[1]`, `rules[2]`) |
| `validate-form-logic` | Rule checks for a whole form (`form_id` by ID or key), optionally limited to one `field_id` | readonly. Returns `errors`, `warnings`, `issues` |
| `explain-field-logic` | Evaluate the main logic (`rule: "logic"`, the default) or an additional rule (`rule: 0, 1, …`) against sample `values` | readonly. Nothing is submitted |

All four take a field by ID or key. Plain show/hide logic with one any/all group still works through `update-field` (see `forms-and-fields.md` § "Conditional Logic"). Use these abilities as soon as anything on this page is involved.

What core already handles, so there's no add-on ability for it:

- **Form action conditions.** `create-form-action` / `update-form-action` go through the action save path, which runs the add-on's normalizer. Groups use a `group` number inside each condition, with `any_all`, `group_any_all` and `groups_any_all` beside `send_stop`.
- **Routing rules and per-form group presets.** `update-form` merges `options` and runs the form-options filter the add-on hooks, so `options.adv_logic_routes` and `options.adv_logic_group_presets` are normalized on save. Site-wide presets (a WordPress option) have no ability.

## The readable shape

The main logic and each additional rule use the same shape:

```json
{
  "effect": "require",
  "match": "at_least_2",
  "group_matches": { "1": "all" },
  "groups_match": "any",
  "conditions": [
    { "field": "24332", "operator": "==", "value": "Pro" },
    { "field": "24334", "operator": ">=", "value": "2", "measure": "count" },
    { "field": "24333", "operator": ">=", "value": "18", "measure": "age" },
    { "field": "context-logged_in", "operator": "==", "value": "yes", "group": 1 }
  ]
}
```

This reads: require the field when (at least 2 of: plan is Pro, 2 or more extras checked, age 18 or over) **or** the visitor is logged in.

- `match`: how conditions combine **inside the first group** (group 0): `any`, `all` or `at_least_N` (1–999).
- `group_matches`: the same for each later group, keyed by group number.
- `groups_match`: how the groups combine, `any` or `all`. It is never "at least".
- `conditions[].group`: group number, starting at 0. Leave it out for one group. One group is saved without group data, the shape other add-ons read.

### Condition settings

| Key | Meaning |
|---|---|
| `field` | **Numeric field ID** (a key is rejected), a Name/Address subfield like `"25_first"`, or a Site & User source (below) |
| `operator` | `==` `!=` `>` `>=` `<` `<=` `LIKE` (contains) `not LIKE` `LIKE%` (starts with) `%LIKE` (ends with), plus `empty` `not_empty` `between` `not_between` `in` `not_in` `regex` `not_regex` |
| `value` | Comparison value. `in` / `not_in`: one value per line (`"A\nB"`). `regex`: case-sensitive pattern without slashes |
| `value2` | Upper bound for `between` / `not_between` (inclusive) |
| `compare_field` | Compare with another field's answer instead of `value`. Not for Site & User sources or regex |
| `context_key` | The name some sources need: user meta key, URL parameter, capability, shortcode |
| `measure` | `weekday` (1 = Monday … 7 = Sunday), `age` (whole years) or `days` (from today, negative = past) for **date** fields. `count` (number selected) for **checkbox / multi-select** |
| `ignore_case` | `true` makes `regex` / `not_regex` case-insensitive |

An invalid regex never matches, for `regex` and for `not_regex`, so a broken "does not match" can't let every answer through. `validate-form-logic` reports it as `invalid_regex`.

"Within the last 7 days" is `measure: "days"`, `between`, `value: "-7"`, `value2: "0"`. Weekday values can be names (`"Monday\nSunday"`) and are saved as numbers.

### Site & User sources

Use as `field: "context-<source>"`. PHP decides these before the form is shown, using the **current** user and request.

`logged_in`, `user_role`, `user_id`, `user_login`, `user_email`, `user_meta` (+`context_key`), `ip`, `display_name`, `user_capability` (+`context_key`), `shortcode` (+`context_key`), `date`, `weekday`, `month`, `time`, `post_id`, `url_param` (+`context_key`), `editing`, `always`, `never`.

Yes/no sources (`logged_in`, `user_capability`, `editing`) store `1` / `0`. The ability converts `yes` / `no` / `true` / `false` for you, and `get-field-logic` returns `"1"`. Use `context-always` as a "no real condition" for rules that should always apply, such as an exclusive choice.

### Effects

**Main logic (`logic.effect`)**: `show`, `hide`, and where the field type supports them `require`, `readonly`, `set_value`, `validation`. A **submit button** takes `show` / `hide` / `enable` / `disable`. A **page break**'s `show` / `hide` mean "do not skip" / "skip" the next page. Check `main_effects` from `get-field-logic`, since it lists only what the field accepts.

**Additional rules (`rules[].effect`)**: check `rule_effects`. Each needs its own settings:

| Effect | Extra settings | Field types |
|---|---|---|
| `require`, `readonly` | none | text-like (`readonly` excludes choice fields) |
| `set_value` | `value_mode` `literal` + `set_value`, or `field` + `value_field` (field ID), or `calc` + `calc` | text-like, hidden, dropdown, radio |
| `validation` | `message` (required). A condition on the field itself checks its current value | text-like, date, choice fields |
| `show_choice`, `hide_choice`, `disable_choice` | `choice` (the saved choice value) | dropdown, radio, checkbox |
| `exclusive_choice` | `choice`. Checking it clears and disables the other choices | checkbox |
| `jump` (Continue to) | `destination`: a **later** question or page break ID. Conditions may only use earlier fields | ordinary top-level questions |
| `button_label`, `previous_label` | `label` | submit, page break |
| `show_next`, `hide_next`, `disable_next` | none | page break (that page's Next button) |

The first matching rule of a kind wins (labels, Continue to, Set value), in array order. To change priority, reorder the array. `rules` **replaces** every current rule, so send the full list. `[]` removes them all. Leave `rules` out to keep them.

`calc` accepts field IDs or keys in brackets and `+ - * / %` (`"[price] * 1.08"`). Keys are saved as IDs. Pro's calculation functions and text or date calculations are not supported.

Additional rules can name groups: `group_names: {"0": "Kids"}`. Main logic group names come from the builder only.

## Worked calls

Require a field from grouped logic, plus a case-insensitive validation rule on the field itself:

```json
{
  "id": 24335,
  "logic": {
    "effect": "require",
    "match": "at_least_2",
    "groups_match": "any",
    "group_matches": { "1": "all" },
    "conditions": [
      { "field": "24332", "operator": "==", "value": "Pro" },
      { "field": "24334", "operator": ">=", "value": "2", "measure": "count" },
      { "field": "24333", "operator": ">=", "value": "18", "measure": "age" },
      { "field": "context-logged_in", "operator": "==", "value": "yes", "group": 1 }
    ]
  },
  "rules": [
    {
      "effect": "validation",
      "message": "Use a company name, not a test value.",
      "conditions": [ { "field": "24335", "operator": "regex", "value": "^test", "ignore_case": true } ]
    }
  ]
}
```

"None of the above" on a checkbox:

```json
{
  "id": "extras",
  "rules": [
    {
      "effect": "exclusive_choice",
      "choice": "None",
      "conditions": [ { "field": "context-always", "operator": "==", "value": "" } ]
    }
  ]
}
```

Remove the main logic and keep the rules: `{"id": 24335, "logic": null}`. Remove everything: `{"id": 24335, "logic": null, "rules": []}`. That also turns `enable_conditional_logic` off.

Submit button logic is stored in two places: Pro's base keys in the form's `options.submit_conditions`, the add-on's extras on the submit field. `update-field-logic` writes both and leaves the form's status alone. Forms created through MCP have no submit field (see SKILL.md rule 5), so this only applies to forms that have one.

## Checking and explaining

`validate-form-logic` changes nothing. Each issue has `code`, `severity` (`error` = can't work as written, `warning` = likely mistake), `message`, `target` (`field` / `action` / `route`), `field_id` / `action_id` / `route`, `rule` (`"logic"` or the rule position), and `condition` / `group` when it is about one.

Codes: `missing_source`, `invalid_regex`, `invalid_range`, `contradictory_conditions`, `at_least_too_high`, `unreachable_group`, `unreachable_rule`, `missing_choice`, `missing_destination`, `backward_destination`, `blocked_destination`, `invalid_route_destination`, `set_value_cycle`, `logic_cycle`. A `logic_cycle` (field A's logic reads B and B's reads A) is a warning, not a save blocker.

`explain-field-logic`:

```json
{ "id": 24335, "values": { "24332": "Pro", "24334": ["Support", "Training"], "24333": "2015-06-01" }, "today": "2026-10-30" }
```

- `values`: sample answers keyed by field ID or key. Arrays are used for checkboxes. A missing answer counts as empty and is listed in `missing`.
- `today` pins age and days measures. It defaults to the site's date.
- The result has `outcome` (the effect applies), `conditions[]` (each with `source` = `field` / `site_user`, `answer`, `met`), and `groups[]` (`match`, `met_count`, `met`).
- `short_circuit`: `decided_in_php` lists the Site & User conditions, and `decided` is `true` / `false` when they settle the rule on their own. `not_needed` lists the field conditions that then don't matter and are never sent to the browser.

Site & User conditions use **the MCP caller** (usually an administrator), not a site visitor. For a visitor's view, reason from the condition rather than from the outcome.

The PHP evaluator here matches the browser through a shared parity suite. Main logic on a live submission is decided by Pro plus the add-on, and native comparisons such as checkbox arrays go through Pro. Treat `explain` as the add-on's reading of the rule, then confirm in a browser when it matters.

## Verify

- Read back with `get-field-logic`, not `list-fields`. The raw arrays are hard to compare by eye.
- Run `validate-form-logic` after a batch of changes, since `update-field-logic` only returns issues for the field it changed. Cycles and missing sources show up across fields.
- For rendering (required marker, read-only state, hidden choices, Next button), check the form in a browser. These are browser behaviors the abilities can't show.
