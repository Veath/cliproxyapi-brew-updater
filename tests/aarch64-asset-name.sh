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
asset="CLIProxyAPI_${version}_darwin_aarch64.tar.gz"
asset_path="${tmp_dir}/${asset}"

mkdir -p "${fake_bin}" "${formula_prefix}/bin" "${cellar_root}/${version}/bin"
printf '#!/bin/sh\nexit 0\n' >"${formula_prefix}/bin/cliproxyapi"
chmod 0755 "${formula_prefix}/bin/cliproxyapi"

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
    exit 1
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
printf '%s\\n' "\$*" >>"${tmp_dir}/curl.log"

out=""
write_effective=false
url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o)
      out="\$2"
      shift 2
      ;;
    -w|--write-out)
      write_effective=true
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
  https://github.com/router-for-me/CLIProxyAPI/releases/latest)
    if [[ "\${write_effective}" == true ]]; then
      printf '%s\\n' "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v${version}"
    fi
    ;;
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

cat >"${fake_bin}/uname" <<'UNAME'
#!/usr/bin/env bash
if [[ "${1:-}" == "-m" ]]; then
  printf 'arm64\n'
else
  /usr/bin/uname "$@"
fi
UNAME
chmod 0755 "${fake_bin}/uname"

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" latest >"${tmp_dir}/output.txt" 2>&1

grep -q "Updating cliproxyapi to v${version}" "${tmp_dir}/output.txt"
grep -q "Downloading release asset: ${asset}" "${tmp_dir}/output.txt"
grep -q "Checksum verified" "${tmp_dir}/output.txt"
grep -q "Installed version:" "${tmp_dir}/output.txt"
grep -q "cli-proxy-api ${version}" "${tmp_dir}/output.txt"
