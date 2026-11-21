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
  ai-extra.list
)
for tracked_file in "${tracked_files[@]}"; do
  if [[ -f "$repo_root/$tracked_file" ]]; then
    cp "$repo_root/$tracked_file" "$staging_dir/$tracked_file"
  fi
done

alias_map_file="${SURGE_ALIAS_MAP:-$HOME/.config/surge-public-sync/aliases.map}"

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
      -e '/^[[:space:]]*((#|;|\/\/)[[:space:]]*)?(http-api(-mcp|-tls|-web-dashboard)?|external-controller-access|wifi-access-password|http-listen|socks5-listen|wifi-access-http-auth)[[:space:]]*=/Id' \
      -e '/^# iPhone 管理/d' \
      -e '/^# HTTPS 管理传输/d' \
      -e 's/^# DoH 引导映射：私人 AliDNS$/# DoH 引导映射：阿里公共 DNS/' \
      -e 's/(psk=)[^,]*/\1YOUR_SNELL_PSK/g' \
      -e 's/(password=)[^,]*/\1YOUR_PROXY_PASSWORD/g' \
      -e 's/(policy-path=)[^,]*/\1YOUR_SURGE_SUBSCRIPTION_URL/g' \
      -e 's#icon-url=https://raw\.githubusercontent\.com/lige47/QuanX-icon-rule/main/icon/06jichang/[^,[:space:]]*#icon-url=https://raw.githubusercontent.com/Irrucky/Tool/main/Surge/icon/surge_2.png#g' \
      -e 's#https://[A-Za-z0-9.-]+\.alidns\.com/dns-query#https://dns.alidns.com/dns-query#g' \
      -e 's/^[[:space:]]*[A-Za-z0-9.-]+\.alidns\.com([[:space:]]*=)/dns.alidns.com\1/g' \
      -e 's/^[[:space:]]*server-proxy-name[[:space:]]*=.*/server-proxy-name= Hysteria/g' \
      -e 's/(= *snell, *)[^,]+, *[^,]+,/\1example.com, 8388,/g' \
      -e 's/(= *hysteria2, *)[^,]+, *[^,]+,/\1example.com, 443,/g' \
      -e 's/(= *anytls, *)[^,]+, *[^,]+,/\1example.com, 443,/g' \
      -e 's/(= *vless, *)[^,]+, *[^,]+,/\1example.com, 443,/g' \
      -e 's/(username[[:space:]]*=[[:space:]]*)[^,]*/username=00000000-0000-0000-0000-000000000000/g' \
      -e 's/(reality-public-key[[:space:]]*=[[:space:]]*)[^,]*/reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/g' \
      -e 's/(reality-short-id[[:space:]]*=[[:space:]]*)[^,# ]*/reality-short-id=00000000/g' \
      -e 's/(exec[[:space:]]*=[[:space:]]*)"[^"]*"/exec = "\/path\/to\/external-proxy\/start-client.sh"/g' \
      -e 's/(addresses[[:space:]]*=[[:space:]]*)[^,# ]*/addresses = 198.51.100.1/g' \
      -e 's/(sni=)[^,]*/\1example.com/g' \
      -e 's/^[[:space:]]*secret[[:space:]]*=.*/secret = 00000000000000000000000000000000/' |
      awk -v map_file="$alias_map_file" '
        BEGIN {
          n = 0
          blank_count = 0
          if (map_file != "" && (getline line < map_file) >= 0) {
            close(map_file)
            while ((getline line < map_file) > 0) {
              sub(/\r$/, "", line)
              if (line ~ /^[[:space:]]*(#|$)/) continue
              eq = index(line, "=")
              if (eq <= 1) continue
              old_val = substr(line, 1, eq - 1)
              new_val = substr(line, eq + 1)
              if (old_val != "") {
                n++
                olds[n] = old_val
                news[n] = new_val
              }
            }
            close(map_file)
          }
        }
        {
          out = $0
          for (i = 1; i <= n; i++) {
            pat = olds[i]
            rep = news[i]
            plen = length(pat)
            res = ""
            while ((pos = index(out, pat)) > 0) {
              res = res substr(out, 1, pos - 1) rep
              out = substr(out, pos + plen)
            }
            out = res out
          }
          if (out ~ /[^[:space:]]/) {
            if (blank_count > 0) {
              print ""
              blank_count = 0
            }
            print out
          } else {
            blank_count++
          }
        }
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
