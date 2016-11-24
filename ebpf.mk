SHELL=/bin/bash -o pipefail
DEST_DIR=/dist
LINUX_HEADERS=$(shell dnf list kernel-devel | awk '/^kernel-devel\..*/{print "/usr/src/kernels/"$$2".x86_64"}')

build:
	@mkdir -p "$(DEST_DIR)"
	clang -D__KERNEL__ -D__ASM_SYSREG_H \
		-DCIRCLE_BUILD_URL=\"$(CIRCLE_BUILD_URL)\" \
		-Wno-unused-value -Wno-pointer-sign -Wno-compare-distinct-pointer-types \
		-O2 -emit-llvm -c tcptracer-bpf.c \
		$(foreach path,$(LINUX_HEADERS), -I $(path)/arch/x86/include -I $(path)/arch/x86/include/generated -I $(path)/include -I $(path)/include/generated/uapi -I $(path)/arch/x86/include/uapi -I $(path)/include/uapi) \
		-o - | llc -march=bpf -filetype=obj -o "${DEST_DIR}/tcptracer-ebpf.o"
	sha1sum ebpf/tcptracer-ebpf.o
	objdump -s --section=build_id ebpf/tcptracer-ebpf.o | grep "^ " | xxd -r | tr "\0" "\n"
