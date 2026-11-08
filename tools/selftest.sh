#!/bin/bash
# Run the dispatcher the way Steam does, against a fake engine in a temporary HOME.
set -euo pipefail
cd "$(dirname "$0")/.."
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export HOME=$t XDG_STATE_HOME= XDG_DATA_HOME=
unset XDG_STATE_HOME XDG_DATA_HOME KINTSUGI_ENGINES STEAM_COMPAT_INSTALL_PATH
mkdir -p "$t/.local/share/kintsugi/engines/123/" "$t/game"
printf '#!/bin/sh\necho "engine dir=$1 env=$KINTSUGI_GAME_DIR rest=$2"\nexit 7\n' > "$t/.local/share/kintsugi/engines/123/run"
chmod +x "$t/.local/share/kintsugi/engines/123/run"
fail() { echo "FAIL: $*"; cat "$t/.local/state/kintsugi/kintsugi.log"; exit 1; }

SteamAppId=123 STEAM_COMPAT_INSTALL_PATH="$t/game" tool/kintsugi waitforexitandrun "$t/game/Game.exe" -x && fail "exit status not passed through" || [ $? -eq 7 ] || fail "wrong status"
grep -q "engine dir=$t/game env=$t/game rest=$t/game/Game.exe" "$t/.local/state/kintsugi/123.log" || fail "engine arguments"
SteamAppId=123 tool/kintsugi waitforexitandrun "$t/other/Game.exe" || true
grep -q "engine dir=$t/other" "$t/.local/state/kintsugi/123.log" || fail "game folder from the .exe"
[ -f "$t/.local/state/kintsugi/123.prev.log" ] || fail "previous log kept"
SteamAppId=123 tool/kintsugi run "$t/x/iscriptevaluator.exe" --legacy || fail "install script not skipped"
[ "$(SteamAppId=123 tool/kintsugi getcompatpath /a/b)" = /a/b ] || fail "getcompatpath"
SteamAppId=999 tool/kintsugi waitforexitandrun "$t/game/Game.exe" && fail "missing engine accepted" || true
grep -q "no engine for app '999'" "$t/.local/state/kintsugi/kintsugi.log" || fail "missing engine logged"
tools/install-engine.sh 456 "$t/.local/share/kintsugi/engines/123" >/dev/null
tools/install-engine.sh 456 "$t/.local/share/kintsugi/engines/123" >/dev/null   # replace
[ -x "$t/.local/share/kintsugi/engines/456/run" ] && [ ! -e "$t/.local/share/kintsugi/engines/456.old" ] || fail "install-engine"
# a stop signal to the tool reaches the engine
mkdir -p "$t/.local/share/kintsugi/engines/77"
printf '#!/bin/bash\ntrap "echo got-term; exit 3" TERM\nwhile :; do sleep 0.1; done\n' > "$t/.local/share/kintsugi/engines/77/run"
chmod +x "$t/.local/share/kintsugi/engines/77/run"
SteamAppId=77 tool/kintsugi waitforexitandrun "$t/game/G.exe" & k=$!
sleep 1; kill -TERM $k; s=0; wait $k || s=$?
[ $s -eq 3 ] && grep -q got-term "$t/.local/state/kintsugi/77.log" || fail "signal not forwarded (status $s)"
# releases: a fake GitHub API and release files as file:// URLs
arch=$(uname -m)
mkrel() {  # tag: a release of fake/engine with an engine that prints its tag
    local d=$t/rel/$1; mkdir -p "$d/e" "$t/api/repos/fake/engine/releases/tags"
    printf '#!/bin/sh\necho "release %s"\n' "$1" > "$d/e/run"; chmod +x "$d/e/run"
    tar -C "$d/e" -czf "$d/eng-$1-linux-$arch.tar.gz" .
    (cd "$d" && sha256sum "eng-$1-linux-$arch.tar.gz" > "eng-$1-linux-$arch.tar.gz.sha256")
    printf '{\n  "tag_name": "%s",\n  "assets": [\n    {"browser_download_url": "file://%s/eng-%s-linux-%s.tar.gz"},\n    {"browser_download_url": "file://%s/eng-%s-linux-%s.tar.gz.sha256"}\n  ]\n}\n' \
        "$1" "$d" "$1" "$arch" "$d" "$1" "$arch" > "$t/api/repos/fake/engine/releases/tags/$1"
    cp "$t/api/repos/fake/engine/releases/tags/$1" "$t/api/repos/fake/engine/releases/latest"
}
export KINTSUGI_GITHUB_API=file://$t/api KINTSUGI_ENGINE_LIST=$t/engines.tsv
printf '# test\n555\tfake/engine\tFake Game\n' > "$t/engines.tsv"
mkrel v1
SteamAppId=555 tool/kintsugi waitforexitandrun "$t/game/G.exe" || fail "first start of a listed engine"
grep -q "release v1" "$t/.local/state/kintsugi/555.log" || fail "engine not downloaded on first start"
[ "$(cat "$t/.local/share/kintsugi/engines/555/.kintsugi-release")" = "fake/engine v1" ] || fail "release not recorded"
mkrel v2
SteamAppId=555 tool/kintsugi waitforexitandrun "$t/game/G.exe" || true
grep -q "release v1" "$t/.local/state/kintsugi/555.log" || fail "update checked again within a day"
rm "$t/.local/state/kintsugi/555.update-check"
SteamAppId=555 tool/kintsugi waitforexitandrun "$t/game/G.exe" || true
grep -q "release v2" "$t/.local/state/kintsugi/555.log" || fail "not updated to v2"
mkrel v3; echo "0000  bad" > "$t/rel/v3/eng-v3-linux-$arch.tar.gz.sha256"
tool/kintsugi-engine update 555 >/dev/null 2>&1 && fail "bad checksum accepted"
grep -q "release v2" "$t/.local/share/kintsugi/engines/555/run" || fail "engine changed by a failed update"
rm -rf "$t/api"; rm "$t/.local/state/kintsugi/555.update-check"
SteamAppId=555 tool/kintsugi waitforexitandrun "$t/game/G.exe" || fail "offline start"
grep -q "release v2" "$t/.local/state/kintsugi/555.log" || fail "offline: installed engine not started"
tool/kintsugi-engine list | grep -q "^555 .*v2" || fail "list"
tool/kintsugi-engine remove 555 >/dev/null && [ ! -e "$t/.local/share/kintsugi/engines/555" ] || fail "remove"
echo "selftest: all passed"
