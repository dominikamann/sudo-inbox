#!/usr/bin/env bats
load helpers/common

@test "help lists every subcommand" {
  run "$SI" help
  [ "$status" -eq 0 ]
  for c in add add-secret list show run reject wait result secret hook install-hook; do
    [[ "$output" == *"$c"* ]]
  done
}

@test "version prints 0.2.0" {
  run "$SI" version
  [ "$output" = "sudo-inbox 0.2.0" ]
}

@test "unknown command exits 2" {
  run "$SI" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "no arguments prints help and exits 2" {
  run "$SI"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help lines fit 60 columns" {
  run "$SI" help
  while IFS= read -r l; do
    [ "${#l}" -le 60 ]
  done <<<"$output"
}
