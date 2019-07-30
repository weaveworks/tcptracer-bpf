#!/bin/bash

# Script to smoke test tcptracer-bpf
#
# `semaphore.sh` runs the test (`tests/run`) in a rkt container with
# custom build stage1-kvm images to test under different kernels.
# stage1-kvm allows us to run a container inside a KVM virtual machine
# and thus test eBPF workloads, which need a modern Linux kernel and
# root access.
#
# `tests/run` starts a tracer (see `tests/tracer.go`) and verifies the
# tracer sees all events for a single TCP connection (client connect,
# server accept, client close, server close) with the expected addr:port
# combinations.

set -eux
set -o pipefail

# Currently we test on Linux version
# 4.4 - the longterm release used in Amazon Linux
# 4.9 - the latest stable release
readonly kernel_versions=("4.4.129" "4.9.96")
readonly rkt_version="1.30.0"

if [[ ! -f "./rkt/rkt" ]] \
    || [[ ! "$(./rkt/rkt version | awk '/rkt Version/{print $3}')" == "${rkt_version}" ]]; then

    curl -LsS "https://github.com/coreos/rkt/releases/download/v${rkt_version}/rkt-v${rkt_version}.tar.gz" \
        -o rkt.tgz

    mkdir -p rkt
    tar -xvf rkt.tgz -C rkt --strip-components=1
fi

# Pre-fetch stage1 dependency due to rkt#2241
# https://github.com/coreos/rkt/issues/2241
sudo ./rkt/rkt image fetch --insecure-options=image "coreos.com/rkt/stage1-kvm:${rkt_version}"

sudo docker build -t "weaveworks/tcptracer-bpf-ci" -f "./tests/Dockerfile" .
# shellcheck disable=SC2024
sudo docker save "weaveworks/tcptracer-bpf-ci" >"tcptracer-bpf-ci.tar"
docker2aci "./tcptracer-bpf-ci.tar"
rm "./tcptracer-bpf-ci.tar"
trap "rm -f ./weaveworks-tcptracer-bpf-ci-latest.aci" EXIT

make

for kernel_version in "${kernel_versions[@]}"; do
    kernel_header_dir="/lib/modules/${kernel_version}-kinvolk-v1/source/include"
    # stage1 image build with https://github.com/kinvolk/stage1-builder
    stage1_name="kinvolk.io/aci/rkt/stage1-kvm:${rkt_version},kernelversion=${kernel_version}"

    rm -f ./rkt-uuid

    sudo timeout --foreground --kill-after=10 5m \
        ./rkt/rkt \
        run --interactive \
        --uuid-file-save=./rkt-uuid \
        --insecure-options=image,all-run \
        --dns=8.8.8.8 \
        --stage1-name="${stage1_name}" \
        --volume=ttbpf,kind=host,source="$PWD" \
        ./weaveworks-tcptracer-bpf-ci-latest.aci \
        --mount=volume=ttbpf,target=/go/src/github.com/weaveworks/tcptracer-bpf \
        --environment=GOPATH=/go \
        --environment=C_INCLUDE_PATH="${kernel_header_dir}/arch/x86/include:${kernel_header_dir}/arch/x86/include/generated" \
        --exec=/bin/bash -- -o xtrace -c \
        'cd /go/src/github.com/weaveworks/tcptracer-bpf/tests &&
        mount -t tmpfs tmpfs /tmp &&
        mount -t debugfs debugfs /sys/kernel/debug/ &&
        make &&
        ./run'

    # Determine exit code from pod status due to
    # https://github.com/coreos/rkt/issues/2777
    test_status=$(sudo ./rkt/rkt status "$(<rkt-uuid)" | awk '/app-/{split($0,a,"=")} END{print a[2]}')
    if [[ $test_status -ne 0 ]]; then
        exit "$test_status"
    fi

    sudo ./rkt/rkt gc --grace-period=0
done
