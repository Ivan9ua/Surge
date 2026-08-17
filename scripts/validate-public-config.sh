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

required_files=(Surge.conf iPhone.conf Shared.dconf bilibili.sgmodule youtube-enhance-bounded.sgmodule youtube-enhance.qxrewrite bilibili-enhance.qxrewrite wechat-direct.list wechat-ip.list)
for config_file in "${required_files[@]}"; do
  [[ -f "$scan_root/$config_file" ]] || { echo "缺少文件: $config_file" >&2; exit 1; }
done

fail() {
  echo "校验失败: $*" >&2
  exit 1
}

config_files=("$scan_root/Surge.conf" "$scan_root/iPhone.conf" "$scan_root/Shared.dconf")
all_public_files=("${config_files[@]}" "$scan_root/bilibili.sgmodule" "$scan_root/youtube-enhance-bounded.sgmodule" "$scan_root/youtube-enhance.qxrewrite" "$scan_root/bilibili-enhance.qxrewrite" "$scan_root/wechat-direct.list" "$scan_root/wechat-ip.list")

if grep -nE -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----' "${all_public_files[@]}" >/dev/null; then
  fail "发现 PEM 私钥材料"
fi

if grep -nE '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16})' "${all_public_files[@]}" >/dev/null; then
  fail "发现疑似平台访问令牌"
fi

if grep -nEi '^[[:space:]]*(ca-p12|ca-passphrase)[[:space:]]*=' "${config_files[@]}" >/dev/null; then
  fail "发现 MITM 私钥或口令字段"
fi

if grep -nEi '^[[:space:]]*(private-key|http-api|external-controller-access|wifi-access-password)[[:space:]]*=' "${config_files[@]}" >/dev/null; then
  fail "发现私钥或远程访问凭据字段"
fi

if grep -nEi '^[[:space:]]*secret[[:space:]]*=' "${config_files[@]}" | grep -v 'secret = 00000000000000000000000000000000' >/dev/null; then
  fail "发现非占位 MTProto secret"
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
grep -q '^secret = 00000000000000000000000000000000$' "$scan_root/Surge.conf" || fail "Mac 模板缺少 MTProto secret 占位符"
grep -q '^secret = 00000000000000000000000000000000$' "$scan_root/iPhone.conf" || fail "iPhone 模板缺少 MTProto secret 占位符"
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Shared.dconf" || fail "共享规则缺少预期 FINAL 兜底"
grep -Eq 'Ivan9ua/Surge@main/wechat-direct\.list,DIRECT$' "$scan_root/Shared.dconf" || fail "微信域名规则未指向 Ivan9ua/Surge@main"
grep -Eq 'Ivan9ua/Surge@main/wechat-ip\.list,DIRECT$' "$scan_root/Shared.dconf" || fail "微信 IP 规则未指向 Ivan9ua/Surge@main"
grep -q '^PROTOCOL,MTProto,Telegram$' "$scan_root/Shared.dconf" || fail "缺少 MTProto 入站分流"
if grep -q 'telegram_asn\.conf' "$scan_root/Shared.dconf"; then
  fail "仍在使用高风险 Telegram ASN 规则"
fi
grep -q '^RULE-SET,https://ruleset-mirror\.skk\.moe/List/ip/china_ip_ipv6\.conf,DIRECT$' "$scan_root/Shared.dconf" || fail "中国 IPv6 规则未同时覆盖 Mac 与 iPhone"
grep -q '^ipv6 = true$' "$scan_root/iPhone.conf" || fail "iPhone 模板未启用 IPv6"
grep -q '^ipv6-vif = auto$' "$scan_root/iPhone.conf" || fail "iPhone 模板未使用自动 IPv6 VIF"

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1 || true
}

ad_domain_line="$(line_of "$scan_root/Shared.dconf" 'List/domainset/reject.conf')"
wechat_domain_line="$(line_of "$scan_root/Shared.dconf" 'wechat-direct.list')"
ad_ip_line="$(line_of "$scan_root/Shared.dconf" 'List/ip/reject.conf')"
wechat_ip_line="$(line_of "$scan_root/Shared.dconf" 'wechat-ip.list')"
[[ -n "$ad_domain_line" && -n "$wechat_domain_line" && "$ad_domain_line" -lt "$wechat_domain_line" ]] || fail "微信域名规则破坏广告优先级"
[[ -n "$ad_ip_line" && -n "$wechat_ip_line" && "$ad_ip_line" -lt "$wechat_ip_line" ]] || fail "微信 IP 规则破坏广告优先级"

grep -q '^DOMAIN,slife\.xy-asia\.com$' "$scan_root/wechat-direct.list" || fail "微信域名补充规则缺少精确 slife 域名"
if grep -q '^DOMAIN-SUFFIX,xy-asia\.com$' "$scan_root/wechat-direct.list"; then
  fail "微信域名补充规则仍使用过宽 xy-asia.com 后缀"
fi
grep -q '^IP-ASN,132203,no-resolve$' "$scan_root/wechat-ip.list" || fail "微信 IP 规则缺少腾讯 ASN 132203"

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

qx_youtube="$scan_root/youtube-enhance.qxrewrite"
grep -Fq 'youtubei\.googleapis\.com\/youtubei\/v1\/(browse|next|player|search|reel\/reel_watch_sequence|guide|account\/get_setting|get_watch|log_event|config)' "$qx_youtube" || fail "Quantumult X YouTube 响应规则不完整"
grep -Fq 'googlevideo\.com\/initplayback.+&ack.* url script-request-body' "$qx_youtube" || fail "Quantumult X YouTube 缺少 initplayback 请求规则"
grep -Fq 'youtubei\.googleapis\.com\/youtubei\/v1\/log_event' "$qx_youtube" || fail "Quantumult X YouTube 缺少 log_event 请求规则"
grep -Fq 'hostname = %APPEND% *.googlevideo.com, youtubei.googleapis.com' "$qx_youtube" || fail "Quantumult X YouTube MITM 主机不完整"
if grep -q 'raw.githubusercontent.com/Maasea/sgmodule/\(master\|refs/heads/master\)/' "$qx_youtube"; then
  fail "Quantumult X YouTube 可执行脚本仍跟随 master"
fi

qx_bilibili="$scan_root/bilibili-enhance.qxrewrite"
grep -Fq 'app2smile/rules/5380447220ea3df4abee8b77dd118de9165631fa/js/bilibili-json.js' "$qx_bilibili" || fail "Quantumult X Bilibili JSON 脚本未固定到审核提交"
grep -Fq 'app2smile/rules/5890c30ff94aa619ed06ec4f343c609acb6bd461/js/bilibili-proto.js' "$qx_bilibili" || fail "Quantumult X Bilibili ProtoBuf 脚本未固定到审核提交"
grep -Fq 'hostname = %APPEND% grpc.biliapi.net, app.bilibili.com, api.bilibili.com, api.live.bilibili.com, line3-h5-mobile-api.biligame.com' "$qx_bilibili" || fail "Quantumult X Bilibili MITM 主机不完整"
if grep -Eqi 'github\.com/BiliUniverse|BiliUniverse/ADBlock|ADBlock/releases' "$qx_bilibili"; then
  fail "Quantumult X Bilibili 模块仍依赖 BiliUniverse"
fi

script_manifest="$repo_root/scripts/remote-assets.sha256"
while IFS= read -r script_url; do
  case "$script_url" in
    https://raw.githubusercontent.com/Maasea/sgmodule/65075cdb388fc5e3094afd7e7314c67b243f3525/*)
      ;;
    https://raw.githubusercontent.com/app2smile/rules/5380447220ea3df4abee8b77dd118de9165631fa/js/bilibili-json.js|https://raw.githubusercontent.com/app2smile/rules/5890c30ff94aa619ed06ec4f343c609acb6bd461/js/bilibili-proto.js)
      ;;
    https://kelee.one/*)
      grep -Fq "  $script_url" "$script_manifest" || fail "Bilibili 远程脚本缺少完整性清单: $script_url"
      ;;
    *)
      fail "发现未固定或未监控的可执行脚本: $script_url"
      ;;
  esac
done < <(
  {
    grep -hEo 'script-path=https://[^,[:space:]]+' "$scan_root"/*.sgmodule | sed 's/^script-path=//'
    grep -hEo 'url script-(request|response)-body https://[^[:space:]]+' "$scan_root"/*.qxrewrite | awk '{print $NF}'
  } | sort -u
)

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
    if git -C "$repo_root" grep -I -E '^[[:space:]]*secret[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'secret = 00000000000000000000000000000000' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 MTProto secret"
    fi
    if git -C "$repo_root" grep -I -E '^[[:space:]]*(private-key|http-api|external-controller-access|wifi-access-password)[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含私钥或远程访问凭据"
    fi
  done < <(git -C "$repo_root" rev-list --all)
fi

echo "公开配置校验通过"
