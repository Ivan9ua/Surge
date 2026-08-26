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

required_files=(Surge.conf iPhone.conf Shared-Routing.dconf Shared-General.dconf bilibili.sgmodule youtube-enhance-bounded.sgmodule wechat.list)
for config_file in "${required_files[@]}"; do
  [[ -f "$scan_root/$config_file" ]] || { echo "缺少文件: $config_file" >&2; exit 1; }
done

fail() {
  echo "校验失败: $*" >&2
  exit 1
}

config_files=("$scan_root/Surge.conf" "$scan_root/iPhone.conf" "$scan_root/Shared-Routing.dconf" "$scan_root/Shared-General.dconf")
all_public_files=("${config_files[@]}" "$scan_root/bilibili.sgmodule" "$scan_root/youtube-enhance-bounded.sgmodule" "$scan_root/wechat.list")

forbidden_extension='.'q'xrewrite'
if find "$scan_root" -maxdepth 1 -type f -name "*$forbidden_extension" -print -quit | grep -q .; then
  fail "发现不应发布的 $forbidden_extension 文件"
fi

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

grep -q 'psk=YOUR_SNELL_PSK' "$scan_root/Shared-Routing.dconf" || fail "缺少 Snell PSK 占位符"
grep -q 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' "$scan_root/Shared-Routing.dconf" || fail "缺少订阅地址占位符"
grep -q '^secret = 00000000000000000000000000000000$' "$scan_root/Surge.conf" || fail "Mac 模板缺少 MTProto secret 占位符"
grep -q '^secret = 00000000000000000000000000000000$' "$scan_root/iPhone.conf" || fail "iPhone 模板缺少 MTProto secret 占位符"
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Shared-Routing.dconf" || fail "共享规则缺少预期 FINAL 兜底"
grep -Eq 'Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list,DIRECT,no-resolve,extended-matching$' "$scan_root/Shared-Routing.dconf" || fail "微信统一规则未固定到完整提交或缺少 no-resolve,extended-matching"
[[ "$(grep -cE 'Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list' "$scan_root/Shared-Routing.dconf")" -eq 1 ]] || fail "微信统一规则必须且只能引用一次"
if grep -Eq 'wechat-(direct|exception|ip)\.list' "$scan_root/Shared-Routing.dconf"; then
  fail "共享规则仍引用旧版微信拆分规则"
fi
grep -q '^PROTOCOL,MTProto,Telegram$' "$scan_root/Shared-Routing.dconf" || fail "缺少 MTProto 入站分流"
if grep -q 'telegram_asn\.conf' "$scan_root/Shared-Routing.dconf"; then
  fail "仍在使用高风险 Telegram ASN 规则"
fi
grep -q '^RULE-SET,https://ruleset-mirror\.skk\.moe/List/ip/china_ip_ipv6\.conf,DIRECT$' "$scan_root/Shared-Routing.dconf" || fail "中国 IPv6 规则未同时覆盖 Mac 与 iPhone"
grep -q '^ipv6 = true$' "$scan_root/Shared-General.dconf" || fail "共享 General 未启用 IPv6"
grep -q '^ipv6-vif = auto$' "$scan_root/Shared-General.dconf" || fail "共享 General 未使用自动 IPv6 VIF"
grep -q '^icmp-forwarding = true #!MACOS-ONLY$' "$scan_root/Shared-General.dconf" || fail "共享 General 缺少仅 macOS 的 ICMP 转发"
if grep -q '^icmp-forwarding' "$scan_root/Surge.conf" "$scan_root/iPhone.conf"; then
  fail "主配置不应直接包含 icmp-forwarding，应统一放在 Shared-General.dconf"
fi

if grep -q 'abcchina\.com' "$scan_root/Shared-General.dconf"; then
  fail "共享 General 仍含已移除的农行 skip-proxy 项"
fi

if awk '
  BEGIN { in_group=0; bad=0 }
  /^\[Proxy Group\][[:space:]]*$/ { in_group=1; next }
  /^\[/ { in_group=0 }
  in_group && /^[[:space:]]*[^#;]/ && /= *(smart|select),/ && /(^|,[[:space:]]*)no-alert=/ { bad=1 }
  END { exit bad ? 0 : 1 }
' "$scan_root/Shared-Routing.dconf"; then
  fail "Smart/select 策略组仍含无效 no-alert 参数"
fi

required_platform_ad_rules=(
  'RULE-SET,https://ruleset-mirror.skk.moe/List/non_ip/reject-drop.conf,REJECT-DROP,pre-matching #!IOS-ONLY'
  'DOMAIN-SET,https://ruleset-mirror.skk.moe/List/domainset/reject.conf,REJECT #!IOS-ONLY'
  'DOMAIN-SET,https://ruleset-mirror.skk.moe/List/domainset/reject.conf,REJECT,extended-matching #!MACOS-ONLY'
  'RULE-SET,https://ruleset-mirror.skk.moe/List/non_ip/reject.conf,REJECT,extended-matching #!MACOS-ONLY'
  'RULE-SET,https://ruleset-mirror.skk.moe/List/non_ip/reject-no-drop.conf,REJECT-NO-DROP,extended-matching #!MACOS-ONLY'
)
for required_rule in "${required_platform_ad_rules[@]}"; do
  grep -qFx -- "$required_rule" "$scan_root/Shared-Routing.dconf" || fail "平台广告规则缺失或条件异常: $required_rule"
done

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1 || true
}

ad_domain_line="$(line_of "$scan_root/Shared-Routing.dconf" 'List/domainset/reject.conf')"
wechat_line="$(line_of "$scan_root/Shared-Routing.dconf" 'wechat.list')"
[[ -n "$ad_domain_line" && -n "$wechat_line" && "$wechat_line" -lt "$ad_domain_line" ]] || fail "微信统一规则未置于广告规则之前"

required_wechat_direct_rules=(
  'DOMAIN,slife.xy-asia.com'
  'DOMAIN,apd-pcdnwxlogin.teg.tencent-cloud.net'
  'DOMAIN,dldir1.qq.com'
  'DOMAIN,soup.v.qq.com'
  'DOMAIN,weixin110.qq.com'
  'DOMAIN-SUFFIX,weixin.com'
  'DOMAIN-SUFFIX,weixinbridge.com'
  'DOMAIN-SUFFIX,wxapp.tc.qq.com'
  'DOMAIN-SUFFIX,map.qq.com'
)
for required_rule in "${required_wechat_direct_rules[@]}"; do
  grep -qF -- "$required_rule" "$scan_root/wechat.list" || fail "微信统一规则缺少域名: $required_rule"
done
required_wechat_exclusions=(
  'AND,((DOMAIN-SUFFIX,wechat.com),(NOT,((DOMAIN,sgminorshort.wechat.com))),(NOT,((DOMAIN,sgshort.wechat.com))))'
  'AND,((DOMAIN-SUFFIX,weixin.qq.com),(NOT,((DOMAIN,dns.weixin.qq.com))),(NOT,((DOMAIN,udns.weixin.qq.com))),(NOT,((DOMAIN,aedns.weixin.qq.com))))'
  'AND,((DOMAIN-SUFFIX,weixin.qq.com.cn),(NOT,((DOMAIN,dns.weixin.qq.com.cn))))'
  'AND,((DOMAIN-SUFFIX,wxs.qq.com),(NOT,((DOMAIN-KEYWORD,wxsnsdy))))'
)
for required_rule in "${required_wechat_exclusions[@]}"; do
  grep -qFx -- "$required_rule" "$scan_root/wechat.list" || fail "微信统一规则缺少广告或 DNS 排除: $required_rule"
done
if grep -q '^DOMAIN-SUFFIX,xy-asia\.com$' "$scan_root/wechat.list"; then
  fail "微信域名补充规则仍使用过宽 xy-asia.com 后缀"
fi
grep -qFx 'AND,((DOMAIN-SUFFIX,wechat.com),(NOT,((DOMAIN,sgminorshort.wechat.com))),(NOT,((DOMAIN,sgshort.wechat.com))))' "$scan_root/wechat.list" || fail "微信统一规则未精确排除海外控制域名"
if grep -qE '^(IP-CIDR|IP-CIDR6|IP-ASN|DOMAIN-KEYWORD),' "$scan_root/wechat.list"; then
  fail "微信统一规则不应使用静态 IP、ASN 或顶层 DOMAIN-KEYWORD"
fi
wechat_rule_count="$(grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/wechat.list" | wc -l | tr -d ' ')"
[[ "$wechat_rule_count" -eq 31 ]] || fail "微信统一规则数量异常: $wechat_rule_count（预期 31）"

for profile_name in Surge.conf iPhone.conf; do
  include_count=$(grep -c '^#!include Shared-Routing\.dconf$' "$scan_root/$profile_name" || true)
  [[ "$include_count" -eq 3 ]] || fail "$profile_name 必须在 Proxy、Proxy Group、Rule 各包含一次 Shared-Routing.dconf"
  general_include_count=$(grep -c '^#!include Shared-General\.dconf$' "$scan_root/$profile_name" || true)
  [[ "$general_include_count" -eq 1 ]] || fail "$profile_name 必须在 General 包含一次 Shared-General.dconf"
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
