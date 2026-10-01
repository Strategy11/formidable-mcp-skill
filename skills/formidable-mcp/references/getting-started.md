# Getting Started: First-Time Setup

Read this when: the site has never been connected from this machine, someone asks "how do I get started / what do I run?", or the very first MCP call fails on authentication. Everything else in this skill assumes a working connection — this file creates one.

**Rule that outranks everything below: never ask for credentials.** Not in chat, not as a command to run, not "paste it and I'll put it in the file for you". The credential travels as a file: downloaded from Formidable's settings screen (or, on older versions, typed into `frm-mcp.env` by the user), and an assistant may move that file into place but never opens it. An assistant's job here is to say which command to run and to read the output — see § "Onboarding someone else" for wording that works.

## Which path applies

| Situation | Path | Needs a password? |
|---|---|---|
| Remote site, staging, production, or any site you don't have a shell on | **HTTP + `frm-mcp` helper** — § "The two-step setup", or step by step below | Yes — a scoped application password, delivered as a downloaded `frm-mcp.env` |
| Local dev site you have a terminal on (Local by Flywheel, Valet, DDEV, wp-env) | **WP-CLI stdio bridge** — see § "Local sites" | No |

When both apply, prefer the WP-CLI bridge: no credential exists to leak.

## The two-step setup from Formidable's settings (recommended)

Formidable's settings screen walks the user through this, and hands the assistant the rest. In WP Admin → **Formidable → Settings → MCP**:

1. Turn on **Enable the Formidable MCP server**, then **Download frm-mcp.env**. Each download creates a fresh application password that only works on the Formidable MCP endpoint (`mcp-protocol.md` § "Scoped connection-file passwords").
2. Pick **Claude Code** or **Codex**, click **Copy setup prompt**, and paste it into the assistant.

The step-2 box shows **Connected** once the downloaded password is used for the first time.

**When you receive that prompt**, it asks for three things:

1. **Install or update the skill** — the commands are in § "1. Install the skill". If the skill only loads after a restart, say so and stop there.
2. **Move the download into place** — the newest `~/Downloads/frm-mcp*.env` goes to `~/.config/formidable-mcp/frm-mcp.env`, moved with `mv` and never opened, printed, or quoted. Exact commands in `mcp-protocol.md` § "Moving a downloaded file into place". (Older prompts say "beside the skill's `scripts/frm-mcp`". That works too, but a plugin update loses it, so prefer the config directory.)
3. **Run `scripts/frm-mcp-setup`** and report what it says. On `Connected.`, carry on with the user's Formidable requests.

If anything fails, use § "Troubleshooting the first connection" — and never ask for the values in the file.

## Step by step (HTTP path)

The same setup by hand, for a user doing it themselves or a Formidable version without the MCP settings section.

### 1. Install the skill

**Claude Code** — as a plugin:

```
/plugin marketplace add Strategy11/formidable-mcp-skill
/plugin install formidable-mcp@formidable
```

**Codex** — as a plugin, from the same repository (Codex reads the same marketplace file):

```bash
codex plugin marketplace add Strategy11/formidable-mcp-skill
codex plugin add formidable-mcp@formidable
```

Start a new session afterward so the skill is picked up.

**Without a plugin system** — clone the repository and link the skill directory into the folder your agent scans for skills:

| Agent | Just you, every project | One project (run from its root) |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex | `~/.agents/skills/` | `.agents/skills/` |

```bash
git clone https://github.com/Strategy11/formidable-mcp-skill.git ~/formidable-mcp-skill
mkdir -p ~/.claude/skills    # or ~/.agents/skills, .claude/skills, .agents/skills
ln -s ~/formidable-mcp-skill/skills/formidable-mcp ~/.claude/skills/formidable-mcp
```

A symlink keeps the skill current with `git pull`; copying the directory works too. Link it into both folders to use it from both agents. Other agents take the same directory wherever they look for skills or instructions.

Nothing here is tied to a particular assistant: the references are plain Markdown and the helpers are POSIX shell scripts that only need `curl` and `jq`. An agent that can read files and run commands can use this; a person with a terminal can too.

However it got installed, the helper scripts live in the skill's `scripts/` directory:

| Installed as | `scripts/` is at |
|---|---|
| Claude Code plugin | `~/.claude/plugins/cache/formidable/formidable-mcp/<version>/skills/formidable-mcp/scripts/` |
| Codex plugin | `~/.codex/plugins/cache/formidable/formidable-mcp/<version>/skills/formidable-mcp/scripts/` |
| Clone + link | `skills/formidable-mcp/scripts/` inside the clone |

If you're still not sure:

```bash
find ~ -name frm-mcp-setup -not -path '*/.git/*' 2>/dev/null
```

The rest of this file writes that directory as `scripts/` — `cd` into it first.

### 2. Confirm the site side is ready

On the WordPress site: **Formidable Forms** active, with **Formidable → Settings → MCP → Enable the Formidable MCP server** turned on, and permalinks set to anything other than "Plain". The MCP adapter ships with Formidable and needs WordPress 7.0+ and PHP 7.4+; if something blocks it, the settings screen says what. (Formidable versions without an MCP settings section need the **Formidable Forms API** add-on, which ships the adapter.) Step 4 below tells you if anything is missing, so this is a glance, not a project.

### 3. Put a connection file in `~/.config/formidable-mcp/frm-mcp.env`

**Download it (recommended).** Formidable → Settings → MCP → **Download frm-mcp.env**, as an **administrator** (ability permission callbacks check real capabilities, so an editor's password gets 403s on most calls). Then move it into place:

```bash
mkdir -p ~/.config/formidable-mcp
mv "$(ls -t ~/Downloads/frm-mcp*.env | head -1)" ~/.config/formidable-mcp/frm-mcp.env
chmod 600 ~/.config/formidable-mcp/frm-mcp.env
```

That's the whole step: the file comes filled in, and its password only works for Formidable MCP. The config directory matters for plugin installs: their `scripts/` directory is replaced on every update, and a file kept beside the scripts would be lost with it. (A `frm-mcp.env` beside the scripts still works and wins if present, which suits a cloned install. `FRM_MCP_ENV=/path/to/file` overrides both.)

**Or make one by hand**, on a Formidable version without the download button:

1. WP Admin → **Users → Profile → Application Passwords**
2. Name it `formidable-mcp` → **Add New Application Password**
3. Copy the generated password — WordPress shows it exactly once

Then, in a terminal:

```bash
mkdir -p ~/.config/formidable-mcp
cp scripts/frm-mcp.env.example ~/.config/formidable-mcp/frm-mcp.env
chmod 600 ~/.config/formidable-mcp/frm-mcp.env
open -e ~/.config/formidable-mcp/frm-mcp.env    # or: nano, code
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
- Either way, `frm-mcp.env` should be the only place these values exist outside WordPress. Keep it out of version control.
- If **Application Passwords** (or the download button) is missing, the site is plain HTTP on a non-local domain — WordPress requires HTTPS for them.

### 4. Verify with one command

```bash
./frm-mcp-setup
```

It checks local tools, the config file, TLS, the endpoint, authentication, and the abilities themselves — and when something is wrong it prints the specific fix rather than a stack trace. If no config file exists anywhere, it creates `~/.config/formidable-mcp/frm-mcp.env` from the template (readable only by you); it changes nothing else, and never prints credential values. A healthy run ends:

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

### Running `frm-mcp` from inside Codex

Codex runs shell commands in a sandbox that, by default, has no network access and can only write inside the workspace. `frm-mcp` needs both — it calls the site, and it saves a session file next to itself, which for a plugin install is under `~/.codex/`. So the first call from Codex fails with `curl: (7) Failed to connect` until it runs outside the sandbox: approve that when Codex asks. Claude Code has no equivalent restriction by default; it just asks for permission to run the command. The stdio bridge below avoids the question entirely, since MCP servers aren't run through the shell sandbox.

## Local sites: the WP-CLI bridge (no password at all)

If you have a shell on the machine hosting WordPress, skip application passwords entirely and run the adapter as a stdio MCP server. The `wp` command and arguments are the same for every client; only the config format differs.

**Claude Code** — `.mcp.json` in the project root (Claude Desktop takes the same JSON in `claude_desktop_config.json`):

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

**Codex** — `~/.codex/config.toml`, or `.codex/config.toml` in a trusted project:

```toml
[mcp_servers.formidable]
command = "wp"
args = ["--path=/absolute/path/to/wordpress", "mcp-adapter", "serve", "--server=formidable-mcp", "--user=1"]
```

Either client can also write that entry for you: `claude mcp add --scope project formidable -- wp --path=... mcp-adapter serve --server=formidable-mcp --user=1`, or the same arguments after `codex mcp add formidable --`.

Then start a new session so the client launches the server, and confirm `formidable` is listed: `/mcp` in either client, or `codex mcp list` from a terminal. Other clients (Cursor, VS Code) are in `mcp-protocol.md` § "Transport 1".

Use the full path to the `wp` binary if it isn't on PATH. `--user=1` is the WordPress user ID to act as — it must be an administrator. Full details, including the per-client config table, are in `mcp-protocol.md` § "Transport 1".

## Onboarding someone else

When walking a user through this, the sequence that works is: **tell them the command, let them run it, read the output.** Do not offer to hold any part of the credential.

A message that gets someone unstuck, adaptable verbatim:

> Setup is two clicks in WordPress, then I do the rest.
>
> 1. In WP Admin → Formidable → Settings → MCP, turn on the MCP server and click **Download frm-mcp.env**.
> 2. Tell me when it's downloaded. I'll move it into place without opening it, and run a check that never prints the password. Please don't paste the file's contents here — anything in this chat is in the transcript, and I don't need to see it.

On a Formidable version without that button, swap step 1 for creating an application password (Users → Profile → Application Passwords) and having them fill in `~/.config/formidable-mcp/frm-mcp.env` from the template themselves, then run `frm-mcp-setup` and read its output.

The output is safe to share by design: it can name the site URL, the WordPress username, the config file path, and — only on failure — up to 20 lines of the site's own HTTP response. The application password appears in none of them, in any encoding.

If the user pastes a credential anyway: don't repeat it back, and tell them to revoke it and download a fresh file. For a downloaded file that's **Formidable → Settings → MCP → Manage connection files → Revoke**; for a hand-made one, **Users → Profile → Application Passwords**. The same list shows each file's last use, so it's also where to clean up old downloads — each one stays valid until revoked, including after Formidable is deactivated.

## Troubleshooting the first connection

`./frm-mcp-setup` diagnoses each of these, but for quick reference:

| Symptom | Cause | Fix |
|---|---|---|
| `Set SITE_URL (env or …/frm-mcp.env)` | The helper found no config | Download `frm-mcp.env` and move it to the path the message names (step 3) |
| `404` on `/wp-json/mcp/formidable-mcp` | MCP server toggle off or blocked, or permalinks are "Plain" | Formidable → Settings → MCP → turn it on (the screen names any blocker); change permalinks. Older Formidable: activate the API add-on |
| `401` / `rest_not_logged_in` / `rest_forbidden` | Wrong or revoked password, non-admin user, or the host strips the `Authorization` header | Download a new file; use an admin; `SetEnvIf Authorization "(.*)" HTTP_AUTHORIZATION=$1` in `.htaccess` |
| `403` / `frm_mcp_skill_scope` | A downloaded password used outside Formidable MCP — another REST route, `discover-abilities`, or a non-Formidable ability | Expected: these passwords are scoped. Use `frm-mcp` with `formidable-forms/*` abilities; see `mcp-protocol.md` § "Scoped connection-file passwords" |
| Worked before a skill update, now `Set SITE_URL …` | `frm-mcp.env` was beside the scripts in an old plugin version's directory | Download a new file and put it in `~/.config/formidable-mcp/` |
| `curl: (60) SSL certificate problem` | Local dev self-signed certificate | Trust the environment's CA (Local's "Trust" button, `valet trust`, `mkcert -install`) or set `FRM_MCP_CACERT` in `frm-mcp.env` |
| `Session not found` / `Missing Mcp-Session-Id` | Session expired mid-run | Nothing — `frm-mcp` re-initializes and retries automatically |
| `curl: (7) Failed to connect` from Codex, but `./frm-mcp-setup` works in a terminal | Codex's sandbox blocks network by default | Approve running the command outside the sandbox — see § "Running `frm-mcp` from inside Codex" |
| Views calls fail, forms calls work | Formidable Views not active (Pro) | Expected on Lite; forms, fields, and entries still work |
| Views calls fail with `frm_ability_addon_outdated` | Formidable Views is active but older than the abilities need | Update Formidable Views |

Deeper causes and the full error catalogue are in `mcp-protocol.md` § "Common errors and solutions"; adapter bugs and their workarounds are in `gotchas.md`.

## Next

Connected? Go back to `SKILL.md` and read the reference for the task at hand before making calls — `forms-and-fields.md` for building forms, `repeaters.md` before anything repeatable, `entries-and-views.md` before writing view content.
