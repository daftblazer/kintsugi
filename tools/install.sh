#!/bin/bash
# Install the Kintsugi compatibility tool into Steam: tools/install.sh [user@host]
# (no host: this machine). Steam lists it after its next start, in a game's Properties >
# Compatibility > "Force the use of a specific Steam Play compatibility tool".
set -euo pipefail
cd "$(dirname "$0")/.."
dest='.local/share/Steam/compatibilitytools.d/kintsugi'
if [ $# -eq 0 ]; then
    mkdir -p "$HOME/$dest" && cp tool/* "$HOME/$dest/" && chmod +x "$HOME/$dest/kintsugi" "$HOME/$dest/kintsugi-engine"
    echo "installed in ~/$dest"
else
    ssh "$1" "mkdir -p ~/$dest"
    scp -q tool/* "$1:$dest/"
    ssh "$1" "chmod +x ~/$dest/kintsugi ~/$dest/kintsugi-engine && echo installed in \$HOME/$dest"
fi
