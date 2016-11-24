package main

import (
	"fmt"
	"os"
	"os/signal"

	"github.com/weaveworks/tcptracer-bpf/pkg/tracer"
)

var lastTimestampV4 uint64
var lastTimestampV6 uint64

func tcpEventCbV4(e tracer.TcpV4) {
	fmt.Printf("%v cpu#%d %s %v %s %v:%v %v:%v %v\n",
		e.Timestamp, e.CPU, e.Type, e.Pid, e.Comm, e.SAddr, e.SPort, e.DAddr, e.DPort, e.NetNS)

	if lastTimestampV4 > e.Timestamp {
		fmt.Printf("ERROR: late event!\n")
		os.Exit(1)
	}

	lastTimestampV4 = e.Timestamp
}

func tcpEventCbV6(e tracer.TcpV6) {
	fmt.Printf("%v cpu#%d %s %v %s %v:%v %v:%v %v\n",
		e.Timestamp, e.CPU, e.Type, e.Pid, e.Comm, e.SAddr, e.SPort, e.DAddr, e.DPort, e.NetNS)

	if lastTimestampV6 > e.Timestamp {
		fmt.Printf("ERROR: late event!\n")
		os.Exit(1)
	}

	lastTimestampV6 = e.Timestamp
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s .../tcptracer-ebpf.o\n", os.Args[0])
		os.Exit(1)
	}
	fileName := os.Args[1]

	t, err := tracer.NewTracerFromFile(fileName, tcpEventCbV4, tcpEventCbV6)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, os.Kill)

	<-sig
	t.Stop()
}
