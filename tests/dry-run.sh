#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

fake_bin="${tmp_dir}/bin"
brew_prefix="${tmp_dir}/homebrew"
formula_prefix="${brew_prefix}/opt/cliproxyapi"
cellar_root="${brew_prefix}/Cellar/cliproxyapi"
version="9.8.7"
asset="CLIProxyAPI_${version}_darwin_arm64.tar.gz"
asset_path="${tmp_dir}/${asset}"

mkdir -p "${fake_bin}" "${formula_prefix}/bin" "${cellar_root}/${version}/bin"
printf '#!/bin/sh\nprintf "old wrapper\\n"\n' >"${formula_prefix}/bin/cliproxyapi"
chmod 0755 "${formula_prefix}/bin/cliproxyapi"
before_wrapper="$(shasum -a 256 "${formula_prefix}/bin/cliproxyapi" | awk '{print $1}')"

mkdir -p "${tmp_dir}/payload"
printf '#!/bin/sh\nprintf "cli-proxy-api %s\\n" "$1"\n' "${version}" >"${tmp_dir}/payload/cli-proxy-api"
chmod 0755 "${tmp_dir}/payload/cli-proxy-api"
tar -czf "${asset_path}" -C "${tmp_dir}/payload" cli-proxy-api
checksum="$(shasum -a 256 "${asset_path}" | awk '{print $1}')"

cat >"${fake_bin}/brew" <<BREW
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  --prefix)
    if [[ "\${2:-}" == "cliproxyapi" ]]; then
      printf '%s\\n' "${formula_prefix}"
    else
      printf '%s\\n' "${brew_prefix}"
    fi
    ;;
  --cellar)
    printf '%s\\n' "${cellar_root}"
    ;;
  services)
    echo "dry-run should not call brew services" >&2
    exit 2
    ;;
  *)
    echo "unexpected brew call: \$*" >&2
    exit 2
    ;;
esac
BREW
chmod 0755 "${fake_bin}/brew"

cat >"${fake_bin}/curl" <<CURL
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o)
      out="\$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="\$1"
      shift
      ;;
  esac
done
case "\${url}" in
  https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/checksums.txt)
    printf '%s  %s\\n' "${checksum}" "${asset}" >"\${out}"
    ;;
  https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/${asset})
    cp "${asset_path}" "\${out}"
    ;;
  *)
    echo "unexpected curl URL: \${url}" >&2
    exit 2
    ;;
esac
CURL
chmod 0755 "${fake_bin}/curl"

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" --dry-run "${version}" >"${tmp_dir}/output.txt" 2>&1

grep -q "Dry run: no files or services were changed" "${tmp_dir}/output.txt"
grep -q "Would install upstream binary:" "${tmp_dir}/output.txt"
grep -q "Would write Homebrew service wrapper:" "${tmp_dir}/output.txt"

after_wrapper="$(shasum -a 256 "${formula_prefix}/bin/cliproxyapi" | awk '{print $1}')"
if [[ "${after_wrapper}" != "${before_wrapper}" ]]; then
  echo "dry-run changed the wrapper" >&2
  exit 1
fi
if [[ -e "${formula_prefix}/bin/cliproxyapi-${version}" ]]; then
  echo "dry-run installed the release binary" >&2
  exit 1
fi
