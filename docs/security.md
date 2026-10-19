# Security model

sudo-inbox moves the decision to run something as root from the agent to you, and makes that
decision easy to take carefully. It does not make an agent trustworthy.

## What it guarantees

- **The agent can queue, not run.** `add` and `add-secret` need no privileges. Running needs
  `sudo-inbox run` in a terminal where you type your sudo password.
- **What you saw is what runs.** `run` reads the script once into memory, renders exactly those
  bytes, hashes them and passes them to `bash -c` inside a single `sudo` call. Changing the file
  after you looked at it has no effect.
- **No password handling.** sudo asks for the password itself. sudo-inbox never sees, stores or
  forwards it.
- **No lingering sudo login.** `sudo -k` runs before and after every approval, so the agent cannot
  reuse a cached login from your approval.
- **Honest display.** Control characters in titles, reasons and scripts are shown in caret
  notation (`^[`), so escape sequences cannot hide lines or fake the prompt. Title and reason are
  labelled as the agent's words. The checks below them come from sudo-inbox itself.
- **Audit log.** Every approval appends one line to `/var/log/sudo-inbox.log` from inside the
  same root call: time, user, entry, type, hash, exit code and title.
- **Secrets stay out of argv and chat.** Values are read hidden, passed on stdin, and only
  written to `.env` files that are not symlinks.

## What it does not protect against

- **An agent running as your own Unix user.** It can edit your shell startup files, aliases or
  `PATH` and so fake `sudo-inbox` or `sudo` in your terminal. If that matters to you, run the
  agent as a separate user and keep `sudo-inbox` root-owned in `/usr/local/bin`.
- **Approving without reading.** The tool flags common risky patterns, but a script can still
  do harm in ways no pattern catches. Prefer small scripts with one purpose and reject anything
  you do not understand.
- **Output.** Everything a script prints goes back to the agent. Do not print secrets.
- **The hook is a nudge, not a wall.** It catches `sudo`, `su`, `doas` and `pkexec` in command
  position but does not parse quoted strings. The real boundary is sudo's password prompt.
- **The inbox directory.** It lives in the user's state directory
  (`~/.local/state/sudo-inbox`). An agent with the same user can rewrite statuses or results
  there. That only misleads the agent itself. Your decisions rely on what `run` shows you.
