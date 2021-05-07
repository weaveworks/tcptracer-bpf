package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"

	// Modified: to use fork
	"github.com/walker-cameron/tcptracer-bpf/pkg/tracer"
)

const (
	OK = iota
	BAD_ARGUMENTS
	TRACER_INSERT_FAILED
	PROCESS_NOT_FOUND
	TCP_EVENT_LATE
	TCP_EVENTS_LOST
)

type tcpEventTracer struct {
	// Modified: don't exit on late events
	// lastTimestampV4 uint64
	// lastTimestampV6 uint64
}

// Modified: output formats to remove timestamp, cpu, and netns
func (t *tcpEventTracer) TCPEventV4(e tracer.TcpV4) {
	if e.Type == tracer.EventFdInstall {
		fmt.Printf("%s %v %s %v\n",
			e.Type, e.Pid, e.Comm, e.Fd)
	} else {
		fmt.Printf("%s %d %v %s %v:%v %v:%v\n",
			e.Type, 4, e.Pid, e.Comm, e.SAddr, e.SPort, e.DAddr, e.DPort)
	}

	// Modified: don't exit on late events
	// if t.lastTimestampV4 > e.Timestamp {
	// 	fmt.Printf("ERROR: late event!\n")
	// 	os.Exit(TCP_EVENT_LATE)
	// }

	// t.lastTimestampV4 = e.Timestamp
}

// Modified: output format to remove timestamp, cpu, and netns
func (t *tcpEventTracer) TCPEventV6(e tracer.TcpV6) {
	fmt.Printf("%s %d %v %s %v:%v %v:%v\n",
		e.Type, 6, e.Pid, e.Comm, e.SAddr, e.SPort, e.DAddr, e.DPort)

	// Modified: don't exit on late events
	// if t.lastTimestampV6 > e.Timestamp {
	// 	fmt.Printf("ERROR: late event!\n")
	// 	os.Exit(TCP_EVENT_LATE)
	// }

	// t.lastTimestampV6 = e.Timestamp
}

func (t *tcpEventTracer) LostV4(count uint64) {
	fmt.Printf("ERROR: lost %d events!\n", count)
	os.Exit(TCP_EVENTS_LOST)
}

func (t *tcpEventTracer) LostV6(count uint64) {
	fmt.Printf("ERROR: lost %d events!\n", count)
	os.Exit(TCP_EVENTS_LOST)
}

func init() {
	// Modified: Removed monitor-fdinstall-pids option
	// flag.StringVar(&watchFdInstallPids, "monitor-fdinstall-pids", "", "a comma-separated list of pids that need to be monitored for fdinstall events")

	flag.Parse()
}

func main() {
	if flag.NArg() > 1 {
		flag.Usage()
		os.Exit(BAD_ARGUMENTS)
	}

	t, err := tracer.NewTracer(&tcpEventTracer{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(TRACER_INSERT_FAILED)
	}

	t.Start()

	// Modified: Removed fdinstall probes, so removing the watchFdInstallPids option
	// for _, p := range strings.Split(watchFdInstallPids, ",") {
	// 	if p == "" {
	// 		continue
	// 	}

	// 	pid, err := strconv.ParseUint(p, 10, 32)
	// 	if err != nil {
	// 		fmt.Fprintf(os.Stderr, "Invalid pid: %v\n", err)
	// 		os.Exit(PROCESS_NOT_FOUND)
	// 	}
	// 	fmt.Printf("Monitor fdinstall events for pid %d\n", pid)
	// 	t.AddFdInstallWatcher(uint32(pid))
	// }

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, os.Kill)

	<-sig
	t.Stop()
}
