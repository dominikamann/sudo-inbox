# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0]

### Added

- `add`, `list`, `show`, `run`, `reject`, `wait` and `result`: agents queue scripts with a title
  and reason, you review and run them through a single `sudo` call, the agent reads the result.
- Review screen with the agent's title and reason, sudo-inbox's own checks for risky lines,
  line numbers, a hash and a warning for long scripts. Control characters are shown visibly.
- `sudo -k` before and after every run, and an audit line in `/var/log/sudo-inbox.log`.
- `add-secret` and `secret`: set values in `.env` files without the agent seeing them.
- Optional notification command (`SUDO_INBOX_NOTIFY` or `~/.config/sudo-inbox/config`).
- `hook claude-code` and `install-hook claude-code`: a `PreToolUse` hook that redirects `sudo`,
  `su`, `doas` and `pkexec` to the inbox and lets passwordless rules through.
- Scripts run in the directory they were queued from. Entries interrupted by a hangup or Ctrl-C
  are marked `interrupted` and never run again.
