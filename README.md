# sudo-inbox

[![Tests](https://img.shields.io/github/actions/workflow/status/dominikamann/sudo-inbox/ci.yml?branch=main&label=tests&style=flat-square)](https://github.com/dominikamann/sudo-inbox/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/dominikamann/sudo-inbox?style=flat-square)](https://github.com/dominikamann/sudo-inbox/releases)
[![Bash](https://img.shields.io/badge/bash-%E2%89%A54-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](sudo-inbox)
[![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square)](sudo-inbox)
[![ShellCheck](https://img.shields.io/badge/shellcheck-clean-brightgreen?style=flat-square)](https://www.shellcheck.net)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Sponsor](https://img.shields.io/badge/support-me-ff5e5b?style=flat-square&logo=ko-fi)](https://github.com/sponsors/dominikamann)

**Your agent needs root. You're on the couch.**

Approve `sudo` for AI agents on headless Linux servers, safely, from any SSH session or your
phone. sudo-inbox is a single Bash script for servers where coding and ops agents (Claude Code,
Codex, OpenCode, Hermes, …) do the work. When an agent needs root, it no longer pastes commands into
the chat for you to copy. It drops a **small script with a reason** into an inbox. You review it
and run it with **one short command** from any SSH session, even from your phone. Your sudo
password goes **only to sudo**. The agent reads the result itself and carries on.

<!-- TODO: docs/demo.gif — agent queues a script, approval in Termius on a phone, agent continues -->

---

## Why

Agents on headless servers hit `sudo` all the time. Today you are the conveyor belt between the
agent and root: copy the command, watch it break at a line wrap, type the password, copy the
output back. Passwords for services end up in the chat or twice in a `.env`.

| Without sudo-inbox | With sudo-inbox |
|---|---|
| Agent pastes commands into the chat | Agent queues a script with title and reason |
| Multi-line commands break when you copy them | You run `sudo-inbox run 3`, nothing to copy |
| You copy the output back to the agent | The agent reads the result with `sudo-inbox wait 3` |
| API tokens and passwords land in the chat | `add-secret` asks you for the value, the agent sees only "set, length 20" |
| Agent keeps trying `sudo` and fails | A hook tells it to use the inbox |

## Features

**For the agent**
- `add` queues a script from stdin or a file and returns the entry number.
- `wait` blocks until you have handled it, then prints status, exit code and output.
- `add-secret` asks you for an API token or password (Jira, GitHub, a database …) and stores it
  in a `.env` file. No pasting into the chat, no command to fill in: you run one command and
  paste the token at a hidden prompt.

**For you**
- `run` shows the title and reason (marked as the agent's words), the directory the script runs
  in, its own checks for risky lines (`rm -rf`, `/etc`, `curl | sh`, `systemctl`, sudoers, SSH
  keys, disks, files the agent could still change, hidden bidi text …), the full script with
  line numbers and a hash, then asks `Run it? [y/N]`.
- Output fits a phone screen. Control characters, also in the script's output, are shown as
  `^[` or `<U+009B>`, so nothing can hide lines or repaint the screen.
- `reject` declines with a reason the agent can read.
- Optional notification command for Matrix, ntfy, Telegram, Pushover or anything else.

**Safety**
- What you saw is exactly what runs: the script is read once into memory and executed from there.
- `sudo -k` before and after every run, so every approval asks for your password.
- A dropped SSH session marks the entry `interrupted` instead of offering it again.
- One root-owned audit log line per approval that uses sudo: time, entry, hash, exit code.
- No dependencies besides bash ≥ 4, coreutils and sudo. One file you can read in one sitting.

## How it works

```
 Agent ──sudo-inbox add──▶ ┌──────────────────────────────┐ ──notify──▶ Matrix / ntfy / …
                           │ entry #3: script + reason     │
 Agent ◀─sudo-inbox wait── │ status, exit code, output     │
                           └──────────────────────────────┘
                                  ▲            │
                       sudo-inbox run 3        │ one sudo call, exact bytes
                                  │            ▼
                            You (SSH tab)     root ──▶ /var/log/sudo-inbox.log
```

1. The agent writes a small script and runs
   `sudo-inbox add "Install LAN/WLAN failover" --reason "wifi drops" < failover.sh`.
2. It tells you: *Entry #3 is waiting. Ask the user to run: sudo-inbox run 3*.
3. In your own terminal (a second SSH tab, or Termius on your phone) you run `sudo-inbox run 3`,
   read it, answer `y` and type your password.
4. The agent's `sudo-inbox wait 3` returns with exit code and output, and it continues.

> Approve in **your own terminal**. sudo needs a real terminal to ask for the password, so
> running `sudo-inbox run` through an agent's shell (for example with `!` in Claude Code) fails
> and the entry simply stays pending.

## Quick start

1. Download, **read**, install root-owned:
   ```bash
   curl -fsSLO https://raw.githubusercontent.com/dominikamann/sudo-inbox/v0.1.0/sudo-inbox
   less sudo-inbox
   sudo install -m 755 -o root -g root sudo-inbox /usr/local/bin/
   ```
   There is deliberately no `curl | sh` one-liner. This tool exists so that nothing runs as root
   unread, and its installer should not be the exception. Install it root-owned so the agent
   cannot change it.
2. Connect your agent: see [Integrations](#integrations) for Claude Code, Codex and others.
3. Optional: get a ping when something is waiting (see [Notifications](#notifications)).

## Integrations

### Claude Code

1. Install the hook. It runs before every Bash command and redirects `sudo`, `su`, `doas` and
   `pkexec` to the inbox, while commands covered by a `NOPASSWD` rule keep working:
   ```bash
   sudo-inbox install-hook claude-code
   ```
   This creates `~/.claude/settings.json`. If that file already exists, nothing is changed and the
   command prints the entry to add under `"hooks"` → `"PreToolUse"`:
   ```json
   { "matcher": "Bash", "hooks": [ { "type": "command", "command": "/usr/local/bin/sudo-inbox hook claude-code" } ] }
   ```
2. Optional but recommended: paste the block from
   [docs/agent-instructions.md](docs/agent-instructions.md) into your `CLAUDE.md`, so Claude
   uses the inbox right away instead of finding out through the hook.
3. Restart Claude Code. Ask it to do something that needs root, then approve it in a second
   SSH session with `sudo-inbox run <n>`.

### Codex

Codex hooks use the same format, so the same hook works:

1. Install it:
   ```bash
   sudo-inbox install-hook codex
   ```
   This creates `~/.codex/hooks.json` (or prints the entry to add if the file exists).
2. In Codex, run `/hooks` once to review and trust the new hook. Codex does not run hooks you
   have not trusted.
3. Paste the block from [docs/agent-instructions.md](docs/agent-instructions.md) into your
   `AGENTS.md`.

### Other agents (OpenCode, Hermes, own scripts, …)

Any agent that can run shell commands can use sudo-inbox. Paste the block from
[docs/agent-instructions.md](docs/agent-instructions.md) into `AGENTS.md` or the agent's
instructions. Without a hook nothing stops the agent from trying `sudo`, but without a terminal
that simply fails, and the instructions tell it what to do instead.

### Waiting for you

Agent tools usually cut off long commands (Claude Code after 2 minutes by default, 10 at most).
`sudo-inbox wait` therefore waits 9 minutes by default and exits with `4` if you have not
answered yet. The agent then simply calls `wait` again. The hook and the instructions tell it so.

## Using it

### Commands

| Command | Who | What |
|---|---|---|
| `add <title> [--reason <text>] [-f <file>]` | agent | Queue a script (stdin or `-f`), max 120 KiB, runs in the current directory |
| `add-secret <NAME> --env <path> [options]` | agent | Ask you to set a secret in a `.env` file |
| `wait <n> [--timeout 9m]` | agent | Block until handled (`90s`, `9m`, `1h`), exit 4 if still waiting |
| `result <n>` | agent | Status, exit code and output, without waiting |
| `list` | you | Waiting and recent entries |
| `show <n>` | you | Entry in full |
| `run [<n>]` | you | Review and run (default: oldest waiting) |
| `reject <n> [<reason>]` | you | Decline |
| `secret <NAME> --env <path> [options]` | you | Set a secret directly |
| `install-hook claude-code\|codex` | you | Install the hook for Claude Code or Codex |
| `hook claude-code\|codex` | the agent | The `PreToolUse` hook itself |

Secret options: `--min N`, `--max N`, `--owner user:group`, `--mode 600`.

`wait` and `result` exit with `0` (done, script succeeded), `1` (done, script failed, or
interrupted), `3` (rejected) or `4` (timeout). An interrupted entry may have run partly and is
never run again; check the system and queue a new entry.

Other commands exit with `0` on success, `2` for usage errors, `5` when something is refused
(missing entry, wrong state, path or validation rules) and `6` when sudo did not run anything
(wrong password, no terminal).

### API tokens: the agent needs one, you never paste it into the chat

This needs no root at all. Say your agent has to talk to the GitLab API (Jira, GitHub or a
database work the same way):

```bash
# agent
sudo-inbox add-secret GITLAB_TOKEN --env ~/work/release-bot/.env --min 20
sudo-inbox wait 7 --timeout 9m

# you, in your own terminal: one command, then paste the token at the hidden prompt
sudo-inbox run 7

# agent: load it without ever printing it
set -a; . ~/work/release-bot/.env; set +a
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/user
```

The token never appears in the chat, the transcript or a command line. An agent running as
your user could still read the file, so this keeps tokens out of the conversation, not out of
reach (see [Secrets](#secrets) for how to keep one from the agent entirely).

### Secrets

```bash
# agent
sudo-inbox add-secret SMTP_PASSWORD --env /srv/mailer/.env --min 16
# you
sudo-inbox run 4        # shows file, key, mode and owner, then asks for the value twice
```

The value is read hidden, checked for length and written atomically as `KEY=value`,
replacing an existing key (also `export KEY=`) instead of adding it twice. The format works for
Docker Compose and systemd `EnvironmentFile`. Values with spaces, `#`, `$` or `"` are
single-quoted. Values with single quotes or newlines are refused. Only files named `.env`,
`.env.*` or `*.env` are allowed, and symlinks are refused, so an agent cannot point a secret at
`sudoers` or `authorized_keys`.

Where the file lives decides who can read it afterwards:

- **In a directory you can write** (your projects): sudo-inbox writes it as you, never with
  sudo. Keep in mind that an agent running as your user can read that file too. The secret
  stays out of the chat, not out of reach.
- **In a root-owned directory** (for example `/etc/myapp/` or a root-owned `/opt/stack/`): the
  write goes through sudo, with the value on stdin, never on the command line, and the file
  keeps its owner or gets the one from `--owner`. This is how you keep a secret away from an
  agent that runs as you.
- **Below a directory you can write, but not writable itself**: refused, because you (or the
  agent) could swap the directory while root writes.

### Notifications

Set `SUDO_INBOX_NOTIFY` in the agent's environment, or put `NOTIFY=<command>` into
`~/.config/sudo-inbox/config`. The command gets the entry number and title as `$1` and `$2`,
runs in the background and may fail without bothering anyone.

```bash
# Matrix (a bot account's access token)
NOTIFY=curl -s -X PUT -H "Authorization: Bearer $MATRIX_TOKEN" -d "{\"msgtype\":\"m.text\",\"body\":\"sudo-inbox: entry #$1 is waiting\"}" "https://matrix.example.org/_matrix/client/v3/rooms/!room:example.org/send/m.room.message/si-$1-$(date +%s)"
# ntfy
NOTIFY=curl -s -d "sudo-inbox #$1: $2" https://ntfy.sh/your-topic
# Telegram
NOTIFY=curl -s "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d chat_id=$TG_CHAT -d text="sudo-inbox #$1: $2"
# Pushover
NOTIFY=curl -s https://api.pushover.net/1/messages.json -d token=$PO_TOKEN -d user=$PO_USER -d message="sudo-inbox #$1: $2"
```

## Compared to

| Tool | Approach | Gap for headless servers |
|---|---|---|
| [sudoplz](https://github.com/crypdick/sudoplz) | Desktop dialog, password stored encrypted to your SSH key | Needs a desktop on the same machine, stores the password |
| [claude-sudo-askpass](https://github.com/dgutson/claude-sudo-askpass) | Desktop dialog via `SUDO_ASKPASS` | Needs a desktop, Claude Code only |
| [Hook + `sudo -v`](https://www.dgt.is/blog/2026-03-10-ai-sudo-with-agents/) | Block until you run `sudo -v` elsewhere | One shared sudo login for a while instead of one approval, no review, no output back |

sudo-inbox is built for a server without a screen and a human somewhere else: it shows the
exact content before it runs, returns the output to the agent and covers service secrets too.

## Documentation

- [Agent instructions](docs/agent-instructions.md): the block for `AGENTS.md` / `CLAUDE.md`
- [Security model](docs/security.md)
- [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)

## Security

The agent can queue work but never run it: running needs your sudo password in a real terminal.
The bytes you review are the bytes that run, but files a script reads (`./install.sh`,
`~/nginx.conf`) can still change, which is why the review flags them. If the agent runs as the
same Unix user as you (the usual setup today), it could in principle tamper with your shell.
Read [docs/security.md](docs/security.md) for the full model. Report vulnerabilities privately as
described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)

---

<p align="center">Proudly provided by <a href="https://amannlabs.eu">amannlabs.eu</a></p>
