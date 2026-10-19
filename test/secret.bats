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

@test "root-owned directory goes through sudo without the value in argv" {
  [ -d /srv/root-env ] && [ ! -w /srv/root-env ] || skip "needs root-owned /srv/root-env"
  printf 'topsecret\ntopsecret\n' | "$SI" secret K --env /srv/root-env/.env || true
  grep -q -- '-- bash -c' "$SI_TEST_SUDO_CALLS"
  ! grep -q topsecret "$SI_TEST_SUDO_CALLS"
}

@test "read-only file in your own directory never uses sudo" {
  d="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$d"
  printf 'A=1\n' >"$d/.env"
  chmod 444 "$d/.env"
  "$SI" add-secret K --env "$d/.env"
  printf 'y\nval\nval\n' | "$SI" run 1
  no_root_call
  grep -qx 'K=val' "$d/.env"
  [ ! -L "$d/.env" ]
}

@test "file swapped for a symlink before the write is refused" {
  d="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$d"
  : >"$d/.env"
  "$SI" add-secret K --env "$d/.env"
  # The swap happens while the user types the value.
  run bash -c "{ printf 'y\n'; sleep 1; rm '$d/.env'; ln -s /etc/hostname '$d/.env'; printf 'v\nv\n'; } | '$SI' run 1"
  [ "$status" -ne 0 ]
  [ -L "$d/.env" ]
  [ "$(cat "$ENTRIES/1/status")" = pending ]
}

@test "writable parent above a protected directory is refused" {
  d="$BATS_TEST_TMPDIR/ro"
  mkdir -p "$d"
  : >"$d/.env"
  chmod 400 "$d/.env"
  chmod 500 "$d"
  run bash -c "printf 'x\nx\n' | '$SI' secret K --env '$d/.env'"
  chmod 700 "$d"
  [ "$status" -eq 5 ]
  [[ "$output" == *"writable by you"* ]]
  no_root_call
}

@test "other owner in your own directory is refused and leaves no temp file" {
  d="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$d"
  run bash -c "printf 'abcdefgh\nabcdefgh\n' | '$SI' secret K --env '$d/.env' --owner root:root"
  [ "$status" -eq 5 ]
  [ -z "$(ls -A "$d")" ]
}

@test "invalid owner is refused at add-secret" {
  run "$SI" add-secret K --env "$BATS_TEST_TMPDIR/.env" --owner $'me\033[2J'
  [ "$status" -eq 2 ]
}

@test "tampered secret fields are validated before writing" {
  d="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$d"
  printf 'A=1\n' >"$d/.env"
  "$SI" add-secret K --env "$d/.env"
  printf '.*' >"$ENTRIES/1/name"
  run bash -c "printf 'y\nv\nv\n' | '$SI' run 1"
  [ "$status" -ne 0 ]
  grep -qx 'A=1' "$d/.env"
  "$SI" add-secret L --env "$d/.env"
  printf '644; rm -rf /' >"$ENTRIES/2/mode"
  run bash -c "printf 'y\nv\nv\n' | '$SI' run 2"
  [ "$status" -ne 0 ]
}

@test "export KEY lines are replaced too" {
  f="$BATS_TEST_TMPDIR/.env"
  printf 'export K=old\nB=2\n' >"$f"
  printf 'new\nnew\n' | "$SI" secret K --env "$f"
  [ "$(grep -c 'K=' "$f")" -eq 1 ]
  grep -qx 'K=new' "$f"
}

@test "unreadable .env is never overwritten" {
  d="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$d"
  printf 'OTHER=keep\n' >"$d/.env"
  chmod 000 "$d/.env"
  run bash -c "printf 'v\nv\n' | '$SI' secret K --env '$d/.env'"
  chmod 600 "$d/.env"
  [ "$status" -ne 0 ]
  grep -qx 'OTHER=keep' "$d/.env"
}
