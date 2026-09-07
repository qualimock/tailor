#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"
MINGW_ARCH="${MINGW_ARCH:-ucrt64}"

mkdir -p "$DIST_DIR"

build_and_install() {
	local pkg_dir="$1"
	local name
	name="$(basename "$pkg_dir")"
	local prefix="mingw-w64-ucrt-x86_64-${name#mingw-w64-}"

	local cached
	cached="$(ls "$DIST_DIR/${prefix}"-[0-9]*.pkg.tar.zst 2>/dev/null | head -1 || true)"

	if [ -n "$cached" ]; then
		echo "== $name: using cached $(basename "$cached")"
	else
		echo "== $name: building"
		(
			cd "$pkg_dir"
			MINGW_ARCH="$MINGW_ARCH" makepkg-mingw -sCLf --noconfirm
		)
		cp "$pkg_dir/${prefix}"-[0-9]*.pkg.tar.zst "$DIST_DIR/"
		cached="$(ls "$DIST_DIR/${prefix}"-[0-9]*.pkg.tar.zst | head -1)"
	fi

	pacman -U --noconfirm "$cached"
}

build_and_install "$SCRIPT_DIR/mingw-w64-blueprint-compiler"
build_and_install "$SCRIPT_DIR/mingw-w64-libosinfo"
build_and_install "$SCRIPT_DIR/mingw-w64-osinfo-db-tools"
build_and_install "$SCRIPT_DIR/mingw-w64-osinfo-db"
