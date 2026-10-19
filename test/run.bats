#!/usr/bin/env bats
load helpers/common

@test "run executes after y and records result" {
  echo 'echo hello; exit 3' | "$SI" add T
  run bash -c "echo y | '$SI' run 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *hello* ]]
  [[ "$output" == *"Done. Exit code 3."* ]]
  [ "$(cat "$ENTRIES/1/exit_code")" = 3 ]
  [ "$(cat "$ENTRIES/1/output")" = hello ]
  [ "$(cat "$ENTRIES/1/status")" = done ]
  grep -q 'entry=1 type=script sha256=' "$SI_TEST_ROOT_LOG"
  grep -q 'exit=3 title=T' "$SI_TEST_ROOT_LOG"
}

@test "output does not contain the sentinel" {
  echo 'echo hello' | "$SI" add T
  run bash -c "echo y | '$SI' run 1"
  [[ "$output" != *__SUDO_INBOX_STARTED__* ]]
  [ -f "$ENTRIES/1/output" ]
  ! grep -q __SUDO_INBOX_STARTED__ "$ENTRIES/1/output"
}

@test "default answer is no" {
  echo 'echo x' | "$SI" add T
  run bash -c "echo | '$SI' run 1"
  [[ "$output" == *"Not run. Entry #1 stays pending."* ]]
  [ "$(cat "$ENTRIES/1/status")" = pending ]
  [ ! -e "$SI_TEST_SUDO_CALLS" ]
}

@test "run without number takes oldest pending" {
  echo 'echo one' | "$SI" add a
  echo 'echo two' | "$SI" add b
  run bash -c "echo y | '$SI' run"
  [[ "$output" == *one* ]]
  [ "$(cat "$ENTRIES/2/status")" = pending ]
}

@test "run on empty inbox" {
  run "$SI" run
  [ "$status" -eq 0 ]
  [ "$output" = "Inbox is empty." ]
}

@test "sudo -k before and after" {
  echo 'true' | "$SI" add T
  echo y | "$SI" run 1
  [ "$(head -1 "$SI_TEST_SUDO_CALLS")" = "-k" ]
  [ "$(tail -1 "$SI_TEST_SUDO_CALLS")" = "-k" ]
  [ "$(grep -cx -- -k "$SI_TEST_SUDO_CALLS")" -eq 2 ]
}

@test "run executes the bytes that were shown" {
  echo 'echo original' | "$SI" add T
  export SI_TEST_SUDO_BEFORE="echo 'echo tampered' > '$ENTRIES/1/script'"
  run bash -c "echo y | '$SI' run 1"
  [[ "$output" == *original* ]]
  [[ "$output" != *tampered* ]]
}

@test "run preserves exotic script bytes" {
  cat >"$BATS_TEST_TMPDIR/s" <<'EOS'
printf '%s|' 'single' "double" "$(echo sub)" 'back\slash' "ü"
EOS
  printf '%s' "$(cat "$BATS_TEST_TMPDIR/s")" | "$SI" add T
  run bash -c "echo y | '$SI' run 1"
  [ "$(cat "$ENTRIES/1/output")" = 'single|double|sub|back\slash|ü|' ]
}

@test "failed sudo auth leaves entry pending" {
  echo 'echo x' | "$SI" add T
  export SI_TEST_SUDO_FAIL=1
  run bash -c "echo y | '$SI' run 1"
  [ "$status" -eq 6 ]
  [[ "$output" == *"sudo authentication failed. Entry #1 stays pending."* ]]
  [ "$(cat "$ENTRIES/1/status")" = pending ]
}

@test "done entry cannot run again" {
  echo true | "$SI" add T
  echo y | "$SI" run 1
  run bash -c "echo y | '$SI' run 1"
  [ "$status" -eq 5 ]
  [[ "$output" == *"entry #1 is done"* ]]
}

@test "reject stores reason" {
  echo true | "$SI" add T
  run "$SI" reject 1 "too broad"
  [ "$output" = "Entry #1 rejected." ]
  [ "$(cat "$ENTRIES/1/status")" = rejected ]
  [ "$(cat "$ENTRIES/1/reject_reason")" = "too broad" ]
}

@test "reject only works on pending entries" {
  echo true | "$SI" add T
  "$SI" reject 1
  run "$SI" reject 1
  [ "$status" -eq 5 ]
}

@test "root output is sanitized on screen but kept raw for the agent" {
  printf 'printf "\\033[2Jfake\\n"\n' | "$SI" add T
  run bash -c "echo y | '$SI' run 1"
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == *'^[[2Jfake'* ]]
  grep -q $'\033' "$ENTRIES/1/output"
}

@test "script runs in the directory it was queued from" {
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  (cd "$BATS_TEST_TMPDIR/proj" && echo pwd | "$SI" add T)
  cd "$BATS_TEST_TMPDIR"
  echo y | "$SI" run 1 >/dev/null
  [ "$(cat "$ENTRIES/1/output")" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "root log line stays one line for a title with newlines" {
  echo true | "$SI" add $'T\n2026-01-01T00:00:00Z user=root entry=99 fake'
  echo y | "$SI" run 1 >/dev/null
  [ "$(wc -l <"$SI_TEST_ROOT_LOG")" -eq 1 ]
}

@test "hangup during run marks entry interrupted" {
  echo 'sleep 30' | "$SI" add T
  setsid bash -c "echo y | '$SI' run 1 >/dev/null 2>&1" &
  pid=$!
  for _ in $(seq 50); do [ "$(cat "$ENTRIES/1/status")" = running ] && break; sleep 0.1; done
  [ "$(cat "$ENTRIES/1/status")" = running ]
  kill -HUP -- "-$pid"
  for _ in $(seq 50); do [ "$(cat "$ENTRIES/1/status")" = interrupted ] && break; sleep 0.1; done
  [ "$(cat "$ENTRIES/1/status")" = interrupted ]
  [ "$(tail -1 "$SI_TEST_SUDO_CALLS")" = "-k" ]
  [ -z "$(ls -A "$XDG_STATE_HOME/sudo-inbox" | grep '^\.run\.' || true)" ]
  run bash -c "echo y | '$SI' run 1"
  [ "$status" -eq 5 ]
  [[ "$output" == *"interrupted"* ]]
  run "$SI" result 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"status: interrupted"* ]]
}

@test "root call never creates a cached sudo login" {
  echo true | "$SI" add T
  echo y | "$SI" run 1 >/dev/null
  grep -q -- '^-k -- bash -c' "$SI_TEST_SUDO_CALLS"
}

@test "review shows the age and warns about old entries" {
  echo true | "$SI" add T
  printf '2026-01-01T00:00:00Z' >"$ENTRIES/1/created"
  run "$SI" show 1
  [[ "$output" == *"! queued more than 24 hours ago"* ]]
}

@test "long script renders quickly" {
  seq 3000 | sed 's/^/echo line /' | "$SI" add T
  start=$(date +%s)
  "$SI" show 1 >/dev/null
  [ $(( $(date +%s) - start )) -lt 5 ]
}

@test "long output is shown quickly" {
  echo 'seq 5000' | "$SI" add T
  start=$(date +%s)
  echo y | "$SI" run 1 >/dev/null
  [ $(( $(date +%s) - start )) -lt 5 ]
}

@test "reject on a non-pending entry prints status safely" {
  echo true | "$SI" add T
  printf 'done\033[2J' >"$ENTRIES/1/status"
  run "$SI" reject 1
  [ "$status" -eq 5 ]
  [[ "$output" != *$'\033'* ]]
}
