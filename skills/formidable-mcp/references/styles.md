# Styles

Read this when: creating, updating, querying, assigning, or deleting Formidable form styles (appearance themes), or fixing style-related CSS issues.

## Overview

Styles control the appearance and layout of Formidable forms. Each style is a WordPress post of type `frm_styles` whose `post_content` holds a JSON object of style properties. Styles are assigned to forms via the form's `custom_style` option.

## MCP Abilities

| Ability | Purpose | Key parameters |
|---------|---------|----------------|
| `formidable-forms/list-styles` | List all styles | (none) |
| `formidable-forms/get-style` | Get one style's full properties | `id` |
| `formidable-forms/create-style` | Create a new style | `name`, `post_content` (object of properties) |
| `formidable-forms/update-style` | Update style properties | `id`, `post_content` (object of properties) |
| `formidable-forms/delete-style` | Delete a style | `id` |
| `formidable-forms/assign-style-to-form` | Apply a style to a form | `form_id`, `style_id` |

All style properties (colors, fonts, spacing) persist via `create-style` and `update-style`.

### Important: post_type Requirement

Styles must have `post_type='frm_styles'` for MCP updates to work. Styles created via MCP get this automatically; a style created by other means with `post_type='post'` breaks MCP updates. Correct such a style with:

```bash
wp post update {ID} --post_type=frm_styles
```

## Property Format Requirements

- Wrap all style properties in `"post_content": {...}` for create/update.
- All property values are strings.
- Hex colors WITHOUT the `#` prefix (e.g., `"FF0000"`, not `"#FF0000"`).
- Sizes/spacing include units (e.g., `"12px"`, `"8px 12px"`, `"100%"`).

## Creating Styles

Via MCP over the WP-CLI stdio bridge:

```bash
cat > /tmp/create_style.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-style","parameters":{"name":"My New Style","post_content":{"title_color":"D32F2F","bg_color":"F5DEB3","text_color":"2C2C2C"}}}}}
JSON

cat /tmp/create_style.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data | {id, name}'
```

MCP sets all style properties during creation and persists them; `post_type` is automatically set to `frm_styles`.

## Querying Styles

Via HTTP MCP transport (with an established session):

```bash
# List all styles
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/list-styles",
        "parameters": {}
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent.data[] | {id, name}'

# Get a specific style
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/get-style",
        "parameters": {
          "id": "15"
        }
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent.data'
```

## Assigning Styles to Forms

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/assign-style-to-form",
        "parameters": {
          "form_id": "1429",
          "style_id": "15"
        }
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent'
```

Assignment sets `custom_style` in the form's options (verify with a form-options query: expect e.g. `custom_style: "15"`).

## Updating Styles

Use MCP; all colors, fonts, and spacing persist correctly:

```bash
cat > /tmp/update_style.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/update-style","parameters":{"id":"10400","post_content":{"text_color":"000000","submit_bg_color":"FF0000","border_color":"CCCCCC"}}}}}
JSON

cat /tmp/update_style.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.result.structuredContent.data.post_content'
```

**Requirements:**
- All properties wrapped in `"post_content": {...}`
- Color values: hex without `#` (e.g., "FF0000")
- Style must have `post_type='frm_styles'` (see post_type Requirement above)

## Deleting Styles

```bash
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "mcp-adapter-execute-ability",
      "arguments": {
        "ability_name": "formidable-forms/delete-style",
        "parameters": {
          "id": "15"
        }
      }
    },
    "id": 2
  }' 2>&1 | jq '.result.structuredContent'
```

## Common Workflow: Create a Style and Apply It to a Form

```bash
# 1. Create the style, capture the new ID
STYLE_ID=$(curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/create-style","parameters":{"name":"My New Style"}}},"id":2}' \
  2>&1 | jq -r '.result.structuredContent.data.id')

# 2. Assign to form
curl -s -X POST "https://your-site.local/wp-json/mcp/formidable-mcp" \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: $SESSION" \
  -u "admin:APP_PASSWORD" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"tools/call\",
    \"params\": {
      \"name\": \"mcp-adapter-execute-ability\",
      \"arguments\": {
        \"ability_name\": \"formidable-forms/assign-style-to-form\",
        \"parameters\": {
          \"form_id\": \"1429\",
          \"style_id\": \"$STYLE_ID\"
        }
      }
    },
    \"id\": 2
  }" 2>&1 | jq '.result.structuredContent'
```

## Complete Style Properties Reference

Based on Formidable Lite's style system, all customizable properties:

### Layout & Structure
- `center_form` — Center the form on page (true/false)
- `form_width` — Form container width (e.g., "100%")
- `form_align` — Form alignment ("left", "center", "right")
- `direction` — Text direction ("ltr" or "rtl")
- `field_shape_type` — Field shape ("rounded-corner", "square", etc.)
- `field_width` — Field width (e.g., "100%")

### Typography
- `font` — Font family (e.g., "Georgia, serif")
- `font_size` — Base font size (e.g., "15px")
- `weight` — Font weight ("normal", "bold", "500", etc.)
- `title_size` — Form title size
- `form_desc_size` — Form description size
- `label_font_size` — Label text size
- `field_font_size` — Input field font size
- `section_font_size` — Section header size
- `description_font_size` — Field description size

### Colors - Text & Labels
- `title_color` — Form title color (hex, e.g., "8B5A8B")
- `form_desc_color` — Form description color
- `label_color` — Label text color
- `text_color` — Input field text color
- `description_color` — Field description text color
- `required_color` — Required field indicator color
- `check_label_color` — Checkbox/radio label color
- `section_color` — Section header text color

### Colors - Backgrounds & Borders
- `bg_color` — Input field background ("ffffff", "FDF8FC", etc.)
- `border_color` — Input field border color
- `field_border_width` — Border thickness (e.g., "1px")
- `field_border_style` — Border style ("solid", "dashed", etc.)
- `border_radius` — Border radius for rounded corners (e.g., "12px")
- `fieldset_color` — Fieldset border color
- `fieldset_bg_color` — Fieldset background color

### Colors - Interactive States
- `bg_color_active` — Background when field is focused/active
- `border_color_active` — Border color when active
- `submit_hover_bg_color` — Submit button hover background
- `submit_hover_color` — Submit button hover text color
- `submit_active_bg_color` — Submit button active/clicked background
- `submit_active_color` — Submit button active text color

### Colors - Error & Disabled
- `bg_color_error` — Error state background
- `border_color_error` — Error state border
- `text_color_error` — Error state text
- `border_width_error` — Error border thickness
- `bg_color_disabled` — Disabled field background
- `border_color_disabled` — Disabled field border
- `text_color_disabled` — Disabled field text

### Colors - Messages
- `error_bg` — Error message background
- `error_border` — Error message border
- `error_text` — Error message text color
- `success_bg_color` — Success message background
- `success_border_color` — Success message border
- `success_text_color` — Success message text color

### Submit Button Styling
- `submit_style` — Enable custom styling (true/false)
- `submit_font_size` — Button text size
- `submit_width` — Button width ("auto", "100%", etc.)
- `submit_height` — Button height (e.g., "48px")
- `submit_bg_color` — Button background color
- `submit_border_color` — Button border color
- `submit_border_width` — Button border width
- `submit_text_color` — Button text color
- `submit_weight` — Button text weight
- `submit_border_radius` — Button corner radius
- `submit_padding` — Button padding (e.g., "8px 16px")
- `submit_margin` — Button margin

### Spacing & Padding
- `field_pad` — Input field padding (e.g., "8px 12px")
- `field_margin` — Space around fields (e.g., "20px")
- `field_height` — Input field height
- `label_padding` — Label padding
- `fieldset_padding` — Fieldset padding
- `title_margin_top` — Title top margin
- `title_margin_bottom` — Title bottom margin
- `form_desc_margin_top` — Description top margin
- `form_desc_margin_bottom` — Description bottom margin
- `section_pad` — Section padding
- `section_mar_top` — Section top margin
- `section_mar_bottom` — Section bottom margin

### Sections & Fieldsets
- `section_border_color` — Section border color
- `section_border_width` — Section border width
- `section_border_style` — Section border style
- `section_border_loc` — Section border location ("-top", "-bottom", etc.)
- `section_bg_color` — Section background color

### Advanced Options
- `remove_box_shadow` — Remove field box shadow (true/false)
- `auto_width` — Auto field width (true/false)
- `line_height` — Line height (e.g., "normal", "40px")
- `position` — Label position ("none", "above", "inside", etc.)
- `align` — Label alignment ("left", "right", "center")
- `width` — Label width (e.g., "150px")
- `custom_css` — Custom CSS code
- `enable_style_custom_css` — Enable custom CSS (true/false)
- `single_style_custom_css` — Additional custom CSS

### Progress Indicators
- `progress_bg_color` — Progress bar background
- `progress_color` — Progress bar text color
- `progress_active_bg_color` — Active step background
- `progress_active_color` — Active step text color
- `progress_border_color` — Progress bar border
- `progress_border_size` — Progress border thickness
- `progress_size` — Progress bar size

## Complete Working Examples

### Example: Dark Bold Theme (dark background, gold/orange-red accents)

Successfully tested via MCP — all colors persist:

```bash
cat > /tmp/dark_theme.jsonl << 'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"claude","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-adapter-execute-ability","arguments":{"ability_name":"formidable-forms/update-style","parameters":{"id":"10400","post_content":{"bg_color":"1a1a1a","text_color":"FFD700","title_color":"FFD700","form_desc_color":"FFC107","label_color":"FFD700","border_color":"FF6B35","fieldset_bg_color":"2d2d2d","section_color":"FFC107","submit_bg_color":"FF6B35","submit_text_color":"1a1a1a","submit_hover_bg_color":"FFD700"}}}}}
JSON

cat /tmp/dark_theme.jsonl | wp --path="/path/to/site" mcp-adapter serve --server=formidable-mcp --user=1 2>/dev/null | tail -1 | jq '.'
```

**Colors used:** dark blacks `1a1a1a` / `2d2d2d`, bold gold `FFD700`, bright amber `FFC107`, orange-red `FF6B35`.

### Example: Soft Pastel Theme

```json
{
  "name": "Flowery Garden",
  "post_content": {
    "fieldset_bg_color": "F5E6F0",
    "fieldset_color": "D4A5C7",
    "text_color": "6B5563",
    "section_color": "9B7BA9",
    "section_bg_color": "FDF8FC",
    "form_desc_color": "A98FA5",
    "description_color": "9B7BA9",
    "title_color": "B85A92",
    "label_color": "9B7BA9",
    "bg_color": "FDF8FC",
    "border_color": "D5B5D0",
    "field_border_color": "D5B5D0",
    "submit_bg_color": "D67B9F",
    "submit_text_color": "ffffff",
    "submit_hover_bg_color": "C45A7F",
    "border_radius": "12px",
    "success_bg_color": "E8F0E8",
    "success_text_color": "6A8A6A"
  }
}
```

### Example: Primary-Colors Game Theme (red, yellow, green, blue)

```json
{
  "name": "Super Mario",
  "post_content": {
    "fieldset_bg_color": "87CEEB",
    "fieldset_color": "FF0000",
    "text_color": "000000",
    "section_color": "FF0000",
    "section_bg_color": "FFFF00",
    "form_desc_color": "008000",
    "description_color": "008000",
    "title_color": "FF0000",
    "label_color": "000000",
    "bg_color": "87CEEB",
    "border_color": "FFD700",
    "field_border_width": "3px",
    "submit_bg_color": "FF0000",
    "submit_text_color": "FFFF00",
    "submit_border_color": "000000",
    "submit_border_width": "3px",
    "submit_hover_bg_color": "CC0000",
    "border_radius": "8px",
    "error_bg": "FF6B6B",
    "error_border": "FF0000",
    "success_bg_color": "90EE90",
    "success_border_color": "008000"
  }
}
```

### Worked Example: Neon Arcade Theme (create + assign, end to end)

A complete custom-theme build (a dark neon "Arcade Retro" style, created as style ID 10633 and assigned to a form via `assign-style-to-form`). Use this as a template for any themed style.

Color palette:

| Element | Property | Color | Hex |
|---------|----------|-------|-----|
| Background | `bg_color` | Black | `000000` |
| Text | `text_color` | Cyan | `00F5FF` |
| Title | `title_color` | Magenta | `FF006E` |
| Description | `form_desc_color` | Yellow | `FFFF00` |
| Labels | `label_color` | Cyan | `00F5FF` |
| Borders | `border_color` | Cyan | `00F5FF` |
| Submit button | `submit_bg_color` | Magenta | `FF006E` |
| Button hover | `submit_hover_bg_color` | Cyan | `00F5FF` |
| Section headers | `section_color` | Yellow | `FFFF00` |
| Success messages | `success_bg_color` | Green | `00FF00` |
| Error messages | `error_bg` | Red | `FF0000` |
| Fieldset background | `fieldset_bg_color` | Dark gray | `1a1a1a` |

Design elements:
- `border_radius`: "8px" (slight rounding for retro feel)
- `field_border_width`: "2px" (bold borders)
- `submit_border_width`: "3px" (prominent button)
- `weight`: bold for headers
- Fieldset background dark gray (`1a1a1a`) for contrast against the black form background

Steps:
1. Create the style with `formidable-forms/create-style` (name + `post_content` with the palette above).
2. Assign to the target form with `formidable-forms/assign-style-to-form` (`form_id`, `style_id`).
3. Verify: fetch the form's options and confirm `custom_style` equals the new style ID (e.g., `custom_style: "10633"`).

## Tips for Creating Color Schemes

- **Hex colors:** Use without `#` prefix (e.g., "FF0000" not "#FF0000")
- **Use MCP:** MCP works fully for create and update operations with color persistence
- **Include post_content:** Wrap all properties in `"post_content": {...}`
- **post_type:** A style with `post_type='post'` needs `wp post update {ID} --post_type=frm_styles` before MCP updates work
- **Consistency:** Update related colors together (hover, active, borders)
- **Contrast:** Ensure text colors have enough contrast with backgrounds
- **Test:** Create the style and view a test form to verify appearance

## Database Structure

### Styles (WordPress Posts)
- **Table:** `wp_posts`
- **post_type:** `'frm_styles'` (CRITICAL — must be set, not 'post')
- **post_status:** `'publish'`
- **post_content:** JSON serialized object containing all style properties

### Key Fields in Style post_content JSON
- Color properties: `title_color`, `label_color`, `text_color`, `border_color`, `bg_color`, `submit_bg_color`, `submit_text_color`, `submit_hover_bg_color`, etc.
- Layout: `form_width`, `field_height`, `field_pad`, `border_radius`, `label_position`
- Typography: `font_size`, `title_size`, `label_font_size`, `section_font_size`
- Advanced: `custom_css`, `field_shape_type`, `theme_css`, `use_base_font_size`

## Scale Field Label Alignment CSS

How scale fields with before/after input labels (e.g., "10 - Very Happy") align, in Formidable Pro's `css/pro_fields.css.php`:

- `.frm_scale_container .frm_opt_container` is `display: flex; flex-direction: column; width: fit-content;` — the container only takes the width needed for the scale options
- `.frm_scale_labels` is `width: 100%` — the labels row fills that flex container, so options and labels share the same width

Because the labels row matches the width of the scale options (not the full field width), the "after" label with `margin-left: auto` sits at the right edge of the scale options, aligned correctly with or without inline field labels.
