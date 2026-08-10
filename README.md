# Formidable Forms MCP Skill

An [Agent Skill](https://code.claude.com/docs/en/skills) that teaches Claude how to build and manage
[Formidable Forms](https://formidableforms.com) sites through the Formidable MCP adapter — forms, fields,
repeaters, entries, views, styles, form actions, applications, PDFs, and templates.

The skill is documentation, not code: it encodes the working payloads, the field-option shapes, the
ordering rules, and the known adapter bugs that are otherwise discovered the hard way. Claude reads the
relevant reference file before making MCP calls, so it gets the call right the first time.

## Requirements

- WordPress with **Formidable Forms** and the Formidable MCP adapter available
- An MCP connection to that site — either the WP-CLI stdio bridge (server shell access) or the HTTP
  endpoint with an application password. Setup for both is in
  [`skills/formidable-mcp/references/mcp-protocol.md`](skills/formidable-mcp/references/mcp-protocol.md).
- Some features referenced (repeaters, views, applications, PDFs) require Formidable Pro or add-ons;
  each reference notes where.

## Install

### As a Claude Code plugin (recommended)

```
/plugin marketplace add Strategy11/formidable-mcp-skill
/plugin install formidable-mcp@formidable
```

Update later with `/plugin marketplace update formidable`.

### Manual install

Copy the skill directory into your project or personal skills folder:

```bash
git clone https://github.com/Strategy11/formidable-mcp-skill.git
cp -r formidable-mcp-skill/skills/formidable-mcp ~/.claude/skills/
```

Use `.claude/skills/` inside a project instead of `~/.claude/skills/` to scope it to that project.

## Usage

Once installed, ask for Formidable work in plain language and Claude loads the skill on its own:

> Build me a multi-step job application form with a repeatable "previous employers" section, then create a
> view that lists submissions by date.

You can also invoke it explicitly with `/formidable-mcp`.

## What's inside

```
skills/formidable-mcp/
├── SKILL.md                  # Overview + routing table: which reference to read for which task
├── references/
│   ├── forms-and-fields.md   # Forms, all field types, options, settings
│   ├── repeaters.md          # Repeatable sections and nested forms (most error-prone area)
│   ├── entries-and-views.md  # Submissions, views, filters, field statistics
│   ├── shortcodes.md         # Shortcodes for emails, views, form HTML, conditionals, graphs
│   ├── styles.md             # Styles, themes, appearance
│   ├── actions.md            # Email, confirmation, webhook, post creation, gated content
│   ├── applications.md       # Applications (Pro)
│   ├── pdfs.md               # PDF downloads and email attachments
│   ├── templates.md          # Form template XML import/export
│   ├── mcp-protocol.md       # Transports, auth, session protocol, abilities catalog, errors
│   └── gotchas.md            # Known adapter bugs and their workarounds
└── scripts/
    └── frm-mcp               # Helper: calls an ability over HTTP, handles sessions and retries
```

`tests/smoke-test.sh` verifies that a site's adapter supports everything the skill documents. It creates
scratch objects, asserts against them, and deletes them again — **point it at a development site, not
production**:

```bash
FRM_MCP_URL="https://your-site.example/wp-json/mcp/formidable-mcp" \
FRM_MCP_AUTH="username:application password" \
./tests/smoke-test.sh
```

## Configuration

The `frm-mcp` helper reads `SITE_URL`, `WP_USERNAME`, and `APPLICATION_PASSWORD` from the environment, or
from a `frm-mcp.env` file next to the script. That file is gitignored — keep credentials out of version
control, and use a WordPress [application password](https://wordpress.org/documentation/article/application-passwords/)
rather than an account password.

## Contributing

Corrections are welcome, especially adapter behavior that contradicts what a reference file claims. The
references are written from verified behavior, so please note how you confirmed a change.

## License

MIT — see [LICENSE](LICENSE).
