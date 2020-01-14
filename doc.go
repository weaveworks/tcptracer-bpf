// There is no Go code in this directory, but we need the generated .c
// and .h files when the library is re-used, so this file exists to
// get `go mod` to copy those files.
// +build never

package tcptracer_bpf

import "C"
