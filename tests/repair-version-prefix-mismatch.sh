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
version="6.9.3"
wrong_version="6.9.36"
asset="CLIProxyAPI_${version}_darwin_arm64.tar.gz"
asset_path="${tmp_dir}/${asset}"

mkdir -p "${fake_bin}" "${formula_prefix}/bin" "${cellar_root}/${version}/bin"
bin_dir="$(cd "${formula_prefix}/bin" && pwd -P)"
real_binary="${bin_dir}/cliproxyapi-${version}"
wrapper="${bin_dir}/cliproxyapi"
cat >"${real_binary}" <<EOF
#!/bin/sh
printf 'cli-proxy-api ${wrong_version}\n'
EOF
chmod 0755 "${real_binary}"
cat >"${wrapper}" <<'EOF'
#!/bin/sh
printf 'broken wrapper\n'
EOF
chmod 0755 "${wrapper}"

mkdir -p "${tmp_dir}/payload"
cat >"${tmp_dir}/payload/cli-proxy-api" <<EOF
#!/bin/sh
printf 'cli-proxy-api ${version}\n'
EOF
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

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" repair "${version}" >"${tmp_dir}/output.txt" 2>&1

grep -q "Existing upstream binary failed validation:" "${tmp_dir}/output.txt"
grep -q "Downloading release asset: ${asset}" "${tmp_dir}/output.txt"
grep -q "cli-proxy-api ${version}" "${tmp_dir}/output.txt"
grep -q "checksums.txt" "${tmp_dir}/curl.log"
grep -q "${asset}" "${tmp_dir}/curl.log"
