#!/bin/bash

set -eu

if [[ $EUID -ne 0 ]]; then
    echo "root required - aborting" >&2
    exit 1
fi

readonly dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tracer="${dir}/tracer"
readonly netns=$(mktemp /tmp/tcptracer-bpf-test-netns-XXXXXXXX)
readonly tracer_output=$(mktemp /tmp/tcptracer-bpf-test-stdout-XXXXXXXX)
readonly port=8080
exec 3<> <(tail --pid "$$" -f "${tracer_output}")
tracer_pid=-1

function shutdown() {
    if [[ $tracer_pid -ne -1 ]]; then
        kill $tracer_pid 2>/dev/null || true
    fi
    exec 3>&-
    rm "${tracer_output}"
    # kill all processes in network namespace
    # via http://unix.stackexchange.com/a/213066
    find -L /proc/[1-9]*/task/*/ns/net -samefile "${netns}" \
        | cut -d/ -f5 | xargs -r kill
    umount -f "${netns}"
    rm "${netns}"
}

trap shutdown EXIT

unshare --net="${netns}" ip link set lo up
nsenter --net="${netns}" "${tracer}" >&3 &
tracer_pid=$!

sleep 1 # wait for tracer to load

# stop and fail here when tracer encountered an error and didn't start
ps -p "$tracer_pid" >/dev/null

for i in $(seq 1 25); do
    nsenter --net="${netns}" busybox nc -l -p $((8081 + i)) &
done

nsenter --net="${netns}" busybox nc -l -p "${port}" >/dev/null &
sleep 1 # wait for nc -l

echo foo | nsenter --net="${netns}" busybox nc 127.0.0.1 "${port}"

lines_found=0
while true; do
    read -t 2 -r -u 3 line || break
    if [[ "$line" =~ ^[0-9]+\ cpu#[0-9]\ ([a-z]+)\ [0-9]+\ busybox\ (127.0.0.1\:[0-9]+)\ (127.0.0.1\:[0-9]+)\ [0-9]+$ ]]; then
        action=${BASH_REMATCH[1]}
        saddr=${BASH_REMATCH[2]}
        daddr=${BASH_REMATCH[3]}
        printf "action: %s program: nc saddr: %s daddr: %s\n" "${action}" "${saddr}" "${daddr}"
        if [[ "${action}" == "connect" && "$daddr" == "127.0.0.1:${port}" ]] \
            || [[ "${action}" == "accept" && "$saddr" == "127.0.0.1:${port}" ]] \
            || [[ "${action}" == "close" && "$daddr" == "127.0.0.1:${port}" ]] \
            || [[ "${action}" == "close" && "$saddr" == "127.0.0.1:${port}" ]]; then
            lines_found=$((lines_found + 1))
        else
            echo "^^^ unexpected values in event"
        fi
    fi
done

if [[ $lines_found -eq 3 ]]; then
    echo "success"
    exit 0
else
    printf "expected 3 lines, found %d\n" "${lines_found}"
    echo "failure"
    exit 1
fi
