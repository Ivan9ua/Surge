#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scan_root="$repo_root"
scan_history=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "--root 缺少目录" >&2; exit 2; }
      scan_root="$2"
      shift 2
      ;;
    --history)
      scan_history=true
      shift
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 2
      ;;
  esac
done

required_files=(Surge.conf iPhone.conf Shared.dconf bilibili.sgmodule youtube-enhance-bounded.sgmodule)
for config_file in "${required_files[@]}"; do
  [[ -f "$scan_root/$config_file" ]] || { echo "缺少文件: $config_file" >&2; exit 1; }
done

fail() {
  echo "校验失败: $*" >&2
  exit 1
}

config_files=("$scan_root/Surge.conf" "$scan_root/iPhone.conf" "$scan_root/Shared.dconf")
all_public_files=("${config_files[@]}" "$scan_root/bilibili.sgmodule" "$scan_root/youtube-enhance-bounded.sgmodule")

if grep -nE -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----' "${all_public_files[@]}" >/dev/null; then
  fail "发现 PEM 私钥材料"
fi

if grep -nE '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16})' "${all_public_files[@]}" >/dev/null; then
  fail "发现疑似平台访问令牌"
fi

if grep -nEi '^[[:space:]]*(ca-p12|ca-passphrase)[[:space:]]*=' "${config_files[@]}" >/dev/null; then
  fail "发现 MITM 私钥或口令字段"
fi

if grep -nE 'psk=' "${config_files[@]}" | grep -v 'psk=YOUR_SNELL_PSK' >/dev/null; then
  fail "发现非占位 Snell PSK"
fi

if grep -nE 'policy-path=' "${config_files[@]}" | grep -v 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' >/dev/null; then
  fail "发现非占位订阅地址"
fi

if grep -nEi '(ss|ssr|vmess|vless|trojan|hysteria2?)://' "${config_files[@]}" >/dev/null; then
  fail "发现可导入的代理 URI"
fi

if ! awk '
  BEGIN { in_proxy=0; bad=0 }
  /^\[Proxy\][[:space:]]*$/ { in_proxy=1; next }
  /^\[/ { in_proxy=0 }
  in_proxy && /^[[:space:]]*[^#;[:space:]][^=]*=/ {
    if ($0 !~ /= *snell, *example\.com, *8388, *psk=YOUR_SNELL_PSK,/) bad=1
  }
  END { exit bad }
' "${config_files[@]}"; then
  fail "[Proxy] 中存在未经脱敏或未纳入校验器的代理定义"
fi

grep -q 'psk=YOUR_SNELL_PSK' "$scan_root/Shared.dconf" || fail "缺少 Snell PSK 占位符"
grep -q 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' "$scan_root/Shared.dconf" || fail "缺少订阅地址占位符"
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Shared.dconf" || fail "共享规则缺少预期 FINAL 兜底"
grep -q 'blackmatrix7/ios_rule_script@ccc2d6b711007324bacb55cdfbbf7e36ad48145a/' "$scan_root/Shared.dconf" || fail "微信规则未固定到审核过的上游提交"

for profile_name in Surge.conf iPhone.conf; do
  include_count=$(grep -c '^#!include Shared\.dconf$' "$scan_root/$profile_name" || true)
  [[ "$include_count" -eq 3 ]] || fail "$profile_name 必须在 Proxy、Proxy Group、Rule 各包含一次 Shared.dconf"
done

for module_name in bilibili.sgmodule youtube-enhance-bounded.sgmodule; do
  if ! awk -v limit=2097152 '
    /^[[:space:]]*#/ { next }
    /requires-body=(true|1)/ {
      value=$0
      if (value !~ /max-size=[0-9]+/) exit 1
      sub(/^.*max-size=/, "", value)
      sub(/,.*/, "", value)
      if ((value + 0) > limit) exit 1
    }
  ' "$scan_root/$module_name"; then
    fail "$module_name 存在无正文上限或超过 2 MiB 的脚本"
  fi
done

if grep -q 'script-path=https://raw.githubusercontent.com/Maasea/sgmodule/master/' "$scan_root/youtube-enhance-bounded.sgmodule"; then
  fail "YouTube 可执行脚本仍跟随 master"
fi

script_manifest="$repo_root/scripts/remote-assets.sha256"
while IFS= read -r script_url; do
  case "$script_url" in
    https://raw.githubusercontent.com/Maasea/sgmodule/65075cdb388fc5e3094afd7e7314c67b243f3525/*)
      ;;
    https://kelee.one/*)
      grep -Fq "  $script_url" "$script_manifest" || fail "Bilibili 远程脚本缺少完整性清单: $script_url"
      ;;
    *)
      fail "发现未固定或未监控的可执行脚本: $script_url"
      ;;
  esac
done < <(grep -hEo 'script-path=https://[^,[:space:]]+' "$scan_root"/*.sgmodule | sed 's/^script-path=//' | sort -u)

if command -v surge-cli >/dev/null 2>&1; then
  surge-cli --check "$scan_root/Surge.conf" >/dev/null
  surge-cli --check "$scan_root/iPhone.conf" >/dev/null
elif [[ -x /Applications/Surge.app/Contents/Applications/surge-cli ]]; then
  /Applications/Surge.app/Contents/Applications/surge-cli --check "$scan_root/Surge.conf" >/dev/null
  /Applications/Surge.app/Contents/Applications/surge-cli --check "$scan_root/iPhone.conf" >/dev/null
else
  echo "提示: 当前平台没有 surge-cli，已跳过官方语法检查"
fi

if [[ "$scan_history" == true ]]; then
  git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null
  while IFS= read -r revision; do
    if git -C "$repo_root" grep -I -E '^[[:space:]]*(ca-p12|ca-passphrase)[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含 MITM 私钥材料"
    fi
    if git -C "$repo_root" grep -I -E -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}' "$revision" 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含私钥或平台访问令牌"
    fi
    if git -C "$repo_root" grep -I -E 'psk=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'psk=YOUR_SNELL_PSK' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 PSK"
    fi
    if git -C "$repo_root" grep -I -E 'policy-path=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位订阅地址"
    fi
  done < <(git -C "$repo_root" rev-list --all)
fi

echo "公开配置校验通过"
