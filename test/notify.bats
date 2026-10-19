#!/usr/bin/env bats
load helpers/common

@test "notify gets number and title as \$1 and \$2, nothing appended" {
  export SUDO_INBOX_NOTIFY="printf '%s|' \"\$1\" \"\$2\" > '$BATS_TEST_TMPDIR/n'"
  echo true | "$SI" add "Fix wifi"
  sleep 1
  [ "$(cat "$BATS_TEST_TMPDIR/n")" = "1|Fix wifi|" ]
}

@test "notify also fires for secrets" {
  export SUDO_INBOX_NOTIFY="printf '%s|%s' \"\$1\" \"\$2\" > '$BATS_TEST_TMPDIR/n'"
  "$SI" add-secret K --env "$BATS_TEST_TMPDIR/.env"
  sleep 1
  [ "$(cat "$BATS_TEST_TMPDIR/n")" = "1|Set K in $BATS_TEST_TMPDIR/.env" ]
}

@test "notify from config file" {
  mkdir -p "$XDG_CONFIG_HOME/sudo-inbox"
  echo "NOTIFY=touch '$BATS_TEST_TMPDIR/hit'" >"$XDG_CONFIG_HOME/sudo-inbox/config"
  cd "$BATS_TEST_TMPDIR"
  echo true | "$SI" add T
  sleep 1
  [ -e "$BATS_TEST_TMPDIR/hit" ]
  [ ! -e "$BATS_TEST_TMPDIR/1" ]
  [ ! -e "$BATS_TEST_TMPDIR/T" ]
}

@test "failing notify does not fail add" {
  export SUDO_INBOX_NOTIFY="exit 7"
  run bash -c "echo true | '$SI' add T"
  [ "$status" -eq 0 ]
}

@test "slow notify does not block add" {
  export SUDO_INBOX_NOTIFY="sleep 8"
  start=$(date +%s)
  echo true | "$SI" add T
  [ $(( $(date +%s) - start )) -lt 3 ]
}
