#!/usr/bin/env bats
load helpers/common

@test "add from stdin creates entry 1" {
  run bash -c "printf 'echo hi\n' | '$SI' add 'Say hi' --reason 'test'"
  [ "$status" -eq 0 ]
  [ "$output" = "Entry #1 is waiting. Ask the user to run: sudo-inbox run 1" ]
  [ "$(cat "$ENTRIES/1/status")" = pending ]
  [ "$(cat "$ENTRIES/1/type")" = script ]
  [ "$(cat "$ENTRIES/1/reason")" = test ]
}

@test "add -f reads file byte-exact" {
  printf 'a\nb' >"$BATS_TEST_TMPDIR/s"
  "$SI" add T -f "$BATS_TEST_TMPDIR/s"
  cmp "$BATS_TEST_TMPDIR/s" "$ENTRIES/1/script"
}

@test "empty script is refused" {
  run bash -c "printf '' | '$SI' add T"
  [ "$status" -eq 5 ]
}

@test "empty title is a usage error" {
  run bash -c "echo true | '$SI' add ''"
  [ "$status" -eq 2 ]
}

@test "script over 256 KiB is refused" {
  head -c 262145 /dev/zero | tr '\0' a >"$BATS_TEST_TMPDIR/big"
  run "$SI" add T -f "$BATS_TEST_TMPDIR/big"
  [ "$status" -eq 5 ]
}

@test "20 parallel adds get 20 distinct numbers" {
  for i in $(seq 20); do
    (echo "echo $i" | "$SI" add "t$i" >/dev/null) &
  done
  wait
  [ "$(ls "$ENTRIES" | wc -l)" -eq 20 ]
  for i in $(seq 20); do [ -f "$ENTRIES/$i/script" ]; done
}

@test "show renders control characters visibly" {
  printf 'echo \033[2Khidden\n' | "$SI" add $'evil\033[1A'
  run "$SI" show 1
  [[ "$output" == *'evil^[[1A'* ]]
  [[ "$output" == *'echo ^[[2Khidden'* ]]
  [[ "$output" != *$'\033'* ]]
}

@test "show flags risky lines" {
  printf 'apt update\nsystemctl restart nginx\n' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"! line 2: changes a service"* ]]
}

@test "show says when nothing is risky" {
  echo 'echo hi' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"no risky patterns found"* ]]
}

@test "show warns on long scripts" {
  seq 61 | sed 's/^/echo /' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"long script (61 lines)"* ]]
}

@test "show unknown entry exits 5" {
  run "$SI" show 9
  [ "$status" -eq 5 ]
}

@test "show bad number exits 2" {
  run "$SI" show ../1
  [ "$status" -eq 2 ]
}

@test "list shows newest first" {
  echo a | "$SI" add first
  echo b | "$SI" add second
  run "$SI" list
  [ "${lines[0]}" = "#2  pending  second" ]
  [ "${lines[1]}" = "#1  pending  first" ]
}

@test "list on empty inbox" {
  run "$SI" list
  [ "$output" = "Inbox is empty." ]
}

@test "header fields from disk are sanitized (status, type, created)" {
  echo true | "$SI" add T
  printf 'pending\033[1;2r' >"$ENTRIES/1/status"
  printf 'script\033[2J' >"$ENTRIES/1/type"
  printf '2026\033[H' >"$ENTRIES/1/created"
  run "$SI" show 1
  [[ "$output" != *$'\033'* ]]
  run "$SI" list
  [[ "$output" != *$'\033'* ]]
}

@test "newlines and tabs in title and reason are shown visibly" {
  echo true | "$SI" add $'line1\nChecks by sudo-inbox:' --reason $'a\tb'
  run "$SI" show 1
  [[ "$output" == *'line1^JChecks by sudo-inbox:'* ]]
  [[ "$output" == *'a^Ib'* ]]
}

@test "C1 control characters are shown visibly" {
  printf 'echo \xc2\x9b2J\n' | "$SI" add $'t\xc2\x9b2J'
  run "$SI" show 1
  [[ "$output" != *$'\xc2\x9b'* ]]
  [[ "$output" == *'t<U+009B>2J'* ]]
  [[ "$output" == *'echo <U+009B>2J'* ]]
}

@test "bidi overrides are shown visibly and flagged" {
  printf 'echo ok \xe2\x80\xae# hidden\n' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *'<U+202E>'* ]]
  [[ "$output" == *"! line 1: hidden text direction (bidi)"* ]]
}

@test "relative and home paths are flagged" {
  printf 'bash ./install.sh\ncp ~/x /opt/x\n' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"! line 1: uses a file the agent can change"* ]]
  [[ "$output" == *"! line 2: uses a file the agent can change"* ]]
}

@test "show displays the directory the script runs in" {
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  cd "$BATS_TEST_TMPDIR/proj"
  echo true | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"Runs in: $BATS_TEST_TMPDIR/proj"* ]]
}

@test "secret header fields are sanitized" {
  "$SI" add-secret K --env "$BATS_TEST_TMPDIR/.env"
  printf 'K\033[2J' >"$ENTRIES/1/name"
  printf '600\033[H' >"$ENTRIES/1/mode"
  printf 'me\033[1;2r' >"$ENTRIES/1/owner"
  run "$SI" show 1
  [[ "$output" != *$'\033'* ]]
}

@test "script over 120 KiB is refused" {
  head -c 130000 /dev/zero | tr '\0' a >"$BATS_TEST_TMPDIR/big"
  run "$SI" add T -f "$BATS_TEST_TMPDIR/big"
  [ "$status" -eq 5 ]
  [[ "$output" == *"max 120 KiB"* ]]
}

@test "invisible and non-ASCII characters are flagged" {
  printf 'echo a\xe2\x80\x8bb\n' | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"! line 1: non-ASCII characters"* ]]
}

@test "very long lines are flagged" {
  printf 'echo %0250d\n' 0 | "$SI" add T
  run "$SI" show 1
  [[ "$output" == *"! line 1: very long line"* ]]
}

@test "title and reason are capped" {
  long="$(printf '%0201d' 0)"
  run bash -c "echo true | '$SI' add '$long'"
  [ "$status" -eq 2 ]
  run bash -c "echo true | '$SI' add T --reason \"\$(printf '%02049d' 0)\""
  [ "$status" -eq 2 ]
}

@test "list truncates before sanitizing" {
  echo true | "$SI" add "$(printf 'x%.0s' $(seq 38))$(printf '\xc2\x9b')yz"
  run "$SI" list
  [[ "$output" == *'<U+009B>'* ]]
}
