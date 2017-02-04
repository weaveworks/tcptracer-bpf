DEBUG=1
UID=$(shell id -u)
PWD=$(shell pwd)

DOCKER_FILE?=Dockerfile
DOCKER_IMAGE?=weaveworks/tcptracer-bpf-builder

# If you can use docker without being root, you can do "make SUDO="
SUDO=$(shell docker info >/dev/null 2>&1 || echo "sudo -E")

all: build-docker-image build-ebpf-object

build-docker-image:
	$(SUDO) docker build -t $(DOCKER_IMAGE) -f $(DOCKER_FILE) .

build-ebpf-object:
	$(SUDO) docker run --rm -e DEBUG=$(DEBUG) \
		-e CIRCLE_BUILD_URL=$(CIRCLE_BUILD_URL) \
		-v $(PWD):/src:ro \
		-v $(PWD)/ebpf:/dist/ \
		--workdir=/src \
		$(DOCKER_IMAGE) \
		make -f ebpf.mk build
	sudo chown -R $(UID):$(UID) ebpf

delete-docker-image:
	$(SUDO) docker rmi -f $(DOCKER_IMAGE)
