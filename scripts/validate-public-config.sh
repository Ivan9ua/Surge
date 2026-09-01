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
grep -q '^FINAL,Proxy,dns-failed$' "$scan_root/Shared-Routing.dconf" || fail "共享规则缺少预期 FINAL 兜底"
wechat_reference_regex='^RULE-SET,https://(raw\.githubusercontent\.com/Ivan9ua/Surge/[0-9a-f]{40}/wechat\.list|cdn\.jsdelivr\.net/gh/Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list),DIRECT,(no-resolve,extended-matching|extended-matching,no-resolve)$'
grep -Eq "$wechat_reference_regex" "$scan_root/Shared-Routing.dconf" || fail "微信统一规则未固定到完整提交或缺少 no-resolve,extended-matching"
[[ "$(grep -cE 'Ivan9ua/Surge@[0-9a-f]{40}/wechat\.list' "$scan_root/Shared-Routing.dconf")" -eq 1 ]] || fail "微信统一规则必须且只能引用一次"
if grep -Eq 'wechat-(direct|exception|ip)\.list' "$scan_root/Shared-Routing.dconf"; then
  fail "共享规则仍引用旧版微信拆分规则"
fi
if grep -q '^PROTOCOL,MTProto,Telegram$' "$scan_root/Shared-Routing.dconf"; then
  fail "共享规则仍含已删除的 MTProto 入站分流"
fi
if grep -q 'telegram_asn\.conf' "$scan_root/Shared-Routing.dconf"; then
  fail "仍在使用高风险 Telegram ASN 规则"
fi
grep -q '^RULE-SET,https://ruleset-mirror\.skk\.moe/List/ip/china_ip_ipv6\.conf,DIRECT #!MACOS-ONLY$' "$scan_root/Shared-Routing.dconf" || fail "中国 IPv6 规则未限定为 macOS"
grep -q '^ipv6 = true$' "$scan_root/Surge.conf" || fail "Mac 模板未启用 IPv6"
grep -q '^ipv6-vif = auto$' "$scan_root/Surge.conf" || fail "Mac 模板未使用自动 IPv6 VIF"
grep -q '^ipv6 = false$' "$scan_root/iPhone.conf" || fail "iPhone 模板未关闭 IPv6"
grep -q '^ipv6-vif = disabled$' "$scan_root/iPhone.conf" || fail "iPhone 模板未禁用 IPv6 VIF"
if grep -qE '^ipv6(-vif)?[[:space:]]*=' "$scan_root/Shared-General.dconf"; then
  fail "IPv6 设备差异不应写入共享 General"
fi
if grep -Eq '^[[:space:]]*show-error-page-for-reject[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$scan_root/Shared-General.dconf"; then
  fail "共享 General 显式启用了 REJECT 普通 HTTP 错误页"
fi
if grep -q '162\.14\.0\.0/16' "$scan_root/Shared-General.dconf"; then
  fail "共享 General 仍含已移除的宽泛公网 skip-proxy 段"
fi
grep -q '^icmp-forwarding = true$' "$scan_root/Surge.conf" || fail "Mac 模板缺少 macOS 专用 ICMP 转发"
if grep -q '^icmp-forwarding' "$scan_root/iPhone.conf" "$scan_root/Shared-General.dconf"; then
  fail "icmp-forwarding 不应进入 iPhone 或共享 General 配置"
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
  'RULE-SET,https://ruleset-mirror.skk.moe/List/non_ip/reject-drop.conf,REJECT-DROP,pre-matching'
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
[[ -n "$ad_domain_line" && -n "$wechat_line" && "$ad_domain_line" -lt "$wechat_line" ]] || fail "微信统一规则未置于广告规则之后"
wechat_ref_count="$(grep -c 'wechat\.list' "$scan_root/Shared-Routing.dconf" || true)"
[[ "$wechat_ref_count" -eq 1 ]] || fail "微信统一规则必须仅保留一条远程引用"
if grep -qE 'WeChat_Resolve\.list|blackmatrix7/.*/WeChat' "$scan_root/Shared-Routing.dconf"; then
  fail "不得直接引用 Blackmatrix7 WeChat 或 WeChat_Resolve 规则"
fi

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
if grep -qFx 'DOMAIN,wup.imtt.qq.com' "$scan_root/wechat.list"; then
  fail "wup.imtt.qq.com 与广告规则冲突，不应加入微信直连"
fi
grep -qFx 'AND,((DOMAIN-SUFFIX,wechat.com),(NOT,((DOMAIN,sgminorshort.wechat.com))),(NOT,((DOMAIN,sgshort.wechat.com))))' "$scan_root/wechat.list" || fail "微信统一规则未精确排除海外控制域名"
if grep -qE '^(IP-CIDR|IP-CIDR6|IP-ASN|DOMAIN-KEYWORD|USER-AGENT),' "$scan_root/wechat.list"; then
  fail "微信统一规则不应使用静态 IP、ASN、顶层 DOMAIN-KEYWORD 或 USER-AGENT"
fi
wechat_rule_count="$(grep -Ev '^[[:space:]]*(#|;|//|$)' "$scan_root/wechat.list" | wc -l | tr -d ' ')"
[[ "$wechat_rule_count" -eq 31 ]] || fail "微信统一规则数量异常: $wechat_rule_count（预期 31）"

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
