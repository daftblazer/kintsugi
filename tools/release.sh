#!/bin/bash
# tools/release.sh <version> [--upload]: build/dist/kintsugi-<version>.tar.gz, a kintsugi/ folder to extract into
# Steam's compatibilitytools.d. With --upload it is published as GitHub release <version> (gh CLI).
set -euo pipefail
cd "$(dirname "$0")/.."
VER=${1:?usage: tools/release.sh <version> [--upload]}
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "uncommitted changes: commit first" >&2; exit 1; }
tools/selftest.sh
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir "$d/kintsugi" && cp tool/* "$d/kintsugi/" && chmod +x "$d/kintsugi/kintsugi" "$d/kintsugi/kintsugi-engine"
echo "$VER" > "$d/kintsugi/VERSION"
mkdir -p build/dist
T=build/dist/kintsugi-$VER.tar.gz
tar -C "$d" -czf "$T" kintsugi
(cd build/dist && sha256sum "kintsugi-$VER.tar.gz" > "kintsugi-$VER.tar.gz.sha256")
echo "built $T"
if [ "${2:-}" = --upload ]; then
    gh release create "$VER" "$T" "$T.sha256" --title "Kintsugi $VER" --notes "Extract into Steam's compatibilitytools.d; see README.md."
fi
