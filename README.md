# cliproxyapi-brew-updater

Update a Homebrew-managed `cliproxyapi` service to an upstream CLIProxyAPI
release binary while preserving the Homebrew service entry and config path.

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
