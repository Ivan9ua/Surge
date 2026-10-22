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
[[ -f "$source_dir/Surge.conf" ]] || { echo "源目录缺少单文件 Surge.conf" >&2; exit 1; }
if grep -qE '^[[:space:]]*#!include[[:space:]]' "$source_dir/Surge.conf"; then
  echo "源配置仍依赖分离文件，请先完成合并。" >&2
  exit 1
fi

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/surge-public-sync.XXXXXX")"
cleanup() {
  rm -rf -- "$staging_dir"
}
trap cleanup EXIT

tracked_files=(
  Surge.conf
  wechat.list
  quic-reject.list
  ai-extra.list
)
for tracked_file in "${tracked_files[@]}"; do
  if [[ -f "$repo_root/$tracked_file" ]]; then
    cp "$repo_root/$tracked_file" "$staging_dir/$tracked_file"
  fi
done

sanitize_config() {
  input_file="$1"
  output_file="$2"
  template_name="$3"
  {
    printf '# %s\n' "$template_name"
    printf '# 公开脱敏模板：仅在私有副本填写占位符并配置证书，切勿回传私有副本。\n\n'
    awk '
      BEGIN { in_keystore=0 }
      /^[[:space:]]*\[Keystore\][[:space:]]*$/ { in_keystore=1; next }
      in_keystore && /^[[:space:]]*\[/ { in_keystore=0 }
      !in_keystore { print }
    ' "$input_file" | sed -E \
      -e '/^# 含私密凭据与共用 CA/d' \
      -e '/^[[:space:]]*(ca-p12|ca-passphrase|ca-keystore-name)[[:space:]]*=/d' \
      -e '/^[[:space:]]*(http-api|external-controller-access|wifi-access-password)[[:space:]]*=/d' \
      -e 's/(psk=)[^,]*/\1YOUR_SNELL_PSK/g' \
      -e 's/(password=)[^,]*/\1YOUR_PROXY_PASSWORD/g' \
      -e 's/(policy-path=)[^,]*/\1YOUR_SURGE_SUBSCRIPTION_URL/g' \
      -e 's#https://[A-Za-z0-9.-]+\.alidns\.com/dns-query#https://dns.alidns.com/dns-query#g' \
      -e 's/^[[:space:]]*[A-Za-z0-9.-]+\.alidns\.com([[:space:]]*=)/dns.alidns.com\1/g' \
      -e 's/^[[:space:]]*server-proxy-name[[:space:]]*=.*/server-proxy-name= Hysteria/g' \
      -e 's/US-Hysteria/Hysteria/g' \
      -e 's/(= *snell, *)[^,]+,[^,]+,/\1example.com, 8388,/g' \
      -e 's/(= *hysteria2, *)[^,]+,[^,]+,/\1example.com, 443,/g' \
      -e 's/(= *anytls, *)[^,]+,[^,]+,/\1example.com, 443,/g' \
      -e 's/(sni=)[^,]*/\1example.com/g' \
      -e 's/^[[:space:]]*secret[[:space:]]*=.*/secret = 00000000000000000000000000000000/' |
      awk '
        NF { while (blank_count > 0) { print ""; blank_count-- } print; next }
        { blank_count++ }
      '
  } > "$output_file"
}

sanitize_config "$source_dir/Surge.conf" "$staging_dir/Surge.conf" 'Surge 双端单文件配置模板'

"$repo_root/scripts/validate-public-config.sh" --root "$staging_dir"

for tracked_file in "${tracked_files[@]}"; do
  if ! cmp -s "$staging_dir/$tracked_file" "$repo_root/$tracked_file"; then
    cp "$staging_dir/$tracked_file" "$repo_root/$tracked_file"
    echo "已安全更新: $tracked_file"
  fi
done

echo "同步完成；请检查 git diff 后再提交。"
