# cliproxyapi-brew-updater: CLIProxyAPI Homebrew updater for macOS

`cliproxyapi-brew-updater` is an npm/npx CLI for macOS users who installed
[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) with
[Homebrew](https://brew.sh/). It updates a Homebrew-managed `cliproxyapi`
service to the latest upstream GitHub release binary while preserving
`brew services` and the Homebrew config path.

Use it when `brew upgrade cliproxyapi` is behind the upstream
`router-for-me/CLIProxyAPI` release, but you still want to keep the Homebrew
service workflow and `/opt/homebrew/etc/cliproxyapi.conf` configuration.

## Why this exists

CLIProxyAPI publishes releases frequently, but the `homebrew/core` formula may
not follow every upstream patch release immediately. In particular, Homebrew's
formula can use `livecheck` throttling for high-frequency projects, so a release
such as `6.9.36` may be available on GitHub while `brew upgrade cliproxyapi`
still installs an older version.

Installing the upstream binary manually solves the version lag, but it creates a
second problem: many users already run CLIProxyAPI with `brew services` and keep
their config at Homebrew's config path, such as
`/opt/homebrew/etc/cliproxyapi.conf`. Replacing the command naively can lose that
service workflow or start CLIProxyAPI without the expected config file.

This package keeps the Homebrew workflow intact while using the upstream release
binary. It updates the binary used by the Homebrew service, writes a small
wrapper that passes the existing Homebrew config file, restarts the service when
needed, and removes older manually installed release binaries.

## What it does

- updates Homebrew-installed CLIProxyAPI on macOS from upstream GitHub releases
- keeps `brew services start cliproxyapi` and `brew services restart cliproxyapi`
  working
- preserves the Homebrew config file path, including
  `/opt/homebrew/etc/cliproxyapi.conf`
- supports Apple Silicon (`darwin_arm64`) and Intel (`darwin_amd64`) Macs
- runs as a one-command `npx cliproxyapi-brew-updater` utility

## Usage

Run the latest upstream release:

```bash
npx cliproxyapi-brew-updater
```

Run a specific version:

```bash
npx cliproxyapi-brew-updater 6.9.36
npx cliproxyapi-brew-updater v6.9.36
```

The updater:

- detects `darwin_arm64` or `darwin_amd64`
- downloads the matching GitHub release asset
- verifies the release checksum
- installs the upstream binary into the active Homebrew keg
- writes a `cliproxyapi` wrapper that passes:
  `/opt/homebrew/etc/cliproxyapi.conf` or `${HOMEBREW_PREFIX}/etc/cliproxyapi.conf`
- restarts `brew services` if `cliproxyapi` is already running
- removes old `cliproxyapi-*` binaries from all local `cliproxyapi` kegs

## Requirements

- macOS
- Homebrew
- `cliproxyapi` installed with Homebrew
- `curl`, `tar`, and `shasum`

## Notes

`brew upgrade cliproxyapi` or `brew reinstall cliproxyapi` may replace the
wrapper. Run this updater again afterward if Homebrew is still behind upstream.

## FAQ

### How do I update CLIProxyAPI when Homebrew is behind GitHub releases?

Run `npx cliproxyapi-brew-updater`. The updater resolves the latest
CLIProxyAPI GitHub release, downloads the matching macOS binary, verifies its
checksum, and installs it into the active Homebrew keg.

### Does this replace Homebrew or stop using brew services?

No. The updater keeps the Homebrew-managed service entry. It replaces the
service executable with a wrapper that runs the downloaded upstream CLIProxyAPI
binary and passes the Homebrew config file path.

### Can I install a specific CLIProxyAPI version?

Yes. Pass a version such as `6.9.36` or `v6.9.36`:

```bash
npx cliproxyapi-brew-updater 6.9.36
```

## License

MIT. See [LICENSE](LICENSE).
