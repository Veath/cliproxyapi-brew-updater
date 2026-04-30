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
config_path="${brew_prefix}/etc/cliproxyapi.conf"

mkdir -p "${fake_bin}" "${formula_prefix}/bin" "${cellar_root}/${version}/bin"
bin_dir="$(cd "${formula_prefix}/bin" && pwd -P)"
real_binary="${bin_dir}/cliproxyapi-${version}"
wrapper="${bin_dir}/cliproxyapi"
cat >"${real_binary}" <<EOF
#!/bin/sh
printf 'cli-proxy-api ${version}\n'
EOF
chmod 0755 "${real_binary}"
cat >"${wrapper}" <<EOF
#!/bin/sh
exec "${real_binary}" -config "${config_path}" "\$@"
EOF
chmod 0755 "${wrapper}"

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
    echo "brew services should not be called when already up to date" >&2
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
  *)
    echo "up-to-date run should not download: \${url}" >&2
    exit 2
    ;;
esac
CURL
chmod 0755 "${fake_bin}/curl"

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" latest >"${tmp_dir}/output.txt" 2>&1

grep -q "Resolving latest CLIProxyAPI release" "${tmp_dir}/output.txt"
grep -q "Already up to date: cliproxyapi v${version}" "${tmp_dir}/output.txt"

if grep -q "Downloading checksums" "${tmp_dir}/output.txt"; then
  echo "up-to-date run should not download checksums" >&2
  exit 1
fi

if grep -q "Downloading release asset" "${tmp_dir}/output.txt"; then
  echo "up-to-date run should not download the release asset" >&2
  exit 1
fi
