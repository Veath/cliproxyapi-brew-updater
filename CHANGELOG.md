# Changelog

All notable changes to `cliproxyapi-brew-updater` are documented in this file.

## Unreleased

- No changes yet.

## 0.1.6 - 2026-04-30

- Skip downloads, wrapper rewrites, and service restarts when the requested
  upstream CLIProxyAPI version is already installed and the Homebrew wrapper
  already points to it.

## 0.1.5 - 2026-04-30

- Added a compact single-line progress bar for the main CLIProxyAPI release
  asset download.

## 0.1.4 - 2026-04-30

- Improved repository discoverability with clearer README wording, package
  metadata, and GitHub topics.
- Added this changelog.
- Documented the MIT license in the README.
- Made updater logs quieter and more readable by hiding curl progress meters and
  printing concise installation steps.

## 0.1.3 - 2026-04-28

- Added retry handling for transient `curl` failures when resolving releases,
  downloading checksums, or downloading CLIProxyAPI assets.
- Kept the latest-release regression test covering the retry path.

## 0.1.2 - 2026-04-27

- Avoided GitHub REST API rate limits when resolving the latest CLIProxyAPI
  release.
- Switched latest-version resolution to GitHub's normal release redirect.
- Added a regression test to ensure the `latest` path does not call
  `api.github.com`.

## 0.1.1 - 2026-04-24

- Expanded the README with the reason this updater exists and how it preserves
  the Homebrew service workflow.

## 0.1.0 - 2026-04-24

- Published the initial npm CLI package.
- Added support for installing upstream CLIProxyAPI release binaries into the
  active Homebrew keg.
- Preserved `brew services` behavior through a wrapper that passes the Homebrew
  config path.
