#!/usr/bin/env bash
# Install the Xray core used by Hexogate Node.
#
# Downloads an Xray release zip from GitHub and installs:
#   xray binary  -> $XRAY_BIN_DIR/xray            (default /usr/local/bin)
#   geo assets   -> $XRAY_ASSETS_DIR/*.dat         (default /usr/local/share/xray)
#
# Choose the core with environment variables:
#   XRAY_REPO     GitHub owner/repo that publishes Xray-style release zips.
#                 Default: XTLS/Xray-core. Point it at your own Xray fork to
#                 ship the Hexogate core build.
#   XRAY_VERSION  Release tag to install (for example v26.3.27). Default: latest.
#
# Arguments (kept compatible with the previous installer):
#   --os <linux|...>     Defaults to linux.
#   --arch <64|arm64-v8a|32|arm32-v7a|...>
#                        Xray asset arch suffix. Defaults to the host's arch.
#   --version <tag>      Same as XRAY_VERSION.
#   --repo <owner/repo>  Same as XRAY_REPO.

set -euo pipefail

XRAY_REPO="${XRAY_REPO:-XTLS/Xray-core}"
XRAY_VERSION="${XRAY_VERSION:-latest}"
XRAY_BIN_DIR="${XRAY_BIN_DIR:-/usr/local/bin}"
XRAY_ASSETS_DIR="${XRAY_ASSETS_DIR:-/usr/local/share/xray}"
OS="linux"
ARCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --os) OS="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --version) XRAY_VERSION="$2"; shift 2 ;;
    --repo) XRAY_REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH="64" ;;
    aarch64|arm64) ARCH="arm64-v8a" ;;
    i386|i686) ARCH="32" ;;
    armv7l|armv7*) ARCH="arm32-v7a" ;;
    armv6l) ARCH="arm32-v6" ;;
    riscv64) ARCH="riscv64" ;;
    s390x) ARCH="s390x" ;;
    *) echo "Unsupported architecture: $(uname -m); pass --arch" >&2; exit 1 ;;
  esac
fi

asset="Xray-${OS}-${ARCH}.zip"
if [ "$XRAY_VERSION" = "latest" ]; then
  url="https://github.com/${XRAY_REPO}/releases/latest/download/${asset}"
else
  url="https://github.com/${XRAY_REPO}/releases/download/${XRAY_VERSION}/${asset}"
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

echo "Installing Xray from ${XRAY_REPO} (${XRAY_VERSION}, ${asset})"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --retry 3 -o "$workdir/xray.zip" "$url"
else
  wget -q -O "$workdir/xray.zip" "$url"
fi

unzip -q -o "$workdir/xray.zip" -d "$workdir/out"

install -d "$XRAY_BIN_DIR" "$XRAY_ASSETS_DIR"
install -m 0755 "$workdir/out/xray" "$XRAY_BIN_DIR/xray"
for dat in "$workdir"/out/*.dat; do
  [ -e "$dat" ] && install -m 0644 "$dat" "$XRAY_ASSETS_DIR/"
done

"$XRAY_BIN_DIR/xray" version | head -n 1
