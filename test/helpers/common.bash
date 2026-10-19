# Shared bats setup for sudo-inbox tests.
setup() {
  SI="$BATS_TEST_DIRNAME/../sudo-inbox"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
  export PATH="$BATS_TEST_DIRNAME/helpers/bin:$PATH"
  export SI_TEST_SUDO_CALLS="$BATS_TEST_TMPDIR/sudo-calls"
  export SI_TEST_ROOT_LOG="$BATS_TEST_TMPDIR/root.log"
  unset SUDO_INBOX_NOTIFY SI_TEST_SUDO_FAIL SI_TEST_SUDO_BEFORE SI_TEST_PASSWORDLESS
  ENTRIES="$XDG_STATE_HOME/sudo-inbox/entries"
}
