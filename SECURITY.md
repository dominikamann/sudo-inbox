# Security policy

## Reporting a vulnerability

Please do **not** open a public issue. Report it privately via
[GitHub Security Advisories](https://github.com/dominikamann/sudo-inbox/security/advisories/new).
You will get an answer within a few days.

## Supported versions

Only the latest release receives security fixes.

## Scope

The threat model is described in [docs/security.md](docs/security.md). Ways for an agent to get
a script run as root without the user seeing exactly that script, to read or reuse the sudo
password or login, or to write a secret outside the allowed `.env` files are in scope.
