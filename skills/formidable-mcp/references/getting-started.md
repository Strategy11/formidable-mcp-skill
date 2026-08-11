# Getting Started: First-Time Setup

Read this when: the site has never been connected from this machine, someone asks "how do I get started / what do I run?", or the very first MCP call fails on authentication. Everything else in this skill assumes a working connection — this file creates one.

**Rule that outranks everything below: never ask for credentials.** Not in chat, not as a command to run, not "paste it and I'll put it in the file for you". The application password goes from the WordPress admin screen straight into a local `frm-mcp.env` that the user edits themselves. An assistant's job here is to say which command to run and to read the output — see § "Onboarding someone else" for wording that works.

## Which path applies

| Situation | Path | Needs a password? |
|---|---|---|
| Remote site, staging, production, or any site you don't have a shell on | **HTTP + `frm-mcp` helper** — the main path below | Yes — an application password, stored in `frm-mcp.env` |
| Local dev site you have a terminal on (Local by Flywheel, Valet, DDEV, wp-env) | **WP-CLI stdio bridge** — see § "Local sites" | No |

When both apply, prefer the WP-CLI bridge: no credential exists to leak.

## The five-minute setup (HTTP path)

### 1. Install the skill

In Claude Code, as a plugin:

```
/plugin marketplace add Strategy11/formidable-mcp-skill
/plugin install formidable-mcp@formidable
```

Anywhere else — a personal or project skills directory, or another agent entirely — clone it and put the skill directory where your tool looks for skills or instructions:

```bash
git clone https://github.com/Strategy11/formidable-mcp-skill.git
cp -r formidable-mcp-skill/skills/formidable-mcp ~/.claude/skills/    # or your agent's equivalent
```

Nothing here is tied to a particular assistant: the references are plain Markdown and the helpers are POSIX shell scripts that only need `curl` and `jq`. An agent that can read files and run commands can use this; a person with a terminal can too.

However it got installed, the helper scripts live in the skill's `scripts/` directory. If you're not sure where that ended up:

```bash
find ~ -name frm-mcp-setup -not -path '*/.git/*' 2>/dev/null
```

The rest of this file writes that directory as `scripts/` — `cd` into it first.

### 2. Confirm the site side is ready

On the WordPress site: **Formidable Forms** active, plus the **Formidable Forms API** add-on (it ships the MCP adapter), and permalinks set to anything other than "Plain". Step 4 below tells you if either is missing, so this is a glance, not a project.

### 3. Create an application password and put it in `frm-mcp.env`

In WP Admin, as an **administrator** (ability permission callbacks check real capabilities, so an editor's password gets 403s on most calls):

1. **Users → Profile → Application Passwords**
2. Name it `formidable-mcp` → **Add New Application Password**
3. Copy the generated password — WordPress shows it exactly once

Then, in a terminal:

```bash
cd scripts
cp frm-mcp.env.example frm-mcp.env
open -e frm-mcp.env        # or: nano frm-mcp.env, code frm-mcp.env
```

Fill in the three values and save:

```bash
SITE_URL="https://example.com"
WP_USERNAME="your-wp-username"
APPLICATION_PASSWORD="xxxx xxxx xxxx xxxx xxxx xxxx"
```

Notes that save the most time here:

- `WP_USERNAME` is the **username**, not the display name or the email address.
- `APPLICATION_PASSWORD` is the generated application password, **not** the account login password. Spaces belong in it — paste it as generated, keep the quotes.
- `SITE_URL` is the site root (`https://example.com`), not the `/wp-json/...` endpoint. The helper appends the rest.
- `frm-mcp.env` is gitignored. Keep it that way; it is the only place these values should exist outside WordPress.
- If **Application Passwords** is missing from the profile screen, the site is plain HTTP on a non-local domain — WordPress requires HTTPS for them.

### 4. Verify with one command

```bash
./frm-mcp-setup
```

It checks local tools, the config file, TLS, the endpoint, authentication, and the abilities themselves — and when something is wrong it prints the specific fix rather than a stack trace. It creates `frm-mcp.env` from the template if it's missing, changes nothing else, and never prints credential values. A healthy run ends:

```
5. Formidable abilities
  ✓ list-forms works — 12 form(s) on the site
  ✓ views abilities available

Connected.
```

### 5. Make a real call

```bash
./frm-mcp formidable-forms/list-forms
```

From here on, plain language is enough — the skill routes itself:

> Build me a job application form with name, email, résumé upload, and a repeatable "previous employers" section, then create a view listing submissions by date.

## Local sites: the WP-CLI bridge (no password at all)

If you have a shell on the machine hosting WordPress, skip application passwords entirely and run the adapter as a stdio MCP server. Add this to your MCP client's config file:

```json
{
  "mcpServers": {
    "formidable": {
      "type": "stdio",
      "command": "wp",
      "args": ["--path=/absolute/path/to/wordpress", "mcp-adapter", "serve", "--server=formidable-mcp", "--user=1"],
      "env": {}
    }
  }
}
```

The server definition is the same for every client; where it goes is not — `.mcp.json` in the project root for Claude Code, `claude_desktop_config.json` for Claude Desktop, `.cursor/mcp.json` for Cursor, `.vscode/mcp.json` for VS Code agent mode (which nests under `servers` rather than `mcpServers`). Check your client's MCP docs if none of those match.

Then reload or restart the client so it launches the server, and confirm `formidable` shows up in its MCP server list — in Claude Code that's `/mcp`; other clients have an equivalent panel or status indicator.

Use the full path to the `wp` binary if it isn't on PATH. `--user=1` is the WordPress user ID to act as — it must be an administrator. Full details, including the per-client config table, are in `mcp-protocol.md` § "Transport 1".

## Onboarding someone else

When walking a user through this, the sequence that works is: **tell them the command, let them run it, read the output.** Do not offer to hold any part of the credential.

A message that gets someone unstuck, adaptable verbatim:

> Setup is two things you do yourself, then one command I can read the result of.
>
> 1. In WP Admin → Users → Profile → Application Passwords, add one named `formidable-mcp` and copy it.
> 2. In a terminal: `cd <scripts dir> && cp frm-mcp.env.example frm-mcp.env`, then open `frm-mcp.env` in your editor and fill in `SITE_URL`, `WP_USERNAME`, and the password you just copied. Don't paste it here — anything in this chat is in the transcript, and I don't need to see it.
> 3. Run `./frm-mcp-setup` and paste me the output. It never prints your password, and it tells us exactly what's left to fix.

The output is safe to share by design: it can name the site URL, the WordPress username, the config file path, and — only on failure — up to 20 lines of the site's own HTTP response. The application password appears in none of them, in any encoding.

If the user pastes a credential anyway: don't repeat it back, and tell them to revoke that application password in WP Admin and generate a fresh one for the file. Revoking is one click on the same screen that created it.

## Troubleshooting the first connection

`./frm-mcp-setup` diagnoses each of these, but for quick reference:

| Symptom | Cause | Fix |
|---|---|---|
| `Set SITE_URL (env or frm-mcp.env)` | The helper found no config | `cp frm-mcp.env.example frm-mcp.env` and fill it in |
| `404` on `/wp-json/mcp/formidable-mcp` | Formidable API add-on inactive, or permalinks are "Plain" | Activate the add-on; change permalinks |
| `401` / `rest_not_logged_in` | Wrong or revoked password, non-admin user, or the host strips the `Authorization` header | New application password; use an admin; `SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1` in `.htaccess` |
| `curl: (60) SSL certificate problem` | Local dev self-signed certificate | Trust the environment's CA (Local's "Trust" button, `valet trust`, `mkcert -install`) or set `FRM_MCP_CACERT` in `frm-mcp.env` |
| `Session not found` / `Missing Mcp-Session-Id` | Session expired mid-run | Nothing — `frm-mcp` re-initializes and retries automatically |
| Views calls fail, forms calls work | Formidable Views not active (Pro) | Expected on Lite; forms, fields, and entries still work |

Deeper causes and the full error catalogue are in `mcp-protocol.md` § "Common errors and solutions"; adapter bugs and their workarounds are in `gotchas.md`.

## Next

Connected? Go back to `SKILL.md` and read the reference for the task at hand before making calls — `forms-and-fields.md` for building forms, `repeaters.md` before anything repeatable, `entries-and-views.md` before writing view content.
