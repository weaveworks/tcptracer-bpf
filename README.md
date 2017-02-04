# tcptracer-bpf

tcptracer-bpf is an eBPF program using kprobes to trace TCP events (connect,
accept, close). The eBPF program is compiled to an ELF object file.

tcptracer-bpf also provides a Go library that provides a simple API for loading
the ELF object file. Internally, it is using the [gobpf elf
package](https://github.com/iovisor/gobpf).

tcptracer-bpf does not have any run-time dependencies on kernel headers and is
not tied to a specific kernel version or kernel configuration. This is quite
unusual for eBPF programs using kprobes: for example, eBPF programs using
kprobes with [bcc](https://github.com/iovisor/bcc) are compiled on the fly and
depend on kernel headers. And [perf tools](https://perf.wiki.kernel.org)
compiled for one kernel version cannot be used on another kernel version.

To adapt to the currently running kernel at run-time, tcptracer-bpf creates a
series of TCP connections with known parameters (such as known IP addresses and
ports) and discovers where those parameters are stored in the [kernel struct
sock](https://github.com/torvalds/linux/blob/v4.4/include/net/sock.h#L248). The
offsets of the struct sock fields vary depending on the kernel version and
kernel configuration. Since an eBPF programs cannot loop, tcptracer-bpf does
not directly iterate over the possible offsets. It is instead controlled from
userspace by the Go library using a state machine.

See `tests/tracer.go` for an example how to use tcptracer-bpf.

## Build the elf object

```
make
```

The object file can be found in `ebpf/tcptracer-ebpf.o`.

## Test

```
cd tests
make
sudo ./run
```

## Vendoring

We use [gvt](https://github.com/FiloSottile/gvt).
