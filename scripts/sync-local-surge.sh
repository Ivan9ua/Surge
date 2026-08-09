#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${1:-}"
apply_flag="${2:-}"

if [[ -z "$source_dir" || "$apply_flag" != "--apply" ]]; then
  echo "用法: scripts/sync-local-surge.sh /path/to/Surge --apply" >&2
  echo "必须显式使用 --apply；脚本不会直接复制未脱敏配置。" >&2
  exit 2
fi

[[ -d "$source_dir" ]] || { echo "源目录不存在: $source_dir" >&2; exit 1; }

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/surge-public-sync.XXXXXX")"
cleanup() {
  rm -rf -- "$staging_dir"
}
trap cleanup EXIT

tracked_files=(Surge.conf iPhone.conf Shared.dconf bilibili.sgmodule youtube-enhance-bounded.sgmodule)
for tracked_file in "${tracked_files[@]}"; do
  cp "$repo_root/$tracked_file" "$staging_dir/$tracked_file"
done

sanitize_config() {
  input_file="$1"
  output_file="$2"
  sed -E \
    -e '/^[[:space:]]*(ca-p12|ca-passphrase)[[:space:]]*=/d' \
    -e 's/(psk=)[^,]*/\1YOUR_SNELL_PSK/g' \
    -e 's/(policy-path=)[^,]*/\1YOUR_SURGE_SUBSCRIPTION_URL/g' \
    -e 's/(= *snell, *)[^,]+,[^,]+,/\1example.com, 8388,/g' \
    "$input_file" > "$output_file"
}

if [[ -f "$source_dir/Mac.conf" ]]; then
  sanitize_config "$source_dir/Mac.conf" "$staging_dir/Surge.conf"
elif [[ -f "$source_dir/Surge.conf" ]]; then
  sanitize_config "$source_dir/Surge.conf" "$staging_dir/Surge.conf"
fi

for config_name in iPhone.conf Shared.dconf; do
  if [[ -f "$source_dir/$config_name" ]]; then
    sanitize_config "$source_dir/$config_name" "$staging_dir/$config_name"
  fi
done

for module_name in bilibili.sgmodule youtube-enhance-bounded.sgmodule; do
  if [[ -f "$source_dir/$module_name" ]]; then
    cp "$source_dir/$module_name" "$staging_dir/$module_name"
  fi
done

"$repo_root/scripts/validate-public-config.sh" --root "$staging_dir"

for tracked_file in "${tracked_files[@]}"; do
  if ! cmp -s "$staging_dir/$tracked_file" "$repo_root/$tracked_file"; then
    cp "$staging_dir/$tracked_file" "$repo_root/$tracked_file"
    echo "已安全更新: $tracked_file"
  fi
done

echo "同步完成；请检查 git diff 后再提交。"
