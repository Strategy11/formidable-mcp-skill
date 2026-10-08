# Formidable Forms MCP Skill

An Agent Skill for [Claude Code](https://code.claude.com/docs/en/skills) and [Codex](https://developers.openai.com/codex/skills)
that teaches your coding agent how to build and manage [Formidable Forms](https://formidableforms.com) sites through the Formidable MCP adapter — forms, fields,
repeaters, entries, views, styles, form actions, applications, PDFs, and templates.

The skill is documentation, not code: it encodes the working payloads, the field-option shapes, the
ordering rules, and the known adapter bugs that are otherwise discovered the hard way. The agent reads the
relevant reference file before making MCP calls, so it gets the call right the first time.

## Requirements

- WordPress 7.0+ with **Formidable Forms**, its MCP server turned on (Formidable → Settings → MCP), and PHP 7.4+
- An MCP connection to that site — either the WP-CLI stdio bridge (server shell access, no password) or the
  HTTP endpoint with an application password. Setup for both is in
  [`skills/formidable-mcp/references/getting-started.md`](skills/formidable-mcp/references/getting-started.md),
  and `skills/formidable-mcp/scripts/frm-mcp-setup` checks it for you.
- Some features referenced (repeaters, views, applications, PDFs) require Formidable Pro or add-ons;
  each reference notes where.

## Install

The repository is a plugin marketplace that both Claude Code and Codex can install from.

### Claude Code

```
/plugin marketplace add Strategy11/formidable-mcp-skill
/plugin install formidable-mcp@formidable
```

Update later with `/plugin marketplace update formidable`.

### Codex

```bash
codex plugin marketplace add Strategy11/formidable-mcp-skill
codex plugin add formidable-mcp@formidable
```

Update later with `codex plugin marketplace upgrade formidable`. Start a new Codex session after installing.

### Manual install (either agent)

Clone the repo and link the skill directory into your agent's skills folder:

| Agent | Personal | One project |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` |

```bash
git clone https://github.com/Strategy11/formidable-mcp-skill.git ~/formidable-mcp-skill
mkdir -p ~/.claude/skills
ln -s ~/formidable-mcp-skill/skills/formidable-mcp ~/.claude/skills/formidable-mcp   # and/or ~/.agents/skills/
```

### Other agents and MCP clients

Nothing here depends on a particular agent below the packaging: the references are plain Markdown and the
helpers are POSIX shell scripts needing only `curl` and `jq`. Clone the repo and point your tool at
`skills/formidable-mcp/` — or read it yourself and drive `scripts/frm-mcp` from a terminal. The stdio bridge
config works in any MCP client; per-client config (Claude Code, Claude Desktop, Codex, Cursor, VS Code) is
tabled in [`references/mcp-protocol.md`](skills/formidable-mcp/references/mcp-protocol.md) § "Transport 1".

## Quickstart: connect a site

Two steps in WordPress. In WP Admin → **Formidable → Settings → MCP**:

1. Turn on **Enable the Formidable MCP server** and click **Download frm-mcp.env**. Each download creates a new
   application password that only works on the Formidable MCP endpoint.
2. Pick Claude Code or Codex, click **Copy setup prompt**, and paste it into your agent. It installs the skill,
   moves the downloaded file into place without opening it, and runs `frm-mcp-setup` to check the connection.

The MCP server ships with Formidable and needs WordPress 7.0+ and PHP 7.4+. Full walkthrough — including the
no-password option for local sites and the manual route for older Formidable versions — is in
[`skills/formidable-mcp/references/getting-started.md`](skills/formidable-mcp/references/getting-started.md).

To do step 2 yourself instead:

```bash
mkdir -p ~/.config/formidable-mcp
mv "$(ls -t ~/Downloads/frm-mcp*.env | head -1)" ~/.config/formidable-mcp/frm-mcp.env
chmod 600 ~/.config/formidable-mcp/frm-mcp.env
skills/formidable-mcp/scripts/frm-mcp-setup     # plugin install? the scripts are in the plugin cache, see below
```

`~/.config/formidable-mcp/` is where the helpers look by default, and unlike the skill's own directory it
survives plugin updates. With a plugin install the scripts themselves are in the agent's plugin cache —
`~/.claude/plugins/cache/formidable/formidable-mcp/<version>/skills/formidable-mcp/scripts/` for Claude Code,
`~/.codex/plugins/cache/formidable/formidable-mcp/<version>/skills/formidable-mcp/scripts/` for Codex.

Revoke a file under **Manage connection files** on the same settings screen; each one stays valid until
revoked, including after Formidable is deactivated.

**Don't paste credentials into a chat with an AI assistant** — anything in a conversation is in the
transcript and would need rotating afterward. The skill instructs the agent never to ask for them: it moves
the downloaded file without reading it, and reads the output of `frm-mcp-setup` instead. If you do have shell
access to the WordPress host, the WP-CLI bridge needs no password at all.

`./frm-mcp-setup` verifies local tooling, the config file, TLS, the MCP endpoint, authentication, and the
abilities themselves, printing a specific fix for whatever fails. When it ends in `Connected.`, try a call:

```bash
./frm-mcp formidable-forms/list-forms
```

## Usage

Once installed, ask for Formidable work in plain language and the agent loads the skill on its own:

> Build me a multi-step job application form with a repeatable "previous employers" section, then create a
> view that lists submissions by date.

You can also invoke it explicitly: `/formidable-mcp` in Claude Code, `$formidable-mcp` in Codex.

Running from Codex over HTTP? Its default sandbox blocks network access, so approve running `frm-mcp` outside
the sandbox when asked — details in
[`getting-started.md`](skills/formidable-mcp/references/getting-started.md) § "Running `frm-mcp` from inside Codex".

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
│   ├── coupons.md            # Discount codes: amounts, form assignment, limits, status
│   ├── landing-pages.md      # Form landing pages: the 1:1 upsert, slugs, content, design
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
`frm-mcp.env` file — `$FRM_MCP_ENV` if set, else one next to the script, else
`~/.config/formidable-mcp/frm-mcp.env`. Download it from Formidable's MCP settings, or copy
`frm-mcp.env.example` and fill it in on older versions. Environment variables of the same names override it,
which is meant for CI rather than for typing a password into a command. Beside the scripts the file is
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
