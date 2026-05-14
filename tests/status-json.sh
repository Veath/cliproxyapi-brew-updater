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
current_version="9.8.6"
latest_version="9.8.7"
config_path="${brew_prefix}/etc/cliproxyapi.conf"

mkdir -p "${fake_bin}" "${formula_prefix}/bin" "${cellar_root}/${current_version}/bin" "${cellar_root}/1.2.3/bin"
bin_dir="$(cd "${formula_prefix}/bin" && pwd -P)"
real_binary="${bin_dir}/cliproxyapi-${current_version}"
wrapper="${bin_dir}/cliproxyapi"
cat >"${real_binary}" <<EOF
#!/bin/sh
printf 'cli-proxy-api ${current_version}\n'
EOF
chmod 0755 "${real_binary}"
cat >"${wrapper}" <<EOF
#!/bin/sh
exec "${real_binary}" -config "${config_path}" "\$@"
EOF
chmod 0755 "${wrapper}"
printf '#!/bin/sh\nexit 0\n' >"${bin_dir}/cliproxyapi-1.2.3"
chmod 0755 "${bin_dir}/cliproxyapi-1.2.3"
printf '#!/bin/sh\nexit 0\n' >"${cellar_root}/1.2.3/bin/cliproxyapi-0.9.0"
chmod 0755 "${cellar_root}/1.2.3/bin/cliproxyapi-0.9.0"

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
    if [[ "\${2:-}" == "info" ]]; then
      printf 'Running: true\\n'
    else
      echo "status should not change services: \$*" >&2
      exit 2
    fi
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
url=""
write_effective=false
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -w|--write-out)
      write_effective=true
      shift 2
      ;;
    -o)
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
      printf '%s\\n' "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v${latest_version}"
    fi
    ;;
  *)
    echo "unexpected curl URL: \${url}" >&2
    exit 2
    ;;
esac
CURL
chmod 0755 "${fake_bin}/curl"

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" status --json >"${tmp_dir}/output.json"

grep -q '"command":"status"' "${tmp_dir}/output.json"
grep -q '"status":"update-available"' "${tmp_dir}/output.json"
grep -q '"currentVersion":"v9.8.6"' "${tmp_dir}/output.json"
grep -q '"latestVersion":"v9.8.7"' "${tmp_dir}/output.json"
grep -q '"wrapperStatus":"ok"' "${tmp_dir}/output.json"
grep -q '"serviceStatus":"running"' "${tmp_dir}/output.json"
grep -q '"oldReleaseBinaryCount":2' "${tmp_dir}/output.json"
