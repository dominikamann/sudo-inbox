#!/usr/bin/env bats
load helpers/common

@test "secret writes new key with mode 600" {
  f="$BATS_TEST_TMPDIR/app.env"
  run bash -c "printf 'abc\nabc\n' | '$SI' secret API_KEY --env '$f'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"API_KEY set in $f (length 3)."* ]]
  [ "$(cat "$f")" = "API_KEY=abc" ]
  [ "$(stat -c %a "$f")" = 600 ]
}

@test "secret replaces existing key instead of appending" {
  f="$BATS_TEST_TMPDIR/.env"
  printf 'A=1\nAPI_KEY=old\nB=2\n' >"$f"
  printf 'new\nnew\n' | "$SI" secret API_KEY --env "$f"
  [ "$(grep -c '^API_KEY=' "$f")" -eq 1 ]
  grep -qx 'API_KEY=new' "$f"
  grep -qx 'A=1' "$f"
  grep -qx 'B=2' "$f"
}

@test "file without trailing newline keeps its last line" {
  f="$BATS_TEST_TMPDIR/.env"
  printf 'A=1' >"$f"
  printf 'x\nx\n' | "$SI" secret K --env "$f"
  grep -qx 'A=1' "$f"
  grep -qx 'K=x' "$f"
}

@test "special characters are single-quoted" {
  f="$BATS_TEST_TMPDIR/.env"
  printf 'a b$#"\na b$#"\n' | "$SI" secret K --env "$f"
  grep -qx "K='a b\$#\"'" "$f"
}

@test "single quote in value is refused" {
  run bash -c "printf \"a'b\na'b\n\" | '$SI' secret K --env '$BATS_TEST_TMPDIR/.env'"
  [ "$status" -eq 5 ]
  [[ "$output" == *"single quotes are not supported"* ]]
}

@test "mismatch is refused" {
  run bash -c "printf 'a\nb\n' | '$SI' secret K --env '$BATS_TEST_TMPDIR/.env'"
  [ "$status" -eq 5 ]
  [[ "$output" == *"Values do not match."* ]]
}

@test "length limits" {
  run bash -c "printf 'abc\nabc\n' | '$SI' secret K --env '$BATS_TEST_TMPDIR/.env' --min 20"
  [ "$status" -eq 5 ]
}

@test "bad name is a usage error" {
  run "$SI" add-secret lower --env "$BATS_TEST_TMPDIR/.env"
  [ "$status" -eq 2 ]
}

@test "non-env path is refused" {
  run "$SI" add-secret K --env /etc/sudoers
  [ "$status" -eq 5 ]
  [[ "$output" == *refused* ]]
}

@test "symlink path is refused" {
  ln -s /etc/hosts "$BATS_TEST_TMPDIR/x.env"
  run "$SI" add-secret K --env "$BATS_TEST_TMPDIR/x.env"
  [ "$status" -eq 5 ]
}

@test "missing parent directory is refused" {
  run "$SI" add-secret K --env "$BATS_TEST_TMPDIR/nope/.env"
  [ "$status" -eq 5 ]
}

@test "agent flow: add-secret, run, result shows only length" {
  f="$BATS_TEST_TMPDIR/.env"
  run "$SI" add-secret LUISA_MAIL_PASSWORD --env "$f" --min 20 --max 20
  [ "$output" = "Entry #1 is waiting. Ask the user to run: sudo-inbox run 1" ]
  run "$SI" show 1
  [[ "$output" == *"Set secret LUISA_MAIL_PASSWORD"* ]]
  [[ "$output" == *"File: $f"* ]]
  run bash -c "printf 'y\n%s\n%s\n' 12345678901234567890 12345678901234567890 | '$SI' run 1"
  [ "$status" -eq 0 ]
  run "$SI" result 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"set, length 20"* ]]
  [[ "$output" != *1234567890* ]]
  grep -qx 'LUISA_MAIL_PASSWORD=12345678901234567890' "$f"
}

@test "secret entry declined stays pending" {
  "$SI" add-secret K --env "$BATS_TEST_TMPDIR/.env"
  run bash -c "printf 'n\n' | '$SI' run 1"
  [ "$(cat "$ENTRIES/1/status")" = pending ]
}

@test "path turned into symlink before run is refused" {
  f="$BATS_TEST_TMPDIR/.env"
  "$SI" add-secret K --env "$f"
  ln -s /etc/hosts "$f"
  run bash -c "printf 'y\nx\nx\n' | '$SI' run 1"
  [ "$status" -eq 5 ]
  [ "$(cat "$ENTRIES/1/status")" = pending ]
}

@test "unwritable file goes through sudo without the value in argv" {
  d="$BATS_TEST_TMPDIR/ro"
  mkdir -p "$d"
  : >"$d/.env"
  chmod 500 "$d"
  printf 'topsecret\ntopsecret\n' | "$SI" secret K --env "$d/.env" || true
  grep -q -- '-- bash -c' "$SI_TEST_SUDO_CALLS"
  ! grep -q topsecret "$SI_TEST_SUDO_CALLS"
  chmod 700 "$d"
}
