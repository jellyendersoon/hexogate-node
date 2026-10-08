FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
# Xray core source: point XRAY_REPO at your own Xray fork to ship the Hexogate core.
ARG XRAY_REPO=XTLS/Xray-core
ARG XRAY_VERSION=latest
# Or a direct zip/binary URL, optionally pinned by sha256 of the xray binary.
ARG XRAY_URL=""
ARG XRAY_SHA256=""

RUN apk update && apk add --no-cache make

WORKDIR /src

COPY go* .
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make NAME=main build
RUN XRAY_REPO=${XRAY_REPO} XRAY_VERSION=${XRAY_VERSION} XRAY_URL=${XRAY_URL} XRAY_SHA256=${XRAY_SHA256} GOOS=${TARGETOS} GOARCH=${TARGETARCH} make install_xray

FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/jellyendersoon/hexogate-node"

RUN apk update && apk add --no-cache wireguard-tools nftables iproute2 procps

WORKDIR /app
COPY --from=builder /src/main /app/main
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY --from=builder /usr/local/share/xray /usr/local/share/xray

ENTRYPOINT ["./main"]
