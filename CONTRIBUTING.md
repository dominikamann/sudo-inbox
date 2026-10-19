# Contributing

Thanks for helping! Bug reports, ideas and pull requests are welcome.

## Setup

Requirements: Docker (the tests run in an Ubuntu 24.04 container with bats, shellcheck and sudo),
or a Linux machine with `bats` and `shellcheck` installed.

```bash
test/run.sh                  # shellcheck + the whole bats suite in Docker
test/run.sh test/run.bats    # one file
bats test                    # directly on Linux
```

The tests never call the real sudo: `test/helpers/bin/sudo` is a stub that comes first in `PATH`.
The script itself has no test switches, because the agent shares its environment.

## Guidelines

- Write a failing test first, then the code that makes it pass.
- Keep it one dependency-free file: bash ≥ 4, coreutils and sudo only.
- Anything that runs as root goes through the single `sudo` call in `root_exec`.
- Every generated line of output must fit 60 columns, so it reads well on a phone.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:` …).

## Pull request checklist

- [ ] Tests added or updated, `test/run.sh` passes (includes shellcheck)
- [ ] Docs updated (`README.md`, `docs/`) if behaviour or options changed
- [ ] `CHANGELOG.md` entry under "Unreleased"
