FROM fedora:25

ENV GOPATH /go

# vim-common is needed for xxd
# vim-minimal needs to be updated first to avoid an RPM conflict on man1/vim.1.gz
RUN dnf update -y vim-minimal && \
	dnf install -y llvm clang kernel-devel make binutils vim-common golang go-bindata ShellCheck git file

RUN go get -u github.com/mvdan/sh/cmd/shfmt
RUN go get -u github.com/fatih/hclfmt

RUN mkdir -p /src /go
