#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scan_root="$repo_root"
scan_history=false
history_ref='--all'

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
    --history-ref)
      [[ $# -ge 2 ]] || { echo "--history-ref 缺少 Git 引用" >&2; exit 2; }
      scan_history=true
      history_ref="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 2
      ;;
  esac
done

required_files=(Surge.conf iPhone.conf Shared-Routing.dconf Shared-General.dconf wechat.list)
for config_file in "${required_files[@]}"; do
  [[ -f "$scan_root/$config_file" ]] || { echo "缺少文件: $config_file" >&2; exit 1; }
done

fail() {
  echo "校验失败: $*" >&2
  exit 1
}

for config_file in "$scan_root"/*.conf "$scan_root"/*.dconf; do
  [[ -e "$config_file" ]] || continue
  case "$(basename "$config_file")" in
    Surge.conf|iPhone.conf|Shared-Routing.dconf|Shared-General.dconf) ;;
    *) fail "发现未纳入脱敏流程的配置文件: $(basename "$config_file")" ;;
  esac
done

config_files=("$scan_root/Surge.conf" "$scan_root/iPhone.conf" "$scan_root/Shared-Routing.dconf" "$scan_root/Shared-General.dconf")
all_public_files=("${config_files[@]}" "$scan_root/wechat.list")

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

for config_file in "${config_files[@]}"; do
  if grep -nEi '^[[:space:]]*(ca-p12|ca-passphrase|ca-keystore-name)[[:space:]]*=|^[[:space:]]*\[Keystore\][[:space:]]*$|type[[:space:]]*=[[:space:]]*p12.*base64[[:space:]]*=' "$config_file" >/dev/null; then
    fail "$(basename "$config_file") 含 MITM Keystore、私钥或口令字段"
  fi
done

if grep -nEi '^[[:space:]]*(private-key|http-api|external-controller-access|wifi-access-password)[[:space:]]*=' "${config_files[@]}" >/dev/null; then
  fail "发现私钥或远程访问凭据字段"
fi

if grep -nEi '^[[:space:]]*secret[[:space:]]*=' "${config_files[@]}" | grep -v 'secret = 00000000000000000000000000000000' >/dev/null; then
  fail "发现非占位 MTProto secret"
fi

if grep -nE 'psk=' "${config_files[@]}" | grep -v 'psk=YOUR_SNELL_PSK' >/dev/null; then
  fail "发现非占位 Snell PSK"
fi

if grep -nE 'password=' "${config_files[@]}" | grep -v 'password=YOUR_PROXY_PASSWORD' >/dev/null; then
  fail "发现非占位代理密码"
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
    if ($0 !~ /= *snell, *example\.com, *8388, *psk=YOUR_SNELL_PSK,/ &&
        $0 !~ /= *hysteria2, *example\.com, *443, *password=YOUR_PROXY_PASSWORD,.*sni=example\.com/) bad=1
  }
  END { exit bad }
' "${config_files[@]}"; then
  fail "[Proxy] 中存在未经脱敏或未纳入校验器的代理定义"
fi

if ! grep -qE '(psk=YOUR_SNELL_PSK|password=YOUR_PROXY_PASSWORD)' "$scan_root/Shared-Routing.dconf"; then
  fail "缺少受支持的代理凭据占位符"
fi
if ! awk '
  /= *(snell|hysteria2|anytls),/ {
    if ($0 ~ /= *snell,/ && $0 !~ /= *snell, *example\.com, *8388, *psk=YOUR_SNELL_PSK,/) bad=1
    if ($0 ~ /= *(hysteria2|anytls),/ && $0 !~ /= *(hysteria2|anytls), *example\.com, *443, *password=YOUR_PROXY_PASSWORD,/) bad=1
  }
  END { exit bad }
' "$scan_root/Shared-Routing.dconf"; then
  fail "代理定义或注释示例仍含真实地址或凭据"
fi
grep -q 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' "$scan_root/Shared-Routing.dconf" || fail "缺少订阅地址占位符"
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Shared-Routing.dconf" || fail "共享规则缺少预期 FINAL 兜底"
if grep -qE 'List/non_ip/apple_cdn\.conf' "$scan_root/Shared-Routing.dconf"; then
  fail "规则地址仍使用已废弃的 Apple CDN 路径"
fi
grep -qFx 'DOMAIN-SET,https://ruleset.skk.moe/List/domainset/apple_cdn.conf,DIRECT' "$scan_root/Shared-Routing.dconf" || fail "Apple CDN 地址或匹配方式与本地决定不一致"
for download_type in domainset non_ip; do
  grep -qE "^.+,https://ruleset\.skk\.moe/List/$download_type/download\.conf,Proxy$" "$scan_root/Shared-Routing.dconf" || fail "通用下载未映射到 Proxy"
done
wechat_reference_regex='^RULE-SET,https://(raw\.githubusercontent\.com/Ivan9ua/Surge/[0-9a-f]{40}/wechat\.list|cdn\.jsdelivr\.net/gh/Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list),DIRECT,(no-resolve,extended-matching|extended-matching,no-resolve)$'
grep -Eq "$wechat_reference_regex" "$scan_root/Shared-Routing.dconf" || fail "微信统一规则未固定到完整提交或缺少 no-resolve,extended-matching"
[[ "$(grep -cE 'Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list' "$scan_root/Shared-Routing.dconf")" -eq 1 ]] || fail "微信统一规则必须且只能引用一次"
if grep -Eq 'wechat-(direct|exception|ip)\.list' "$scan_root/Shared-Routing.dconf"; then
  fail "共享规则仍引用旧版微信拆分规则"
fi
if grep -q '^PROTOCOL,MTProto,Telegram$' "$scan_root/Shared-Routing.dconf"; then
  fail "共享规则仍含已删除的 MTProto 入站分流"
fi
telegram_cidr_line=$(grep -nFx 'RULE-SET,https://ruleset.skk.moe/List/ip/telegram.conf,Telegram' "$scan_root/Shared-Routing.dconf" | cut -d: -f1 || true)
telegram_asn_line=$(grep -nFx 'RULE-SET,https://ruleset.skk.moe/List/ip/telegram_asn.conf,Telegram' "$scan_root/Shared-Routing.dconf" | cut -d: -f1 || true)
[[ -n "$telegram_cidr_line" ]] || fail "缺少 Telegram 官方 CIDR 规则"
if [[ -n "$telegram_asn_line" && "$telegram_cidr_line" -ge "$telegram_asn_line" ]]; then
  fail "Telegram ASN 补充须位于官方 CIDR 之后并使用同一策略"
fi
for domestic_ip in lan domestic china_ip china_ip_ipv6; do
  grep -qFx "RULE-SET,https://ruleset.skk.moe/List/ip/$domestic_ip.conf,DIRECT" "$scan_root/Shared-Routing.dconf" || fail "国内或内网 IP 兜底应允许解析: $domestic_ip"
done
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/ai.conf,Intelligence,extended-matching' "$scan_root/Shared-Routing.dconf" || fail "AI 规则缺少扩展匹配"
for ip_policy in 'reject REJECT-DROP' 'telegram Telegram' 'stream Stream' 'ai Intelligence' 'neteasemusic DIRECT'; do
  read -r ip_name ip_route <<< "$ip_policy"
  grep -qFx "RULE-SET,https://ruleset.skk.moe/List/ip/$ip_name.conf,$ip_route" "$scan_root/Shared-Routing.dconf" || fail "专项 IP 参数与最新本地不一致: $ip_name"
done
grep -q '^ipv6 = true$' "$scan_root/Shared-General.dconf" || fail "共享 General 未启用 IPv6"
grep -q '^ipv6-vif = auto$' "$scan_root/Shared-General.dconf" || fail "共享 General 未使用自动 IPv6 VIF"
if grep -qE '^ipv6(-vif)?[[:space:]]*=' "$scan_root/Surge.conf" "$scan_root/iPhone.conf"; then
  fail "设备入口不应重复覆盖共享 IPv6 设置"
fi
if grep -Eq '^[[:space:]]*show-error-page-for-reject[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$scan_root/Shared-General.dconf"; then
  fail "共享 General 显式启用了 REJECT 普通 HTTP 错误页"
fi
if grep -Eio 'https://[a-z0-9.-]+\.alidns\.com' "${all_public_files[@]}" | grep -Eiv 'https://dns\.alidns\.com$' >/dev/null; then
  fail "发现未脱敏的个人 AliDNS 地址"
fi
grep -q '^icmp-forwarding = true$' "$scan_root/Surge.conf" || fail "Mac 模板缺少 macOS 专用 ICMP 转发"
if grep -q '^icmp-forwarding' "$scan_root/iPhone.conf" "$scan_root/Shared-General.dconf"; then
  fail "icmp-forwarding 不应进入 iPhone 或共享 General 配置"
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
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject-drop.conf,REJECT-DROP,pre-matching #!MACOS-ONLY'
  'DOMAIN-SET,https://ruleset.skk.moe/List/domainset/reject.conf,REJECT,extended-matching #!MACOS-ONLY'
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject.conf,REJECT,extended-matching #!MACOS-ONLY'
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject-no-drop.conf,REJECT-NO-DROP,extended-matching #!MACOS-ONLY'
)
for required_rule in "${required_platform_ad_rules[@]}"; do
  grep -qFx -- "$required_rule" "$scan_root/Shared-Routing.dconf" || fail "平台广告规则缺失或条件异常: $required_rule"
done

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1 || true
}

ad_domain_line="$(line_of "$scan_root/Shared-Routing.dconf" 'List/domainset/reject.conf')"
wechat_line="$(line_of "$scan_root/Shared-Routing.dconf" 'wechat.list')"
[[ -n "$ad_domain_line" && -n "$wechat_line" && "$ad_domain_line" -lt "$wechat_line" ]] || fail "微信统一规则未置于广告规则之后"
for ad_rule in 'List/non_ip/reject.conf' 'List/non_ip/reject-no-drop.conf'; do
  ad_line="$(line_of "$scan_root/Shared-Routing.dconf" "$ad_rule")"
  [[ -n "$ad_line" && "$ad_line" -lt "$wechat_line" ]] || fail "微信统一规则须保留广告优先: $ad_rule"
done
if grep -qE '^DOMAIN,sg(minor)?short\.wechat\.com,' "$scan_root/Shared-Routing.dconf"; then
  fail "微信端点已并入统一规则集，不应保留独立规则"
fi
ordered_routes=(
  'List/domainset/cdn.conf' 'List/non_ip/cdn.conf'
  'List/non_ip/stream.conf' 'List/non_ip/telegram.conf'
  'List/domainset/apple_cdn.conf' 'List/non_ip/microsoft_cdn.conf'
  'List/domainset/download.conf' 'List/non_ip/download.conf'
  'List/non_ip/apple_cn.conf' 'List/non_ip/apple_services.conf' 'List/non_ip/microsoft.conf'
  'List/non_ip/ai.conf' 'List/non_ip/apple_intelligence.conf' 'List/non_ip/global.conf'
  'List/non_ip/neteasemusic.conf' 'wechat.list'
  'List/non_ip/domestic.conf' 'List/non_ip/direct.conf' 'List/non_ip/lan.conf'
  'List/ip/reject.conf' 'List/ip/telegram.conf' 'List/ip/stream.conf' 'List/ip/ai.conf'
  'List/ip/neteasemusic.conf' 'List/ip/lan.conf' 'List/ip/domestic.conf'
  'List/ip/china_ip.conf' 'List/ip/china_ip_ipv6.conf' 'PROCESS-NAME,WeChat,' 'FINAL,Proxy,dns-failed'
)
previous_route_line=0
for route in "${ordered_routes[@]}"; do
  route_line="$(line_of "$scan_root/Shared-Routing.dconf" "$route")"
  [[ -n "$route_line" && "$route_line" -gt "$previous_route_line" ]] || fail "规则排序异常: $route"
  previous_route_line="$route_line"
done
wechat_ref_count="$(grep -c 'wechat\.list' "$scan_root/Shared-Routing.dconf" || true)"
[[ "$wechat_ref_count" -eq 1 ]] || fail "微信统一规则必须仅保留一条远程引用"
if grep -qE 'WeChat_Resolve\.list|blackmatrix7/.*/WeChat' "$scan_root/Shared-Routing.dconf"; then
  fail "不得直接引用 Blackmatrix7 WeChat 或 WeChat_Resolve 规则"
fi

required_wechat_direct_rules=(
  'DOMAIN-SUFFIX,wechat.com'
  'DOMAIN,slife.xy-asia.com'
  'DOMAIN,apd-pcdnwxlogin.teg.tencent-cloud.net'
  'DOMAIN,dldir1.qq.com'
  'DOMAIN,soup.v.qq.com'
  'DOMAIN,weixin110.qq.com'
  'DOMAIN-SUFFIX,weixin.com'
  'DOMAIN-SUFFIX,weixinbridge.com'
  'DOMAIN-SUFFIX,wechatpay.cn'
  'DOMAIN-SUFFIX,wxapp.tc.qq.com'
  'DOMAIN-SUFFIX,map.qq.com'
)
for required_rule in "${required_wechat_direct_rules[@]}"; do
  grep -qF -- "$required_rule" "$scan_root/wechat.list" || fail "微信统一规则缺少域名: $required_rule"
done
required_wechat_exclusions=(
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
if grep -qFx 'DOMAIN,wup.imtt.qq.com' "$scan_root/wechat.list"; then
  fail "wup.imtt.qq.com 与广告规则冲突，不应加入微信直连"
fi
if grep -qE 'sg(minor)?short\.wechat\.com' "$scan_root/wechat.list"; then
  fail "微信统一规则仍含过时的海外端点排除或重复精确条目"
fi
if grep -qE '^(IP-CIDR|IP-CIDR6|IP-ASN|DOMAIN-KEYWORD|USER-AGENT),' "$scan_root/wechat.list"; then
  fail "微信统一规则不应使用静态 IP、ASN、顶层 DOMAIN-KEYWORD 或 USER-AGENT"
fi
wechat_rule_count="$(grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/wechat.list" | wc -l | tr -d ' ')"
[[ "$wechat_rule_count" -eq 32 ]] || fail "微信统一规则数量异常: $wechat_rule_count（预期 32）"

for profile_name in Surge.conf iPhone.conf; do
  include_count=$(grep -c '^#!include Shared-Routing\.dconf$' "$scan_root/$profile_name" || true)
  [[ "$include_count" -eq 3 ]] || fail "$profile_name 必须在 Proxy、Proxy Group、Rule 各包含一次 Shared-Routing.dconf"
  general_include_count=$(grep -c '^#!include Shared-General\.dconf$' "$scan_root/$profile_name" || true)
  [[ "$general_include_count" -eq 1 ]] || fail "$profile_name 必须在 General 包含一次 Shared-General.dconf"
done

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
    if git -C "$repo_root" grep -I -E '^[[:space:]]*(ca-p12|ca-passphrase|ca-keystore-name)[[:space:]]*=|^[[:space:]]*\[Keystore\][[:space:]]*$|type[[:space:]]*=[[:space:]]*p12.*base64[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含 MITM Keystore 或私钥材料"
    fi
    if git -C "$repo_root" grep -I -E -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}' "$revision" 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含私钥或平台访问令牌"
    fi
    if git -C "$repo_root" grep -I -E 'psk=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'psk=YOUR_SNELL_PSK' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 PSK"
    fi
    if git -C "$repo_root" grep -I -E 'password=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'password=YOUR_PROXY_PASSWORD' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位代理密码"
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
  done < <(git -C "$repo_root" rev-list "$history_ref")
fi

echo "公开配置校验通过"
