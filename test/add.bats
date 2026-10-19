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
