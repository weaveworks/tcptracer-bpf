FROM fedora:25

ENV GOPATH /go

# vim-common is needed for xxd
# vim-minimal needs to be updated first to avoid an RPM conflict on man1/vim.1.gz
RUN dnf update -y vim-minimal && \
	dnf install -y llvm clang kernel-devel make binutils vim-common golang go-bindata ShellCheck git file

RUN curl -fsSL -o shfmt https://github.com/mvdan/sh/releases/download/v1.3.0/shfmt_v1.3.0_linux_amd64 && \
    chmod +x shfmt && \
    mv shfmt /usr/bin
RUN go get -u github.com/fatih/hclfmt

RUN mkdir -p /src /go
