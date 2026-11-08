#!/bin/bash
# Install a game's engine: tools/install-engine.sh <steam appid> <engine folder> [user@host]
# The folder must contain an executable `run` (see README.md, "Engines"). It is copied to
# ~/.local/share/kintsugi/engines/<appid>/ (on the host, if given) through a temporary folder,
# then swapped in, so a running engine's files are never overwritten in place.
set -euo pipefail
appid=${1:?usage: install-engine.sh <appid> <engine folder> [user@host]}
src=${2:?usage: install-engine.sh <appid> <engine folder> [user@host]}
host=${3:-}
[ -x "$src/run" ] || { echo "$src/run is missing or not executable" >&2; exit 1; }
base='.local/share/kintsugi/engines'
swap="cd ~/$base && rm -rf $appid.old && { [ ! -e $appid ] || mv $appid $appid.old; } && mv $appid.new $appid && rm -rf $appid.old"
if [ -z "$host" ]; then
    mkdir -p "$HOME/$base" && rm -rf "$HOME/$base/$appid.new" && cp -a "$src" "$HOME/$base/$appid.new"
    bash -c "$swap"
    echo "engine $appid installed in ~/$base/$appid"
else
    ssh "$host" "mkdir -p ~/$base && rm -rf ~/$base/$appid.new"
    scp -qr "$src" "$host:$base/$appid.new"
    ssh "$host" "$swap && echo engine $appid installed in \$HOME/$base/$appid"
fi
