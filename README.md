# cliproxyapi-brew-updater

Update a Homebrew-managed `cliproxyapi` service to an upstream CLIProxyAPI
release binary while preserving the Homebrew service entry and config path.

This is useful when `homebrew/core` lags behind upstream CLIProxyAPI releases.

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
