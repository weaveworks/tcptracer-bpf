.phony: all build

all: build

build:
	go build -o tracer tracer.go

build-in-docker:
	sudo docker build -t "weaveworks/tcptracer-bpf-ci" .
	sudo docker run \
		-v $(GOPATH)/src/github.com/weaveworks/tcptracer-bpf:/go/src/github.com/weaveworks/tcptracer-bpf \
		--env GOPATH=/go \
		weaveworks/tcptracer-bpf-ci \
		sh -c 'cd /go/src/github.com/weaveworks/tcptracer-bpf/tests && make'
	sudo chown $(shell id -u):$(shell id -u) ./tracer
