# Security model

sudo-inbox moves the decision to run something as root from the agent to you, and makes that
decision easy to take carefully. It does not make an agent trustworthy.

## What it guarantees

- **The agent can queue, not run.** `add` and `add-secret` need no privileges. Running needs
  `sudo-inbox run` in a terminal where you type your sudo password.
- **What you saw is what runs.** `run` reads the script once into memory, renders exactly those
  bytes, hashes them and passes them to `bash -c` inside a single `sudo` call. Changing the file
  after you looked at it has no effect. This covers the script itself, not files it reads: a
  line like `bash ./install.sh` or `cp ~/app.conf /etc/` uses a file the agent can still change,
  and the review flags such lines. Ask for inline content (heredocs) instead.
- **Known working directory.** The script runs in the directory it was queued from, shown as
  `Runs in:` on the review screen, not in whatever directory your terminal is in.
- **No password handling.** sudo asks for the password itself. sudo-inbox never sees, stores or
  forwards it.
- **No lingering sudo login.** The approved script runs with `sudo -k`, which asks for the
  password and does not create a cached login, and `sudo -k` runs again before and after. So no
  sudo login exists that the agent could reuse, not even while a long script runs.
- **Honest display.** Every field read from the inbox, the script and the script's live output
  are shown with control characters in caret notation (`^[`), C1 controls and bidi overrides as
  `<U+XXXX>`, and newlines in titles as `^J`. Escape sequences cannot hide lines, repaint the
  screen or fake the prompt. Lines with any non-ASCII character (zero-width spaces,
  look-alike letters) or more than 200 characters are flagged, and so are entries older than a
  day. Title and reason are labelled as the agent's words. The checks
  below them come from sudo-inbox itself.
- **No second run after a dropped session.** The entry is marked `running` before sudo starts.
  A hangup or Ctrl-C marks it `interrupted`, logs that as root, and `run` refuses it from then
  on, because it may have run partly.
- **Audit log.** Every approval that uses sudo appends one line to `/var/log/sudo-inbox.log`
  from inside the same root call: time, user, entry, type, hash, exit code and title. Secrets
  written into your own directories need no sudo and are only logged in your user log.
- **Secrets stay out of argv and chat.** Values are read hidden, passed on stdin, and only
  written to `.env` files that are not symlinks. Secret fields are read once, validated, shown
  and written exactly as shown.
- **Root writes secrets only where you cannot interfere.** If you can write the target
  directory, the secret is written as you, without sudo. If you can write any directory above
  it, the write is refused. Otherwise root re-checks the real directory and that the file is not
  a symlink before it writes, and an unreadable file is never overwritten.

## What it does not protect against

- **An agent running as your own Unix user.** It can edit your shell startup files, aliases or
  `PATH` and so fake `sudo-inbox` or `sudo` in your terminal, and it can read every file you can
  read, including `.env` files in your own directories. Keep `sudo-inbox` root-owned in
  `/usr/local/bin`, call it by that path if in doubt, and keep secrets the agent must not see in
  root-owned directories. Running the agent as a separate user is stronger, but in v0.1 each
  user has their own inbox, so that setup is not supported yet.
- **Approving without reading.** The tool flags common risky patterns, but a script can still
  do harm in ways no pattern catches. Prefer small scripts with one purpose and reject anything
  you do not understand.
- **Output.** Everything a script prints goes back to the agent. Do not print secrets.
- **The hook is a nudge, not a wall.** It catches `sudo`, `su`, `doas` and `pkexec` in command
  position and ignores quoted text, so `bash -c "sudo …"` slips through. The real boundary is
  sudo's password prompt.
- **The inbox directory.** It lives in the user's state directory
  (`~/.local/state/sudo-inbox`). An agent with the same user can rewrite statuses or results
  there. That only misleads the agent itself. Your decisions rely on what `run` shows you.
