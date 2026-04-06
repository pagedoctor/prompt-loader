# Prompt Loader

A single-command installer that downloads and extracts Pagedoctor learning artifacts into your Composer project's `vendor/` folder, so your AI coding agent can immediately learn from episode-specific skills, tasks, and code snippets, without interfering with your local project structure.

## What is this?

The [Pagedoctor Learning Platform](https://pagedoctor.de) publishes video episodes and community resources for TYPO3 developers. Many episodes ship with a **AI-ready prompt artifact** — a package containing:

- Context and background for the episode topic
- Skills and tasks your AI agent can perform
- Code snippets and patterns to apply directly
- Instructions that prime the agent for the episode's coding workflow

**Prompt Loader** fetches that artifact over a secure, authenticated URL and extracts it directly into your project's `vendor/` folder. Nothing is added to `composer.json` or `composer.lock` — the artifact is a dev-only AI tool, not a managed dependency. After installation it outputs a ready-to-paste prompt so your agent loads everything from the artifact and is immediately ready to assist.

## Requirements

- `sh` (POSIX-compatible shell)
- `curl` or `wget`
- `unzip`

## Usage

Many Pagedoctor episodes display its own install command. The general form is:

```sh
curl -sSL https://raw.githubusercontent.com/pagedoctor/prompt-loader/main/install.sh \
  | sh -s -- <artifact-url>
```

With `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/pagedoctor/prompt-loader/main/install.sh \
  | sh -s -- <artifact-url>
```

Replace `<artifact-url>` with the URL shown on the episode page.

### Example

```sh
curl -sSL https://raw.githubusercontent.com/pagedoctor/prompt-loader/main/install.sh \
  | sh -s -- https://pagedoctor.de/api/prompt-loader/get?uid=123
```

## Authentication

The first time you run Prompt Loader you will be prompted for your Pagedoctor authentication token. The token is stored securely at:

| Platform | Path |
|----------|------|
| Linux    | `$XDG_CONFIG_HOME/prompt-loader/token` (default: `~/.config/prompt-loader/token`) |
| macOS    | `~/Library/Application Support/prompt-loader/token` |
| Windows  | `%APPDATA%\prompt-loader\token` |

The token file is created with `600` permissions (owner read/write only). Subsequent runs reuse the stored token. If the token becomes invalid (HTTP 401/403), you are prompted for a new one automatically.

## After installation

Once the artifact is installed to `vendor/`, Prompt Loader prints a prompt you can paste directly into any AI coding agent (Claude Code, Cursor, Windsurf, etc.):

```
══════════════════════════════════════════════
   Prompt Loader — Installation Complete
══════════════════════════════════════════════
Package : pagedoctor/ep042-fluid-templating
Location: vendor/pagedoctor/ep042-fluid-templating

Detected coding agents: claude cursor

Paste the following prompt into your AI coding agent to get started:

────────────────────────────────────────────────
I have installed the Pagedoctor learning artifact `pagedoctor/ep042-fluid-templating`.
Please load all context, skills, tasks, instructions, and code snippets from
`vendor/pagedoctor/ep042-fluid-templating` and apply them to assist me with TYPO3 development.
────────────────────────────────────────────────
```

Copy the prompt, paste it into your agent, and start coding.

## License

MIT — Copyright (c) Colin Atkins (Pagedoctor)
