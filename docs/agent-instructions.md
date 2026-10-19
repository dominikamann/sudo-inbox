# Agent instructions

Paste this block into `AGENTS.md`, `CLAUDE.md` or your agent's system prompt. Claude Code and
Codex users can also install the hook (`sudo-inbox install-hook claude-code` or
`sudo-inbox install-hook codex`), which tells the agent the same thing whenever it tries to use
`sudo`.

```markdown
## Root access (sudo-inbox)

You cannot run sudo, su, doas or pkexec yourself. When something needs root:

1. Put the commands in a small script with one purpose (under 60 lines).
2. Queue it: `sudo-inbox add "<short title>" --reason "<why this is needed>" < script.sh`
3. Ask the user to run this in their own terminal: `sudo-inbox run <n>`
4. Wait for the result: `sudo-inbox wait <n> --timeout 9m` (exit 0 = success,
   1 = script failed or interrupted, 3 = rejected with a reason, 4 = the user has not answered
   yet: run the same `wait` again). Read the output before you continue.

For passwords and API keys never ask the user to paste them into the chat. Use
`sudo-inbox add-secret <NAME> --env <path to .env>` and wait for it the same way.
You will only learn that the value was set and its length.
```
