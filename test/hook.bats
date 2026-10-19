#!/usr/bin/env bats
load helpers/common

# h <json-escaped command>: feed a Claude Code PreToolUse payload to the hook.
h() {
  printf '{"session_id":"x","tool_name":"Bash","tool_input":{"command":"%s","description":"d"}}' "$1" \
    | "$SI" hook claude-code
}

@test "plain sudo is blocked with exit 2" {
  run h 'sudo apt update'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Blocked by sudo-inbox: this needs root."* ]]
  [[ "$output" == *'sudo-inbox add "<title>"'* ]]
  [[ "$output" == *"in their own terminal: sudo-inbox run <n>"* ]]
}

@test "hook only matches command position" {
  run h 'grep sudo /var/log/auth.log'
  [ "$status" -eq 0 ]
  run h 'echo ok && sudo apt update'
  [ "$status" -eq 2 ]
  run h 'find . | xargs sudo rm'
  [ "$status" -eq 2 ]
  run h 'FOO=1 sudo ls'
  [ "$status" -eq 2 ]
  run h 'echo $(sudo id)'
  [ "$status" -eq 2 ]
  run h '/usr/bin/sudo ls'
  [ "$status" -eq 2 ]
  run h 'timeout 5 sudo ls'
  [ "$status" -eq 2 ]
  run h 'ls\nsudo reboot'
  [ "$status" -eq 2 ]
}

@test "su doas pkexec are blocked" {
  for c in 'su -' 'doas ls' 'pkexec ls'; do
    run h "$c"
    [ "$status" -eq 2 ]
  done
}

@test "non-interactive sudo forms pass" {
  for c in 'sudo -n true' 'sudo -l' 'sudo -k'; do
    run h "$c"
    [ "$status" -eq 0 ]
  done
}

@test "passwordless rule passes" {
  export SI_TEST_PASSWORDLESS=docker
  run h 'sudo docker ps'
  [ "$status" -eq 0 ]
  run h 'sudo docker ps && sudo apt update'
  [ "$status" -eq 2 ]
}

@test "escaped quotes in json are handled" {
  run h 'echo \"a\" && sudo id'
  [ "$status" -eq 2 ]
  run h 'echo \"sudo id\"'
  [ "$status" -eq 0 ]
}

@test "other tools pass" {
  run bash -c "echo '{\"tool_name\":\"Read\",\"tool_input\":{}}' | '$SI' hook claude-code"
  [ "$status" -eq 0 ]
}

@test "unknown agent is a usage error" {
  run bash -c "echo '{}' | '$SI' hook other"
  [ "$status" -eq 2 ]
}

@test "install-hook writes new settings" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  run "$SI" install-hook claude-code
  [ "$status" -eq 0 ]
  [[ "$output" == "Hook installed in $HOME/.claude/settings.json." ]]
  grep -q 'sudo-inbox hook claude-code' "$HOME/.claude/settings.json"
  grep -q '"PreToolUse"' "$HOME/.claude/settings.json"
}

@test "install-hook is idempotent" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  "$SI" install-hook claude-code
  run "$SI" install-hook claude-code
  [ "$output" = "Hook already installed." ]
}

@test "install-hook never edits existing settings" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude"
  echo '{"model":"x"}' >"$HOME/.claude/settings.json"
  run "$SI" install-hook claude-code
  [ "$status" -eq 5 ]
  [[ "$output" == *'"PreToolUse"'* ]]
  [ "$(cat "$HOME/.claude/settings.json")" = '{"model":"x"}' ]
}

@test "sudo inside quotes is not blocked" {
  run h 'git commit -m \"docs (sudo setup)\"'
  [ "$status" -eq 0 ]
  run h 'echo \"run this; sudo apt update\"'
  [ "$status" -eq 0 ]
  run h "echo 'a | sudo b'"
  [ "$status" -eq 0 ]
  run h 'echo \"x\" && sudo id'
  [ "$status" -eq 2 ]
}

@test "hook message tells the agent to call wait again on exit 4" {
  run h 'sudo id'
  [[ "$output" == *"--timeout 9m"* ]]
  [[ "$output" == *"exit 4"* ]]
}

@test "codex hook works like the claude-code hook" {
  run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sudo id\"}}' | '$SI' hook codex"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Blocked by sudo-inbox"* ]]
}

@test "install-hook codex writes hooks.json" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  run "$SI" install-hook codex
  [ "$status" -eq 0 ]
  grep -q 'sudo-inbox hook codex' "$HOME/.codex/hooks.json"
  grep -q '"PreToolUse"' "$HOME/.codex/hooks.json"
  [[ "$output" == *"/hooks"* ]]
}

@test "install-hook with existing settings explains the next step" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude"
  echo '{}' >"$HOME/.claude/settings.json"
  run "$SI" install-hook claude-code
  [[ "$output" == *"Next step"* ]]
}

@test "any NOPASSWD rule does not let password commands through" {
  export SI_TEST_NOPASSWD='/usr/bin/systemctl status *'
  export SI_TEST_LISTPW_ANY=1
  run h 'sudo systemctl status cron'
  [ "$status" -eq 0 ]
  run h 'sudo apt update'
  [ "$status" -eq 2 ]
  run h 'sudo systemctl restart cron'
  [ "$status" -eq 2 ]
}

@test "NOPASSWD ALL lets everything through" {
  export SI_TEST_NOPASSWD='ALL'
  run h 'sudo apt update'
  [ "$status" -eq 0 ]
}

@test "sudo with options is blocked" {
  export SI_TEST_PASSWORDLESS=docker
  run h 'sudo -u bob docker ps'
  [ "$status" -eq 2 ]
}
