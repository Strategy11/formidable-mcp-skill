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

## Quickstart: connect a site

Three commands and one edit. Full walkthrough — including the no-password option for local sites — is in
[`skills/formidable-mcp/references/getting-started.md`](skills/formidable-mcp/references/getting-started.md).

```bash
cd skills/formidable-mcp/scripts    # after a plugin install: find ~/.claude -name frm-mcp-setup
cp frm-mcp.env.example frm-mcp.env  # then edit it — see below
./frm-mcp-setup                     # checks everything and says what's left to fix
```

Fill `frm-mcp.env` in with your own editor:

```bash
SITE_URL="https://example.com"
WP_USERNAME="your-wp-username"
APPLICATION_PASSWORD="xxxx xxxx xxxx xxxx xxxx xxxx"
```

The application password comes from WP Admin → **Users → Profile → Application Passwords** on an
administrator account (it is not the login password; spaces in it are fine). `frm-mcp.env` is gitignored, and
`frm-mcp-setup` never prints its values.

**Don't paste credentials into a chat with an AI assistant** — anything in a conversation is in the
transcript and would need rotating afterward. The skill instructs Claude never to ask for them: it points you
at this file and reads the output of `frm-mcp-setup` instead. If you do have shell access to the WordPress
host, the WP-CLI bridge needs no password at all.

`./frm-mcp-setup` verifies local tooling, the config file, TLS, the MCP endpoint, authentication, and the
abilities themselves, printing a specific fix for whatever fails. When it ends in `Connected.`, try a call:

```bash
./frm-mcp formidable-forms/list-forms
```

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
│   ├── getting-started.md    # First-time setup: connecting a site, verifying, onboarding a teammate
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
    ├── frm-mcp               # Helper: calls an ability over HTTP, handles sessions and retries
    ├── frm-mcp-setup         # Connection check: diagnoses setup and says what to fix
    └── frm-mcp.env.example   # Template to copy to frm-mcp.env (gitignored) and fill in
```

`tests/smoke-test.sh` goes further than `frm-mcp-setup`: it verifies that a site's adapter supports
everything the skill documents, creating scratch objects, asserting against them, and deleting them again —
so **point it at a development site, not production**. It reads the same `frm-mcp.env`:

```bash
./tests/smoke-test.sh
```

## Configuration

The `frm-mcp` helper and the smoke test read `SITE_URL`, `WP_USERNAME`, and `APPLICATION_PASSWORD` from a
`frm-mcp.env` file next to the script (copy `frm-mcp.env.example` to start); environment variables of the
same names override it, which is meant for CI rather than for typing a password into a command. The file is
gitignored — keep credentials out of version control, out of chat transcripts, and out of shell history, and
use a WordPress [application password](https://wordpress.org/documentation/article/application-passwords/)
rather than an account password.

Optional keys: `FRM_MCP_CACERT` points at a local CA file for self-signed certificates; `FRM_MCP_INSECURE=1`
skips TLS verification and is refused for anything but local hostnames.

## Contributing

Corrections are welcome, especially adapter behavior that contradicts what a reference file claims. The
references are written from verified behavior, so please note how you confirmed a change.

## License

MIT — see [LICENSE](LICENSE).
