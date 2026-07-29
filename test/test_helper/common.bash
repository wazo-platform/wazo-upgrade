# Resolved from this file's own location (not BATS_TEST_DIRNAME, which is the
# *calling* test file's directory and varies with how deeply it's nested
# under test/, e.g. test/pre-start.d/*.bats).
COMMON_BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_BASH_DIR}/../.." && pwd)"

source "${COMMON_BASH_DIR}/bats-support/load.bash"
source "${COMMON_BASH_DIR}/bats-assert/load.bash"

# Creates an empty stub directory and prepends it to PATH. Call once per
# test in `setup()`, paired with `stub_path_teardown` in `teardown()`.
#
# Uses mktemp rather than BATS_TEST_TMPDIR: this repo's bats (1.2.1) predates
# that variable.
stub_path_setup() {
    # Exported: hand-written stub scripts (using a quoted heredoc, so
    # $STUB_DIR is resolved at run time rather than substituted verbatim)
    # need to see it too, and they run as separate child processes.
    export STUB_DIR="$(mktemp -d "${BATS_TMPDIR:-${TMPDIR:-/tmp}}/wazo-upgrade-bats-XXXXXX")"
    PATH="${STUB_DIR}:${PATH}"
}

stub_path_teardown() {
    [ -n "$STUB_DIR" ] && rm -rf "$STUB_DIR"
}

# stub <command> <exit_status> [output]
#
# Writes an executable named <command> into STUB_DIR that prints [output]
# (if given) to stdout, appends the invocation (command + args) to
# "${STUB_DIR}/<command>.calls", and returns <exit_status>.
stub() {
    local name=$1 status=$2 output=$3
    local stub_file="${STUB_DIR}/${name}"

    cat > "$stub_file" <<EOF
#!/bin/bash
echo "\$0 \$*" >> "${STUB_DIR}/${name}.calls"
$( [ -n "$output" ] && printf 'cat <<'"'"'STUB_OUTPUT_EOF'"'"'\n%s\nSTUB_OUTPUT_EOF\n' "$output" )
exit ${status}
EOF
    chmod +x "$stub_file"
}

# stub_call_count <command>
stub_call_count() {
    local calls_file="${STUB_DIR}/${1}.calls"
    [ -f "$calls_file" ] && wc -l < "$calls_file" || echo 0
}
