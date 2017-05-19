#!/bin/bash

set -eu

if [[ $EUID -ne 0 ]]; then
    echo "root required - aborting" >&2
    exit 1
fi

readonly dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly tracer="${dir}/tracer"
readonly port=61111
readonly port2=61112
readonly netns=$(mktemp /tmp/tcptracer-bpf-test-netns-XXXXXXXX)
readonly tracer_output=$(mktemp /tmp/tcptracer-bpf-test-stdout-XXXXXXXX)
exec 3<> <(tail --pid "$$" -f "${tracer_output}")
server_pid=-1
server2_pid=-1
tracer_pid=-1

function shutdown() {
    if [[ $server_pid -ne -1 ]]; then
        kill $server_pid 2>/dev/null || true
    fi
    if [[ $server2_pid -ne -1 ]]; then
        kill $server2_pid 2>/dev/null || true
    fi
    if [[ $tracer_pid -ne -1 ]]; then
        kill $tracer_pid 2>/dev/null || true
    fi
    exec 3>&-
    rm "${tracer_output}"
    umount -f "${netns}"
    rm "${netns}"
}

trap shutdown EXIT

uname -r

unshare --net="${netns}" ip link set lo up

# start a process in the accept syscall to test
# https://github.com/weaveworks/tcptracer-bpf/issues/10
nsenter --net="${netns}" busybox nc -l -p "${port2}" </dev/null &
server2_pid=$!

sleep 1 # wait for server2 to load

nsenter --net="${netns}" "${tracer}" "--monitor-fdinstall-pids=${server2_pid}" >&3 &
tracer_pid=$!

sleep 1 # wait for tracer to load

# stop and fail here when tracer encountered an error and didn't start
ps -p "$tracer_pid" >/dev/null

# generate some refused connections to test for
# https://github.com/weaveworks/tcptracer-bpf/issues/21
nsenter --net="${netns}" ./multiple_connections_refused.sh "1200"

nsenter --net="${netns}" nc -l "${port}" </dev/null &
server_pid=$!
nsenter --net="${netns}" nc 127.0.0.1 "${port}" &

# generate fdinstall+connect event
nsenter --net="${netns}" nc 127.0.0.1 "${port2}" &

lines_found=0
lines_read=0
readonly lines_expected=8
while [[ $lines_read -lt $lines_expected ]]; do
    read -r -u 3 line
    # 48704147610580 cpu#1 connect 2074 nc 127.0.0.1:52414 127.0.0.1:61111 4026532567
    if [[ "$line" =~ ^[0-9]+\ cpu#[0-9]\ ([a-z]+)\ ([0-9]+)\ [a-z]+\ (127.0.0.1\:[0-9]+)\ (127.0.0.1\:[0-9]+)\ [0-9]+$ ]]; then
        action=${BASH_REMATCH[1]}
        pid=${BASH_REMATCH[2]}
        saddr=${BASH_REMATCH[3]}
        daddr=${BASH_REMATCH[4]}
        lines_read=$((lines_read + 1))
        printf "action: %s pid: %s saddr: %s daddr: %s\n" "${action}" "${pid}" "${saddr}" "${daddr}"
        if [[ "${action}" == "connect" && "$daddr" == "127.0.0.1:${port}" ]] ||
            [[ "${action}" == "connect" && "$daddr" == "127.0.0.1:${port2}" ]] ||
            [[ "${action}" == "accept" && "$saddr" == "127.0.0.1:${port}" ]] ||
            [[ "${action}" == "close" && "$daddr" == "127.0.0.1:${port}" ]] ||
            [[ "${action}" == "close" && "$daddr" == "127.0.0.1:${port2}" ]] ||
            [[ "${action}" == "close" && "$saddr" == "127.0.0.1:${port}" ]] ||
            [[ "${action}" == "close" && "$saddr" == "127.0.0.1:${port2}" ]]; then
            lines_found=$((lines_found + 1))
        else
            echo "^^^ unexpected values in event"
        fi
    elif [[ "$line" =~ ^[0-9]+\ cpu#[0-9]\ ([a-z]+)\ ([0-9]+)\ [a-z]+\ ([0-9]+)$ ]]; then
        action=${BASH_REMATCH[1]}
        pid=${BASH_REMATCH[2]}
        fd=${BASH_REMATCH[3]}
        lines_read=$((lines_read + 1))
        printf "action: %s pid: %s fd: %s\n" "${action}" "${pid}" "${fd}"
        if [[ "${action}" == "fdinstall" && "$fd" -gt "2" ]]; then
            lines_found=$((lines_found + 1))
        else
            echo "^^^ unexpected values in event"
        fi
    fi
done

if [[ $lines_found -eq $lines_expected ]]; then
    echo "success"
    exit 0
else
    echo "failure"
    exit 1
fi
