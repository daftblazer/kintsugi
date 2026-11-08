# Kintsugi

A Steam compatibility tool that runs a **native engine** in place of a Windows game. Pick "Kintsugi"
instead of Proton in a game's Properties > Compatibility and press Play. Steam then starts the game's
native Linux port (a static recompilation or a rewrite) with the game's own files, from its own library
entry, with Steam Input and the Game Mode overlay. It is similar in spirit to Luxtorpeda.

Kintsugi downloads each game's engine from that engine's GitHub releases on the first start, and keeps
it up to date. **No engines or game files are part of this repository.**

## Engines

| Steam app | Game | Engine |
|---|---|---|
| 372360 | Tales of Symphonia | [kintsugi-symphonia](https://github.com/daftblazer/kintsugi-symphonia) |

Engines are built for x86_64 and aarch64 Linux.

## Install

1. Download `kintsugi-<version>.tar.gz` from the [releases](https://github.com/daftblazer/kintsugi/releases)
   and extract it into Steam's `compatibilitytools.d` folder:

   ```
   mkdir -p ~/.local/share/Steam/compatibilitytools.d
   tar -xzf kintsugi-*.tar.gz -C ~/.local/share/Steam/compatibilitytools.d
   ```

   For the Flatpak Steam the folder is
   `~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d`. From a checkout,
   `tools/install.sh` does the same (or `tools/install.sh user@host` over SSH).
2. Restart Steam. In Game Mode that's Steam menu > Power > Restart Steam.
3. In the game's Properties > Compatibility, enable "Force the use of a specific Steam Play
   compatibility tool" and pick **Kintsugi**. It is listed for every Windows game, but only games in
   the table above start.

The first start downloads the engine, so it needs a network connection. After that, the game starts
offline too.

## Managing engines

`kintsugi-engine` (next to the `kintsugi` script in `compatibilitytools.d/kintsugi/`):

```
kintsugi-engine list                     # known engines and the installed versions
kintsugi-engine install <appid> [tag]    # download the latest release (or that tag) for this machine
kintsugi-engine update [appid...]        # install newer releases (all installed engines without appid)
kintsugi-engine remove <appid>
```

On each start Kintsugi looks for a newer release of the game's engine, at most once a day. If it can't
reach GitHub, it starts the installed engine. Set `KINTSUGI_UPDATE=0` (for example in the game's launch
options, `KINTSUGI_UPDATE=0 %command%`) to never update. A download is checked against the release's
SHA-256 sum before it replaces anything.

Logs are in `~/.local/state/kintsugi/`: `kintsugi.log` has every call from Steam, downloads and updates;
`<appid>.log` has the engine's output, and `<appid>.prev.log` the run before.

## How it works

Steam runs `kintsugi <verb> <the game's command line>` with `SteamAppId` and
`STEAM_COMPAT_INSTALL_PATH` (the game folder) in the environment (`tool/toolmanifest.vdf`,
`tool/compatibilitytool.vdf`). For `waitforexitandrun` / `run`, `tool/kintsugi` starts

```
~/.local/share/kintsugi/engines/<appid>/run <game folder> <the game's command line...>
```

and waits for it, passing Steam's stop signal on. Steam's runs of Windows install scripts
(`iscriptevaluator.exe`) and path queries are answered without doing anything. No Steam Linux Runtime
container is used: engines run directly on the host.

## Writing an engine

An engine is a folder with an executable `run` and whatever it needs (binary, `lib/`):

- `$1` is the game folder; the game's original command line follows (usually ignore it).
- Environment: `KINTSUGI_APPID`, `KINTSUGI_GAME_DIR`, `KINTSUGI_ENGINE_DIR` (the engine's own
  folder), plus Steam's (`STEAM_COMPAT_DATA_PATH`: the game's Proton prefix folder, which may
  exist from earlier Proton runs).
- Keep saves and settings outside the engine folder, which is replaced on every update. Use
  `~/.local/share/kintsugi/<engine>/` and `~/.config/kintsugi/<engine>/`.
- Exit when the game quits; the exit status is passed to Steam.

**Releases:**
- Publish the engine folder as GitHub release assets named `<name>-<version>-linux-<arch>.tar.gz`
  (`arch` as `uname -m` prints it: `x86_64`, `aarch64`). The folder's contents go at the top level of
  the archive.
- Next to each archive, publish `<archive>.sha256` in `sha256sum` format.
- Build against an old glibc (for example in an Ubuntu 22.04 container) so the engine runs on
  SteamOS and other distributions.

Then add a line to `tool/engines.tsv`: app ID, `owner/repository`, game.

For development, `tools/install-engine.sh <appid> <folder> [user@host]` installs a local engine folder
(over SSH with a host). It swaps the folder in, so a running engine is never overwritten in place.
Kintsugi doesn't update an engine installed this way.

## Development

- `tools/selftest.sh` runs the dispatcher as Steam would, against fake engines and a fake release server.
- `tools/release.sh <version> [--upload]` packages `tool/` as `build/dist/kintsugi-<version>.tar.gz`
  (and publishes it with the GitHub CLI).

## License

MIT (see `LICENSE`). This covers the code in this repository only, not any game or program it is used with.
