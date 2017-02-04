// +build !linux

package tracer

import (
	"fmt"
)

type Tracer struct{}

func NewTracerFromFile(fileName string, tcpEventCbV4 func(TcpV4), tcpEventCbV6 func(TcpV6)) (*Tracer, error) {
	return nil, fmt.Errorf("not supported on non-Linux systems")
}

func (t *Tracer) Stop() {
}
