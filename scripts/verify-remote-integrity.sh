#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/scripts/remote-assets.sha256"
download_file="$(mktemp "${TMPDIR:-/tmp}/surge-remote-asset.XXXXXX")"
cleanup() {
  rm -f -- "$download_file"
}
trap cleanup EXIT

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

while read -r expected_hash asset_url; do
  [[ -n "$expected_hash" && -n "$asset_url" ]] || continue
  curl -A 'Surge Mac/6.8.0' -fsSL --retry 2 --max-time 30 "$asset_url" -o "$download_file"
  actual_hash="$(hash_file "$download_file")"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    echo "远程脚本完整性校验失败: $asset_url" >&2
    exit 1
  fi
done < "$manifest"

echo "远程脚本完整性校验通过"
