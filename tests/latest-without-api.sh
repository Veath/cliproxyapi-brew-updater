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
printf '#!/bin/sh\nexit 0\n' >"${formula_prefix}/bin/cliproxyapi"
chmod 0755 "${formula_prefix}/bin/cliproxyapi"

mkdir -p "${tmp_dir}/payload"
printf '#!/bin/sh\nprintf "cli-proxy-api %s\\n" "$1"\n' "${version}" >"${tmp_dir}/payload/cli-proxy-api"
chmod 0755 "${tmp_dir}/payload/cli-proxy-api"
tar -czf "${asset_path}" -C "${tmp_dir}/payload" cli-proxy-api
checksum="$(shasum -a 256 "${asset_path}" | awk '{print $1}')"
latest_attempts_file="${tmp_dir}/latest-attempts"

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

for arg in "\$@"; do
  if [[ "\${arg}" == *api.github.com* ]]; then
    echo "test must not call GitHub API for latest resolution" >&2
    exit 56
  fi
done

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
    latest_attempts=0
    if [[ -f "${latest_attempts_file}" ]]; then
      latest_attempts="\$(cat "${latest_attempts_file}")"
    fi
    latest_attempts=\$((latest_attempts + 1))
    printf '%s\\n' "\${latest_attempts}" >"${latest_attempts_file}"
    if [[ "\${latest_attempts}" -eq 1 ]]; then
      echo "curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to github.com:443" >&2
      exit 35
    fi
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

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" latest >"${tmp_dir}/output.txt" 2>&1

if grep -q 'api.github.com' "${tmp_dir}/curl.log"; then
  echo "GitHub API was called despite successful run" >&2
  exit 1
fi

grep -q "Resolving latest CLIProxyAPI release" "${tmp_dir}/output.txt"
grep -q "Updating cliproxyapi to v${version}" "${tmp_dir}/output.txt"
grep -q "Downloading release asset: ${asset}" "${tmp_dir}/output.txt"
grep -q "Checksum verified" "${tmp_dir}/output.txt"
grep -q "Installed version:" "${tmp_dir}/output.txt"
grep -q "cli-proxy-api ${version}" "${tmp_dir}/output.txt"

if grep -q '% Total' "${tmp_dir}/output.txt"; then
  echo "curl progress meter should not be shown in updater output" >&2
  exit 1
fi

if grep -Eq '(/tmp|/var/folders/).+ OK' "${tmp_dir}/output.txt"; then
  echo "raw checksum temp-file output should not be shown" >&2
  exit 1
fi
