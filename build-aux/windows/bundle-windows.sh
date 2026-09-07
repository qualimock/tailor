#!/bin/bash
# bundle-windows.sh
#
# Stages a self-contained, relocatable copy of tailor.exe + its MSYS2
# UCRT64 runtime deps.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE_DIR="$ROOT_DIR/dist/Tailor"
VERSION="${RELEASE_VERSION:-0.0.0-dev}"
OUT_FILE="$ROOT_DIR/Tailor-${VERSION}-windows-x86_64-setup.exe"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"/bin "$STAGE_DIR"/lib/gdk-pixbuf-2.0/2.10.0/loaders "$STAGE_DIR"/lib/gio/modules \
	"$STAGE_DIR"/share/icons "$STAGE_DIR"/etc/ssl/certs

echo "== staging tailor's own install"
cp /ucrt64/bin/tailor.exe "$STAGE_DIR/bin/"
cp /ucrt64/bin/FlashHelper.exe "$STAGE_DIR/bin/"
cp -r /ucrt64/share/glib-2.0 "$STAGE_DIR/share/"
[ -d /ucrt64/share/locale ] && cp -r /ucrt64/share/locale "$STAGE_DIR/share/"
[ -d /ucrt64/share/metainfo ] && cp -r /ucrt64/share/metainfo "$STAGE_DIR/share/"

echo "== staging osinfo-db"
cp -r /ucrt64/share/osinfo "$STAGE_DIR/share/"

echo "== staging icon themes"
[ -d /ucrt64/share/icons/Adwaita ] && cp -r /ucrt64/share/icons/Adwaita "$STAGE_DIR/share/icons/"
[ -d /ucrt64/share/icons/hicolor ] && cp -r /ucrt64/share/icons/hicolor "$STAGE_DIR/share/icons/"
find "$STAGE_DIR/share/icons" -name icon-theme.cache -delete

echo "== staging gdk-pixbuf loaders (scanned at runtime, no cache — see main.vala)"
loaders_src="$(ls -d /ucrt64/lib/gdk-pixbuf-2.0/*/loaders | head -1)"
cp "$loaders_src"/*.dll "$STAGE_DIR/lib/gdk-pixbuf-2.0/2.10.0/loaders/"

echo "== staging GIO modules (TLS backend, ca-certificates provider)"
cp /ucrt64/lib/gio/modules/*.dll "$STAGE_DIR/lib/gio/modules/"

echo "== staging CA bundle for HTTPS downloads"
if [ -f /ucrt64/etc/ssl/certs/ca-bundle.crt ]; then
	cp /ucrt64/etc/ssl/certs/ca-bundle.crt "$STAGE_DIR/etc/ssl/certs/"
else
	echo "warning: ca-bundle.crt not found at the expected MSYS2 path — HTTPS downloads may fail until this is fixed" >&2
fi

echo "== resolving DLL closure"
resolved="$STAGE_DIR/bin/tailor.exe $STAGE_DIR/bin/FlashHelper.exe"
resolved="$resolved $(ls "$STAGE_DIR"/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll)"
resolved="$resolved $(ls "$STAGE_DIR"/lib/gio/modules/*.dll)"

while :; do
	new_dlls=""
	for bin in $resolved; do
		for dll in $(ldd "$bin" 2>/dev/null | grep -o '/ucrt64/bin/[^ ]*\.dll'); do
			name="$(basename "$dll")"
			if [ ! -f "$STAGE_DIR/bin/$name" ]; then
				cp "$dll" "$STAGE_DIR/bin/"
				new_dlls="$new_dlls $STAGE_DIR/bin/$name"
			fi
		done
	done
	[ -z "$new_dlls" ] && break
	resolved="$new_dlls"
done

echo "== generating .ico"
mkdir -p "$ROOT_DIR/dist"
ICON="$ROOT_DIR/dist/tailor.ico"
python3 "$ROOT_DIR/build-aux/windows/svg-to-ico.py" \
	"$ROOT_DIR/data/icons/org.altlinux.Tailor.svg" "$ICON"

echo "== building installer"
NSI="$ROOT_DIR/dist/tailor.nsi"
sed \
	-e "s|@VERSION@|$VERSION|g" \
	-e "s|@STAGE_DIR@|$(cygpath -m "$STAGE_DIR")|g" \
	-e "s|@OUT_FILE@|$(cygpath -m "$OUT_FILE")|g" \
	-e "s|@ICON@|$(cygpath -m "$ICON")|g" \
	"$ROOT_DIR/build-aux/windows/tailor.nsi.in" > "$NSI"

"${MAKENSIS:-/c/Program Files (x86)/NSIS/makensis.exe}" "$(cygpath -m "$NSI")"

echo "== installer at $OUT_FILE"
