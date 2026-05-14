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
cat >"${wrapper}" <<'EOF'
#!/bin/sh
printf 'broken wrapper\n'
EOF
chmod 0755 "${wrapper}"
printf '#!/bin/sh\nexit 0\n' >"${bin_dir}/cliproxyapi-1.2.3"
chmod 0755 "${bin_dir}/cliproxyapi-1.2.3"

cat >"${fake_bin}/brew" <<BREW
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "\$*" >>"${tmp_dir}/brew.log"
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
    elif [[ "\${2:-}" == "restart" ]]; then
      printf 'restarted\\n'
    else
      echo "unexpected brew services call: \$*" >&2
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

cat >"${fake_bin}/curl" <<'CURL'
#!/usr/bin/env bash
echo "repair should not download when the target binary already exists" >&2
exit 2
CURL
chmod 0755 "${fake_bin}/curl"

PATH="${fake_bin}:${PATH}" "${repo_root}/bin/cliproxyapi-brew-updater" repair "${version}" >"${tmp_dir}/output.txt" 2>&1

grep -q "Repairing cliproxyapi v${version}" "${tmp_dir}/output.txt"
grep -q "Reusing existing upstream binary:" "${tmp_dir}/output.txt"
grep -q "Writing Homebrew service wrapper:" "${tmp_dir}/output.txt"
grep -q "Restarting Homebrew service: cliproxyapi" "${tmp_dir}/output.txt"
grep -q "exec \"${real_binary}\" -config \"${config_path}\"" "${wrapper}"
if [[ -e "${bin_dir}/cliproxyapi-1.2.3" ]]; then
  echo "repair did not remove old release binaries" >&2
  exit 1
fi
grep -q "services restart cliproxyapi" "${tmp_dir}/brew.log"
