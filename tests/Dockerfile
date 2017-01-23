FROM fedora:25

RUN dnf install -y iproute make nmap-ncat procps-ng golang

RUN mkdir -p /go

ENV GOPATH /go
CMD ["bash"]
