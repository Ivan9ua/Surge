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

required_files=(Surge.conf wechat.list quic-reject.list ai-extra.list)
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
    Surge.conf) ;;
    *) fail "发现未纳入脱敏流程的配置文件: $(basename "$config_file")" ;;
  esac
done

config_files=("$scan_root/Surge.conf")
all_public_files=("${config_files[@]}" "$scan_root/wechat.list" "$scan_root/quic-reject.list" "$scan_root/ai-extra.list")

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

if grep -nEi '^[[:space:]]*(private-key|http-api(-mcp|-tls|-web-dashboard)?|external-controller-access|wifi-access-password)[[:space:]]*=' "${config_files[@]}" >/dev/null; then
  fail "发现私钥或远程访问凭据字段"
fi

if grep -nEi '^[[:space:]]*secret[[:space:]]*=' "${config_files[@]}" | grep -v 'secret = 00000000000000000000000000000000' >/dev/null; then
  fail "发现非占位 MTProto secret"
fi

# 按字段检查，避免同一行的占位符掩盖真实凭据、UUID、REALITY 密钥或本机路径。
if grep -nE '/Users/' "${all_public_files[@]}" >/dev/null; then
  fail "发现本机用户目录路径"
fi

if grep -hEo '(psk|([[:alnum:]-]*password)|policy-path|username|reality-public-key|reality-short-id|addresses)[[:space:]]*=[[:space:]]*[^,#]*' "${config_files[@]}" |
  sed -E 's/[[:space:]]*=[[:space:]]*/=/; s/[[:space:]]+$//' |
  grep -Ev '^(psk=YOUR_SNELL_PSK|([[:alnum:]-]*password)=YOUR_PROXY_PASSWORD|policy-path=YOUR_SURGE_SUBSCRIPTION_URL|username=00000000-0000-0000-0000-000000000000|reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA|reality-short-id=00000000|addresses=198\.51\.100\.1)$' >/dev/null; then
  fail "发现非占位代理密码、PSK、VLESS 凭据、节点地址或订阅地址"
fi

if grep -nE '^[[:space:]]*[^#;].*exec[[:space:]]*=' "${config_files[@]}" |
  grep -Ev 'exec[[:space:]]*=[[:space:]]*"/path/to/external-proxy/start-client\.sh"' >/dev/null; then
  fail "发现非占位 external exec 路径"
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
        $0 !~ /= *hysteria2, *example\.com, *443, *password=YOUR_PROXY_PASSWORD,.*sni=example\.com/ &&
        $0 !~ /= *vless, *example\.com, *443, *username=00000000-0000-0000-0000-000000000000,.*sni=example\.com,.*reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA, *reality-short-id=00000000/ &&
        $0 !~ /= *external, *exec *= *"\/path\/to\/external-proxy\/start-client\.sh",.*addresses *= *198\.51\.100\.1/) bad=1
  }
  END { exit bad }
' "${config_files[@]}"; then
  fail "[Proxy] 中存在未经脱敏或未纳入校验器的代理定义"
fi

if ! grep -qE '(psk=YOUR_SNELL_PSK|password=YOUR_PROXY_PASSWORD|username=00000000-0000-0000-0000-000000000000)' "$scan_root/Surge.conf"; then
  fail "缺少受支持的代理凭据占位符"
fi
if ! awk '
  /= *(snell|hysteria2|anytls|vless|external),/ {
    if ($0 ~ /= *snell,/ && $0 !~ /= *snell, *example\.com, *8388, *psk=YOUR_SNELL_PSK,/) bad=1
    if ($0 ~ /= *(hysteria2|anytls),/ && $0 !~ /= *(hysteria2|anytls), *example\.com, *443, *password=YOUR_PROXY_PASSWORD,/) bad=1
    if ($0 ~ /= *vless,/ && $0 !~ /= *vless, *example\.com, *443, *username=00000000-0000-0000-0000-000000000000,.*sni=example\.com,.*reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA, *reality-short-id=00000000/) bad=1
    if ($0 ~ /= *external,/ && $0 !~ /= *external, *exec *= *"\/path\/to\/external-proxy\/start-client\.sh",.*addresses *= *198\.51\.100\.1/) bad=1
  }
  END { exit bad }
' "$scan_root/Surge.conf"; then
  fail "代理定义或注释示例仍含真实地址或凭据"
fi
grep -q 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' "$scan_root/Surge.conf" || fail "缺少订阅地址占位符"
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Surge.conf" || fail "共享规则缺少预期 FINAL 兜底"
if grep -qE 'List/non_ip/apple_cdn\.conf' "$scan_root/Surge.conf"; then
  fail "规则地址仍使用已废弃的 Apple CDN 路径"
fi
grep -qFx 'DOMAIN-SET,https://ruleset.skk.moe/List/domainset/cdn.conf,Proxy,extended-matching' "$scan_root/Surge.conf" || fail "CDN 域名集缺少扩展匹配"
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/cdn.conf,Proxy,extended-matching' "$scan_root/Surge.conf" || fail "CDN 规则集缺少扩展匹配"
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/stream.conf,Stream,extended-matching' "$scan_root/Surge.conf" || fail "流媒体规则集缺少扩展匹配"
grep -qFx 'DOMAIN-SET,https://ruleset.skk.moe/List/domainset/apple_cdn.conf,DIRECT' "$scan_root/Surge.conf" || fail "Apple CDN 地址或匹配方式与本地决定不一致"
grep -qFx 'DOMAIN,dl.wechat.com,DIRECT,extended-matching' "$scan_root/Surge.conf" || fail "缺少 dl.wechat.com 直连前置规则或缺少扩展匹配"
for download_type in domainset non_ip; do
  grep -qE "^.+,https://ruleset\.skk\.moe/List/$download_type/download\.conf,Proxy,extended-matching$" "$scan_root/Surge.conf" || fail "通用下载未映射到 Proxy 或缺少扩展匹配"
done
grep -qFx 'tun-included-routes = 169.254.169.254/32' "$scan_root/Surge.conf" || fail "缺少 169.254.169.254 VIF 精准纳入路由"
grep -qFx 'DOMAIN,metadata.google.internal,REJECT-NO-DROP,pre-matching' "$scan_root/Surge.conf" || fail "缺少 metadata.google.internal 预匹配拦截"
grep -qE '^IP-CIDR,169\.254\.169\.254/32,REJECT-NO-DROP,(no-resolve,pre-matching|pre-matching,no-resolve)$' "$scan_root/Surge.conf" || fail "缺少 169.254.169.254/32 预匹配拦截"
grep -qFx '169.254.169.254 = reject' "$scan_root/Surge.conf" || fail "缺少 [IP Rewrite] 169.254.169.254 拦截"
if grep -Eq '^[^#;]*quic-reject\.list|^AND,.*\(PROTOCOL,UDP\).*\(DEST-PORT,443\).*REJECT' "$scan_root/Surge.conf"; then
  fail "主配置仍含已撤回的自定义 QUIC 硬拒绝"
fi

wechat_reference_regex='^RULE-SET,https://(raw\.githubusercontent\.com/Ivan9ua/Surge/([0-9a-f]{40}|main)/wechat\.list|cdn\.jsdelivr\.net/gh/Ivan9ua/Surge@([0-9a-f]{40}|main)/wechat\.list),DIRECT,(no-resolve,extended-matching|extended-matching,no-resolve|extended-matching)$'
grep -Eq "$wechat_reference_regex" "$scan_root/Surge.conf" || fail "微信统一规则未引用或缺少 extended-matching"
[[ "$(grep -cE 'Ivan9ua/Surge(@main|/[0-9a-f]{40}|@([0-9a-f]{40}|main)|/main)/wechat\.list' "$scan_root/Surge.conf")" -eq 1 ]] || fail "微信统一规则必须且只能引用一次"
if grep -Eq 'wechat-(direct|exception|ip)\.list' "$scan_root/Surge.conf"; then
  fail "共享规则仍引用旧版微信拆分规则"
fi
if grep -q '^PROTOCOL,MTProto,Telegram$' "$scan_root/Surge.conf"; then
  fail "共享规则仍含已删除的 MTProto 入站分流"
fi
telegram_cidr_line=$(grep -nFx 'RULE-SET,https://ruleset.skk.moe/List/ip/telegram.conf,Telegram,no-resolve' "$scan_root/Surge.conf" | cut -d: -f1 || true)
telegram_asn_line=$(grep -nFx 'RULE-SET,https://ruleset.skk.moe/List/ip/telegram_asn.conf,Telegram,no-resolve' "$scan_root/Surge.conf" | cut -d: -f1 || true)
[[ -n "$telegram_cidr_line" ]] || fail "缺少 Telegram 官方 CIDR 规则"
if [[ -n "$telegram_asn_line" && "$telegram_cidr_line" -ge "$telegram_asn_line" ]]; then
  fail "Telegram ASN 补充须位于官方 CIDR 之后并使用同一策略"
fi
domestic_ip_list=(lan domestic china_ip)
if grep -q '^RULE-SET,https://ruleset.skk.moe/List/ip/china_ip_ipv6.conf,' "$scan_root/Surge.conf"; then
  domestic_ip_list+=(china_ip_ipv6)
fi
for domestic_ip in "${domestic_ip_list[@]}"; do
  grep -qFx "RULE-SET,https://ruleset.skk.moe/List/ip/$domestic_ip.conf,DIRECT" "$scan_root/Surge.conf" || fail "国内或内网 IP 兜底应允许解析: $domestic_ip"
done
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/ai.conf,Intelligence,extended-matching' "$scan_root/Surge.conf" || fail "AI 规则缺少扩展匹配"
grep -qFx 'RULE-SET,https://raw.githubusercontent.com/Ivan9ua/Surge/main/ai-extra.list,Intelligence,extended-matching' "$scan_root/Surge.conf" || fail "AI 补充引用缺失或参数异常"
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/domestic.conf,DIRECT,extended-matching' "$scan_root/Surge.conf" || fail "国内规则集缺少扩展匹配"
grep -qFx 'RULE-SET,https://ruleset.skk.moe/List/non_ip/direct.conf,DIRECT,extended-matching' "$scan_root/Surge.conf" || fail "直连规则集缺少扩展匹配"
if ! awk '
  /^[[:space:]]*(#|;|\/\/|$)/ { next }
  { count++; if ($0 !~ /^(DOMAIN|DOMAIN-SUFFIX),[a-z0-9.-]+$/ || seen[$0]++) bad=1 }
  END { exit (bad || count != 35) }
' "$scan_root/ai-extra.list"; then
  fail "AI 补充应为35条不重复的纯域名规则"
fi
if grep -Eq '^DOMAIN-SUFFIX,(auth0\.com|stripe\.com|googleapis\.com|microsoft\.com|facebook\.com|instagram\.com|whatsapp\.net)$' "$scan_root/ai-extra.list"; then
  fail "AI 补充含未经批准的宽泛共享服务"
fi
for ai_domain in \
  'DOMAIN-SUFFIX,muse.ai' \
  'DOMAIN-SUFFIX,metaaivm.com' \
  'DOMAIN-SUFFIX,copilot.microsoft.com' \
  'DOMAIN-SUFFIX,githubcopilot.com' \
  'DOMAIN,jetski-webchannel.googleapis.com' \
  'DOMAIN-SUFFIX,context7.com' \
  'DOMAIN-SUFFIX,perplexity.com' \
  'DOMAIN-SUFFIX,huggingface.co'; do
  grep -qFx "$ai_domain" "$scan_root/ai-extra.list" || fail "AI 补充缺少关键产品域名"
done
for ip_policy in 'reject REJECT-DROP,no-resolve' 'telegram Telegram,no-resolve' 'stream Stream,no-resolve' 'ai Intelligence,no-resolve' 'neteasemusic DIRECT'; do
  read -r ip_name ip_route <<< "$ip_policy"
  grep -qFx "RULE-SET,https://ruleset.skk.moe/List/ip/$ip_name.conf,$ip_route" "$scan_root/Surge.conf" || fail "专项 IP 参数与最新本地不一致: $ip_name"
done
if grep -qE 'US-Snell|US-Hysteria|Oracle-Xray|Tencent-Xray|Oracle-Hikyaku' "$scan_root/Surge.conf"; then
  fail "Surge.conf 节点名称尚未统一为公开别名"
fi
if grep -E '^always-real-ip[[:space:]]*=.*(^|,[[:space:]]*)(\*\.qpic\.cn|\*\.qlogo\.cn|\*\.weixin\.qq\.com|\*\.wechat\.com)([[:space:]]*,|$)' "$scan_root/Surge.conf" >/dev/null; then
  fail "Surge.conf always-real-ip 仍残留已移除的微信宽泛后缀"
fi
if grep -q '^ipv6 = true$' "$scan_root/Surge.conf"; then
  grep -q '^ipv6-vif = auto$' "$scan_root/Surge.conf" || fail "启用 IPv6 时共享 General 未使用自动 IPv6 VIF"
elif grep -q '^ipv6 = false$' "$scan_root/Surge.conf"; then
  grep -q '^ipv6-vif = disabled$' "$scan_root/Surge.conf" || fail "禁用 IPv6 时共享 General 未使用 disabled IPv6 VIF"
else
  fail "共享 General IPv6 设置异常"
fi
if grep -Eq '^[[:space:]]*show-error-page-for-reject[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$scan_root/Surge.conf"; then
  fail "共享 General 显式启用了 REJECT 普通 HTTP 错误页"
fi
if grep -h -Eio '[a-z0-9.-]+\.alidns\.com' "${all_public_files[@]}" | grep -Eiv '^dns\.alidns\.com$' >/dev/null; then
  fail "发现未脱敏的个人 AliDNS 地址"
fi
if grep -nE '^[[:space:]]*server-proxy-name[[:space:]]*=' "${config_files[@]}" | grep -v 'server-proxy-name= Hysteria' >/dev/null; then
  fail "发现非占位 Ponte server-proxy-name"
fi
grep -qFx 'hijack-dns = 8.8.8.8:53, 8.8.4.4:53' "$scan_root/Surge.conf" || fail "Surge.conf DNS 劫持项与当前共享配置不一致"
grep -q '^h2 = true$' "$scan_root/Surge.conf" || fail "Surge.conf 缺少 MITM h2 配置"
grep -q '^hostname-disabled = ' "$scan_root/Surge.conf" || fail "Surge.conf 缺少 MITM hostname-disabled 列表"
if grep -Eq '^\[Testing\]|^(download-duration-limit|upload-size-limit|upload-duration-limit)[[:space:]]*=' "$scan_root/Surge.conf"; then
  fail "主配置重新引入已删除的 Mac 测速段"
fi

if awk '
  BEGIN { in_group=0; bad=0 }
  /^\[Proxy Group\][[:space:]]*$/ { in_group=1; next }
  /^\[/ { in_group=0 }
  in_group && /^[[:space:]]*[^#;]/ && /= *(smart|select),/ && /(^|,[[:space:]]*)no-alert=/ { bad=1 }
  END { exit bad ? 0 : 1 }
' "$scan_root/Surge.conf"; then
  fail "Smart/select 策略组仍含无效 no-alert 参数"
fi

required_platform_ad_rules=(
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject-drop.conf,REJECT-DROP,pre-matching #!MACOS-ONLY'
  'DOMAIN-SET,https://ruleset.skk.moe/List/domainset/reject.conf,REJECT,pre-matching #!MACOS-ONLY'
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject.conf,REJECT,extended-matching'
  'RULE-SET,https://ruleset.skk.moe/List/non_ip/reject-no-drop.conf,REJECT-NO-DROP,extended-matching #!MACOS-ONLY'
)
for required_rule in "${required_platform_ad_rules[@]}"; do
  grep -qFx -- "$required_rule" "$scan_root/Surge.conf" || fail "平台广告规则缺失或条件异常: $required_rule"
done

line_of() {
  grep -nF "$2" "$1" | head -1 | cut -d: -f1 || true
}

reject_drop_line="$(line_of "$scan_root/Surge.conf" 'List/non_ip/reject-drop.conf')"
ad_domain_line="$(line_of "$scan_root/Surge.conf" 'List/domainset/reject.conf')"
wechat_line="$(line_of "$scan_root/Surge.conf" 'wechat.list')"
[[ -n "$reject_drop_line" && -n "$ad_domain_line" && "$reject_drop_line" -lt "$ad_domain_line" ]] || fail "广告规则 reject-drop.conf 须置于广告组首位，避免被前置 REJECT 降级"
[[ -n "$ad_domain_line" && -n "$wechat_line" && "$ad_domain_line" -lt "$wechat_line" ]] || fail "微信统一规则未置于广告规则之后"
for ad_rule in 'List/non_ip/reject.conf' 'List/non_ip/reject-no-drop.conf'; do
  ad_line="$(line_of "$scan_root/Surge.conf" "$ad_rule")"
  [[ -n "$ad_line" && "$ad_line" -lt "$wechat_line" ]] || fail "微信统一规则须保留广告优先: $ad_rule"
done
if grep -qE '^DOMAIN,sg(minor)?short\.wechat\.com,' "$scan_root/Surge.conf"; then
  fail "微信端点已并入统一规则集，不应保留独立规则"
fi
ordered_routes=(
  'DOMAIN,metadata.google.internal' 'IP-CIDR,169.254.169.254/32'
  'List/domainset/cdn.conf' 'List/non_ip/cdn.conf'
  'List/non_ip/stream.conf' 'List/non_ip/telegram.conf'
  'List/domainset/apple_cdn.conf' 'List/non_ip/microsoft_cdn.conf'
  'DOMAIN,dl.wechat.com,DIRECT,extended-matching'
  'List/domainset/download.conf' 'List/non_ip/download.conf'
  'ai-extra.list' 'List/non_ip/ai.conf' 'List/non_ip/apple_intelligence.conf'
  'List/non_ip/apple_cn.conf' 'List/non_ip/apple_services.conf' 'List/non_ip/microsoft.conf'
  'List/non_ip/global.conf'
  'List/non_ip/neteasemusic.conf' 'wechat.list'
  'List/non_ip/domestic.conf' 'List/non_ip/direct.conf' 'List/non_ip/lan.conf'
  'List/ip/reject.conf' 'List/ip/telegram.conf' 'List/ip/stream.conf' 'List/ip/ai.conf'
  'List/ip/neteasemusic.conf' 'List/ip/lan.conf' 'List/ip/domestic.conf'
  'List/ip/china_ip.conf'
)
if grep -q '^RULE-SET,https://ruleset.skk.moe/List/ip/china_ip_ipv6.conf,' "$scan_root/Surge.conf"; then
  ordered_routes+=('List/ip/china_ip_ipv6.conf')
fi
ordered_routes+=('PROCESS-NAME,WeChat,' 'PROCESS-NAME,WeChatAppEx,' 'PROCESS-NAME,XPlayer,' 'PROCESS-NAME,WeChatHelper,' 'FINAL,Proxy,dns-failed')
previous_route_line=0
for route in "${ordered_routes[@]}"; do
  route_line="$(line_of "$scan_root/Surge.conf" "$route")"
  [[ -n "$route_line" && "$route_line" -gt "$previous_route_line" ]] || fail "规则排序异常: $route"
  previous_route_line="$route_line"
done
wechat_ref_count="$(grep -c 'wechat\.list' "$scan_root/Surge.conf" || true)"
[[ "$wechat_ref_count" -eq 1 ]] || fail "微信统一规则必须仅保留一条远程引用"
if grep -qE 'WeChat_Resolve\.list|blackmatrix7/.*/WeChat' "$scan_root/Surge.conf"; then
  fail "不得直接引用 Blackmatrix7 WeChat 或 WeChat_Resolve 规则"
fi

required_wechat_direct_rules=(
  'DOMAIN-SUFFIX,wechat.com'
  'DOMAIN-SUFFIX,servicewechat.com'
  'DOMAIN-SUFFIX,wxgateway.com'
  'DOMAIN-SUFFIX,wechatlegal.net'
  'DOMAIN-SUFFIX,tenpay.com'
  'DOMAIN-SUFFIX,wechatpay.com'
  'DOMAIN-SUFFIX,wechatpay.cn'
  'DOMAIN-SUFFIX,wecom.work'
  'DOMAIN-SUFFIX,wetype.cn'
  'DOMAIN-SUFFIX,iot-tencent.com'
  'DOMAIN,slife.xy-asia.com'
)
for required_rule in "${required_wechat_direct_rules[@]}"; do
  grep -qFx -- "$required_rule" "$scan_root/wechat.list" || fail "微信统一规则缺少域名: $required_rule"
done
if grep -q '^DOMAIN-SUFFIX,xy-asia\.com$' "$scan_root/wechat.list"; then
  fail "微信域名补充规则仍使用过宽 xy-asia.com 后缀"
fi
if grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/wechat.list" | grep -Eq '(wup\.imtt\.qq\.com|apd-pcdnwxlogin\.teg\.tencent-cloud\.net|soup\.v\.qq\.com|up-hl\.3g\.qq\.com|yun-hl\.3g\.qq\.com|wxs\.qq\.com)'; then
  fail "微信规则含与 Sukka 广告拦截冲突的域名，不应加入微信直连"
fi
if grep -qE 'sg(minor)?short\.wechat\.com' "$scan_root/wechat.list"; then
  fail "微信统一规则仍含过时的海外端点排除或重复精确条目"
fi
if grep -qE '^(IP-CIDR|IP-CIDR6|IP-ASN|DOMAIN-KEYWORD|USER-AGENT|AND),' "$scan_root/wechat.list"; then
  fail "微信统一规则不应使用逻辑规则、静态 IP、ASN、顶层 DOMAIN-KEYWORD 或 USER-AGENT"
fi
wechat_rule_count="$(grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/wechat.list" | wc -l | tr -d ' ')"
[[ "$wechat_rule_count" -eq 11 ]] || fail "微信统一规则数量异常: $wechat_rule_count（预期 11）"
if ! awk '
  /^[[:space:]]*(#|;|\/\/|$)/ { next }
  {
    count++
    if ($0 !~ /^(DOMAIN|DOMAIN-SUFFIX),[a-z0-9.-]+$/) bad=1
    if (seen[$0]++) bad=1
  }
  END { exit (bad || count != 11) }
' "$scan_root/wechat.list"; then
  fail "微信统一规则格式异常、存在重复或条目数量异常"
fi

if grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/quic-reject.list" >/dev/null; then
  fail "已停用的 QUIC 兼容地址不得包含有效规则"
fi

if grep -qE '^[[:space:]]*#!include[[:space:]]' "$scan_root/Surge.conf"; then
  fail "主配置必须独立完整，不能引用分离配置"
fi
for process in WeChat WeChatAppEx XPlayer WeChatHelper; do
  grep -qFx "PROCESS-NAME,$process,DIRECT #!MACOS-ONLY" "$scan_root/Surge.conf" || fail "微信进程兜底缺失或未隔离: $process"
done

if command -v surge-cli >/dev/null 2>&1; then
  surge-cli --check "$scan_root/Surge.conf" >/dev/null
elif [[ -x /Applications/Surge.app/Contents/Applications/surge-cli ]]; then
  /Applications/Surge.app/Contents/Applications/surge-cli --check "$scan_root/Surge.conf" >/dev/null
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
    if git -C "$repo_root" grep -I -E 'username[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'username=00000000-0000-0000-0000-000000000000' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 VLESS username"
    fi
    if git -C "$repo_root" grep -I -E 'reality-public-key[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 REALITY 公钥"
    fi
    if git -C "$repo_root" grep -I -E 'reality-short-id[[:space:]]*=' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -v 'reality-short-id=00000000' | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含非占位 REALITY short-id"
    fi
    if git -C "$repo_root" grep -I -E 'exec[[:space:]]*=.*\/Users\/|/Users/' "$revision" -- '*.conf' '*.dconf' 2>/dev/null | grep -q .; then
      fail "Git 历史提交 ${revision:0:12} 含本机用户路径"
    fi
  done < <(git -C "$repo_root" rev-list "$history_ref")
fi

echo "公开配置校验通过"
