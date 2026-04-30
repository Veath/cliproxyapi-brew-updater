# Changelog

All notable changes to `cliproxyapi-brew-updater` are documented in this file.

## Unreleased

- Improved repository discoverability with clearer README wording, package
  metadata, and GitHub topics.
- Added this changelog.
- Documented the MIT license in the README.

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
