#!/bin/bash

set -eu

if [[ $EUID -ne 0 ]]; then
    echo "root required - aborting" >&2
    exit 1
fi

test_pid=-1

function shutdown() {
    if [[ $test_pid -ne -1 ]]; then
        kill $test_pid 2>/dev/null || true
    fi
}

trap shutdown EXIT

timeout 150 ./test.sh &
test_pid=$!
wait $test_pid

exit $?
