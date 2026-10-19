#!/usr/bin/env bats
load helpers/common

@test "result of done entry with failing script exits 1" {
  echo 'echo out; exit 3' | "$SI" add T
  echo y | "$SI" run 1 >/dev/null
  run "$SI" result 1
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "status: done" ]
  [ "${lines[1]}" = "exit_code: 3" ]
  [ "${lines[2]}" = "--- output ---" ]
  [ "${lines[3]}" = out ]
}

@test "result of successful entry exits 0" {
  echo 'echo fine' | "$SI" add T
  echo y | "$SI" run 1 >/dev/null
  run "$SI" result 1
  [ "$status" -eq 0 ]
}

@test "result of pending entry" {
  echo true | "$SI" add T
  run "$SI" result 1
  [ "$status" -eq 0 ]
  [ "$output" = "status: pending" ]
}

@test "result of rejected entry exits 3" {
  echo true | "$SI" add T
  "$SI" reject 1 nope
  run "$SI" result 1
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "status: rejected" ]
  [ "${lines[1]}" = "reason: nope" ]
}

@test "wait returns once the entry is done" {
  echo 'echo ok' | "$SI" add T
  (sleep 3; echo y | "$SI" run 1 >/dev/null) &
  run "$SI" wait 1 --timeout 30s
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]]
}

@test "wait times out with exit 4" {
  echo true | "$SI" add T
  run "$SI" wait 1 --timeout 3s
  [ "$status" -eq 4 ]
  [[ "$output" == *"status: pending (timed out after 3s)"* ]]
}

@test "bad timeout is a usage error" {
  echo true | "$SI" add T
  run "$SI" wait 1 --timeout soon
  [ "$status" -eq 2 ]
}
