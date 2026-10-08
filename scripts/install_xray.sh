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
#   XRAY_URL      Direct download URL instead of a GitHub release: either an
#                 Xray zip or a bare xray binary (https://, http:// or file://).
#                 Overrides XRAY_REPO / XRAY_VERSION.
#   XRAY_SHA256   Expected sha256 of the installed xray binary. When set, the
#                 install fails unless the binary matches exactly.
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
if [ -n "${XRAY_URL:-}" ]; then
  url="$XRAY_URL"
  echo "Installing Xray from ${url}"
elif [ "$XRAY_VERSION" = "latest" ]; then
  url="https://github.com/${XRAY_REPO}/releases/latest/download/${asset}"
  echo "Installing Xray from ${XRAY_REPO} (${XRAY_VERSION}, ${asset})"
else
  url="https://github.com/${XRAY_REPO}/releases/download/${XRAY_VERSION}/${asset}"
  echo "Installing Xray from ${XRAY_REPO} (${XRAY_VERSION}, ${asset})"
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}

fetch "$url" "$workdir/download"

mkdir -p "$workdir/out"
if unzip -tq "$workdir/download" >/dev/null 2>&1; then
  unzip -q -o "$workdir/download" -d "$workdir/out"
else
  # A bare binary rather than a release zip: take the geo assets
  # (geoip.dat, geosite.dat) from the regular release of XRAY_REPO.
  cp "$workdir/download" "$workdir/out/xray"
  if [ "$XRAY_VERSION" = "latest" ]; then
    assets_url="https://github.com/${XRAY_REPO}/releases/latest/download/${asset}"
  else
    assets_url="https://github.com/${XRAY_REPO}/releases/download/${XRAY_VERSION}/${asset}"
  fi
  echo "Fetching geo assets from ${assets_url}"
  fetch "$assets_url" "$workdir/assets.zip"
  unzip -q -o "$workdir/assets.zip" '*.dat' -d "$workdir/out"
fi
[ -f "$workdir/out/xray" ] || { echo "No xray binary found in the download" >&2; exit 1; }

if [ -n "${XRAY_SHA256:-}" ]; then
  actual="$(sha256sum "$workdir/out/xray" | cut -d' ' -f1)"
  if [ "$actual" != "$XRAY_SHA256" ]; then
    echo "xray sha256 mismatch: expected ${XRAY_SHA256}, got ${actual}" >&2
    exit 1
  fi
  echo "xray sha256 verified: ${actual}"
fi

install -d "$XRAY_BIN_DIR" "$XRAY_ASSETS_DIR"
install -m 0755 "$workdir/out/xray" "$XRAY_BIN_DIR/xray"
for dat in "$workdir"/out/*.dat; do
  if [ -e "$dat" ]; then install -m 0644 "$dat" "$XRAY_ASSETS_DIR/"; fi
done

"$XRAY_BIN_DIR/xray" version | head -n 1
