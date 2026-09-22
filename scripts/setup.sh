#!/usr/bin/env bash
# Provision the Roblox toolchain without requiring cargo/rokit/aftman.
# Downloads the pinned rojo release binary into tools/bin/.
set -euo pipefail

ROJO_VERSION="7.7.0"
STYLUA_VERSION="2.5.2"
SELENE_VERSION="0.31.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT/tools/bin"
mkdir -p "$BIN_DIR"

case "$(uname -s)" in
  Linux)  OS="linux"  ;;
  Darwin) OS="macos"  ;;
  *)      echo "Unsupported OS: $(uname -s). On Windows use rokit, or grab the release manually." >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  ARCH="x86_64"  ;;
  arm64|aarch64) ARCH="aarch64" ;;
  *)             echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# fetch <binary-name> <version> <download-url>
# Skips the download when the pinned version is already installed.
fetch() {
  local name="$1" version="$2" url="$3"
  if [[ -x "$BIN_DIR/$name" ]] && "$BIN_DIR/$name" --version 2>/dev/null | grep -q "$version"; then
    echo "$name $version already installed"
    return 0
  fi

  echo "Downloading $name $version ..."
  curl -fsSL "$url" -o "$TMP/$name.zip"
  unzip -q -o "$TMP/$name.zip" -d "$TMP/$name"
  install -m 0755 "$(find "$TMP/$name" -type f -name "$name" | head -1)" "$BIN_DIR/$name"
  echo "Installed: $("$BIN_DIR/$name" --version)"
}

# Rojo: source <-> Studio sync and place-file builds.
fetch rojo "$ROJO_VERSION" \
  "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-${OS}-${ARCH}.zip"

# StyLua: formatting. Also our syntax gate — it refuses to format code it
# cannot parse, so `make check` catches Luau syntax errors before Studio does.
fetch stylua "$STYLUA_VERSION" \
  "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-${OS}-${ARCH}.zip"

# Selene: static analysis against the Roblox standard library.
SELENE_OS="$OS"
[[ "$SELENE_OS" == "macos" ]] && SELENE_OS="macos"
fetch selene "$SELENE_VERSION" \
  "https://github.com/Kampfkarren/selene/releases/download/${SELENE_VERSION}/selene-${SELENE_VERSION}-${SELENE_OS}.zip"

if [[ ! -f "$ROOT/roblox.toml" ]]; then
  echo "Generating the Roblox standard library for selene ..."
  (cd "$ROOT" && "$BIN_DIR/selene" generate-roblox-std >/dev/null 2>&1) || \
    echo "warning: could not generate roblox std (offline?); selene will be less precise"
fi

echo "Toolchain ready in $BIN_DIR"
