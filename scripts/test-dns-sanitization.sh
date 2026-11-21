#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/surge-public-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/public/scripts" "$fixture_dir/source"
cp "$repo_root/scripts/sync-local-surge.sh" "$repo_root/scripts/validate-public-config.sh" "$fixture_dir/public/scripts/"
for name in Surge.conf wechat.list ai-extra.list; do
  cp "$repo_root/$name" "$fixture_dir/public/$name"
  cp "$repo_root/$name" "$fixture_dir/source/$name"
done

cat > "$fixture_dir/aliases.map" <<'EOF'
Private-VLESS-A=VLESS-1
Private-VLESS-B=VLESS-2
Private-Ext-Node=Hikyaku
Private-Hy2=Hysteria
Private-Provider=Subscription
EOF

validate() { bash "$fixture_dir/public/scripts/validate-public-config.sh" --root "$fixture_dir/source"; }
sync_public() { SURGE_ALIAS_MAP="$fixture_dir/aliases.map" bash "$fixture_dir/public/scripts/sync-local-surge.sh" "$fixture_dir/source" --apply; }
reject() {
  if validate > "$fixture_dir/result.log" 2>&1; then
    echo "错误：未拒绝 $1" >&2
    exit 1
  fi
}
mutate() { sed "$1" "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"; }
assert_absent() {
  if grep -qiE "$1" "$fixture_dir/public/Surge.conf"; then
    echo '错误：公开模板仍含合成凭据或个人标识' >&2
    exit 1
  fi
}

# 全部为合成夹具，不读取本机私有配置。
cp "$repo_root/Surge.conf" "$fixture_dir/source/Mac.conf"
reject '额外配置入口'
grep -q '未纳入脱敏流程' "$fixture_dir/result.log"
mv "$fixture_dir/source/Mac.conf" "$fixture_dir/Mac.conf.fixture"

mkdir -p "$fixture_dir/source/docs"
cp "$repo_root/Surge.conf" "$fixture_dir/source/docs/nested.conf"
reject '嵌套配置'
grep -q '未纳入脱敏流程' "$fixture_dir/result.log"
mv "$fixture_dir/source/docs/nested.conf" "$fixture_dir/nested.conf.fixture"
printf '归档\n' > "$fixture_dir/source/docs/Surge.conf.bak"
reject '嵌套备份'
grep -q '未纳入脱敏流程' "$fixture_dir/result.log"
mv "$fixture_dir/source/docs/Surge.conf.bak" "$fixture_dir/archive.fixture"
for field in http-listen socks5-listen wifi-access-http-auth; do
  printf '示例： `%s = synthetic-user:synthetic-value`\n' "$field" > "$fixture_dir/source/docs/example.md"
  reject "文档遗留 $field"
  grep -q '文档含远程访问字段' "$fixture_dir/result.log"
done
printf '示例： `policy-path="https://subscription.invalid/example"`\n' > "$fixture_dir/source/docs/example.md"
reject '文档遗留订阅地址'
grep -q '实际订阅地址' "$fixture_dir/result.log"
mv "$fixture_dir/source/docs/example.md" "$fixture_dir/example.md.fixture"

mutate 's#https://dns.alidns.com/dns-query#https://test-account.alidns.com/dns-query#g; s#^dns.alidns.com =#test-account.alidns.com =#'
if ! grep -q '^test-account.alidns.com =' "$fixture_dir/source/Surge.conf"; then
  printf '\n[Host]\ntest-account.alidns.com = 223.5.5.5, 223.6.6.6\n' >> "$fixture_dir/source/Surge.conf"
fi
reject '个人 DNS 与 Host'
sync_public
grep -q '^encrypted-dns-server = .*https://dns.alidns.com/dns-query' "$fixture_dir/public/Surge.conf"
grep -q '^dns.alidns.com = 223.5.5.5, 223.6.6.6' "$fixture_dir/public/Surge.conf"
assert_absent 'test-account'

awk '
  /^\[Proxy\]$/ { print "[Ponte]"; print "server-proxy-name= private-relay"; print ""; print; next }
  { print }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '非占位 Ponte'
sync_public
grep -q '^server-proxy-name= Hysteria' "$fixture_dir/public/Surge.conf"

sed -E \
  -e 's#VLESS-1 = vless, example\.com, 443#Private-VLESS-A = vless, private-vless.invalid, 8443#' \
  -e 's#VLESS-2#Private-VLESS-B#g' \
  -e 's#VLESS-1#Private-VLESS-A#g' \
  -e 's#username=00000000-0000-0000-0000-000000000000#username=11111111-2222-3333-4444-555555555555#g' \
  -e 's#sni=example\.com#sni=private-sni.invalid#g' \
  -e 's#reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA#reality-public-key=SYNTHETIC_REALITY_PUBKEY_SECRET_VAL#g' \
  -e 's#reality-short-id=00000000#reality-short-id=abcd1234#g' \
  "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject 'VLESS 真实地址、UUID 或 REALITY 凭据'
sync_public
assert_absent 'private-(vless|sni)\.invalid|11111111-2222|SYNTHETIC_REALITY|abcd1234|Private-VLESS-A|Private-VLESS-B'
grep -q 'VLESS-1 = vless, example\.com, 443, username=00000000-0000-0000-0000-000000000000, sni=example\.com, flow=xtls-rprx-vision, reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA, reality-short-id=00000000' "$fixture_dir/public/Surge.conf"

mutate 's#reality-public-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA#reality-public-key=SYNTHETIC_LEAKED_KEY#'
reject '被占位 UUID 掩盖的 REALITY 公钥'

sed -E \
  -e 's#exec = "/path/to/external-proxy/start-client\.sh"#exec = "/Users/tester/Library/start-client.sh"#' \
  -e 's#addresses = 198\.51\.100\.1#addresses = 203.0.113.9#' \
  -e 's#Hikyaku#Private-Ext-Node#g' \
  "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject 'external 代理本机路径与真实 IP'
sync_public
assert_absent 'Users/tester|203\.0\.113\.9|Private-Ext-Node'
grep -q 'Hikyaku = external, exec = "/path/to/external-proxy/start-client\.sh", local-port = 11080, addresses = 198\.51\.100\.1, udp-relay=true #!MACOS-ONLY' "$fixture_dir/public/Surge.conf"

awk '
  { print }
  /^\[Proxy\]$/ { print "Private-Hy2 = hysteria2, private-proxy.invalid, 8443, password=synthetic-secret, download-bandwidth=100, gecko-password=synthetic-gecko-secret, sni=private-sni.invalid, port-hopping=20000-50000" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject 'Hysteria2 代理地址及多个凭据'
sync_public
assert_absent 'private-(proxy|sni)\.invalid|synthetic-|Private-Hy2'
grep -q 'Hysteria = hysteria2, example\.com, 443, password=YOUR_PROXY_PASSWORD, download-bandwidth=100, gecko-password=YOUR_PROXY_PASSWORD, sni=example\.com, port-hopping=20000-50000' "$fixture_dir/public/Surge.conf"

awk '
  { print }
  /^\[Proxy\]$/ { print "Hysteria = hysteria2, example.com, 443, password=YOUR_PROXY_PASSWORD, download-bandwidth=100, gecko-password=synthetic-gecko-secret, sni=example.com, port-hopping=20000-50000" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '被同一行占位密码掩盖的 gecko-password'

mutate 's#VLESS-1 = vless, example\.com, 443#CloudVendor-Node = vless, example.com, 443#'
reject '未纳入公开白名单的私有节点别名'
grep -q '节点名称尚未统一为公开别名' "$fixture_dir/result.log"

sed -E \
  -e 's#include-other-group=Subscription#include-other-group=Private-Provider#g' \
  -e 's#^Subscription = select,#Private-Provider = select,#g' \
  -e 's#https://raw\.githubusercontent\.com/Irrucky/Tool/main/Surge/icon/surge_2\.png, category=节点选择#https://raw.githubusercontent.com/lige47/QuanX-icon-rule/main/icon/06jichang/Brand.png, category=节点选择#g' \
  "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '未脱敏的订阅策略组名称或机场图标'
grep -q '订阅策略组名称或图标尚未脱敏' "$fixture_dir/result.log"
sync_public
assert_absent 'Private-Provider|/06jichang/'
grep -q '^Subscription = select, policy-path=YOUR_SURGE_SUBSCRIPTION_URL, .*https://raw\.githubusercontent\.com/Irrucky/Tool/main/Surge/icon/surge_2\.png' "$fixture_dir/public/Surge.conf"

cp "$repo_root/Surge.conf" "$fixture_dir/source/Surge.conf"
SURGE_ALIAS_MAP="$fixture_dir/missing-aliases.map" bash "$fixture_dir/public/scripts/sync-local-surge.sh" "$fixture_dir/source" --apply

mutate 's#policy-path=YOUR_SURGE_SUBSCRIPTION_URL#policy-path=https://converter.invalid/sub?url=https%3A%2F%2Fprovider.invalid%2Fapi%3Ftoken2%3Dsynthetic-token#'
reject '订阅令牌'
sync_public
assert_absent 'synthetic-token'

awk '
  { print }
  /^\[General\]$/ { print "external-controller-access = synthetic-controller@127.0.0.1:6170"; print "http-api = synthetic-api@127.0.0.1:6171"; print "http-api-mcp = true"; print "http-api-tls = false"; print "http-api-web-dashboard = true" }
  /^\[MITM\]$/ { print "ca-keystore-name = synthetic-ca"; print "ca-passphrase = synthetic-ca-password" }
  END { print "\n[Keystore]\nsynthetic-ca = type = p12, base64 = SYNTHETIC_NOT_A_CERTIFICATE, password = synthetic-ca-password" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '证书与控制器'
sync_public
assert_absent 'synthetic-|\[Keystore\]|ca-keystore-name|external-controller-access|http-api'

awk '
  { print }
  /^\[General\]$/ {
    print "http-listen = synthetic-user:synthetic-http@127.0.0.1:6152"
    print "SOCKS5-LISTEN = synthetic-user:synthetic-socks@127.0.0.1:6153"
    print "# wifi-access-http-auth = synthetic-user:synthetic-wifi"
  }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '额外监听与认证字段'
sync_public
assert_absent 'synthetic-|http-listen|socks5-listen|wifi-access-http-auth'

for region in HK TW JP SG US; do
  mutate "/^$region = smart,/s/policy-priority=\"\([^\"]*\)\"/policy-priority=\1/"
  reject "地区组 $region 权重未加引号"
  grep -q "Smart 地区组 $region" "$fixture_dir/result.log"
done
mutate '/^US = smart,/s/VLESS-1:0\.80/VLESS-1:invalid/'
reject '权重不是数值'
grep -q 'Smart 地区组 US' "$fixture_dir/result.log"

mutate 's|^\[General\]|[General]\nhttp-api-mcp = true|'
reject '公开模板遗留 MCP 管理开关'

mutate 's|^\[General\]|[General]\nhttp-api-tls = false|'
reject '公开模板遗留 HTTP API 设置'

# 校验失败时不得覆盖任何已脱敏的公开模板。
before="$(cksum "$fixture_dir/public/Surge.conf")"
mutate 's#non_ip/ai.conf,Intelligence,extended-matching#non_ip/ai.conf,Intelligence#'
if sync_public > "$fixture_dir/result.log" 2>&1; then
  echo '错误：不完整源配置仍被发布' >&2
  exit 1
fi
[[ "$before" == "$(cksum "$fixture_dir/public/Surge.conf")" ]]

for mutation in \
  's#ip/china_ip.conf,DIRECT#ip/china_ip.conf,DIRECT,no-resolve#' \
  's#domainset/download.conf,Proxy,extended-matching#domainset/download.conf,DIRECT#' \
  's#domainset/download.conf,Proxy,extended-matching#domainset/download.conf,Proxy#' \
  's#non_ip/domestic.conf,DIRECT,extended-matching#non_ip/domestic.conf,DIRECT#' \
  's#non_ip/direct.conf,DIRECT,extended-matching#non_ip/direct.conf,DIRECT#' \
  's#DOMAIN,captive\.apple\.com,DIRECT,extended-matching#DOMAIN,captive.apple.com,DIRECT#' \
  's#non_ip/apple_cn\.conf,DIRECT,extended-matching#non_ip/apple_cn.conf,DIRECT#' \
  's#non_ip/apple_services\.conf,Apple,extended-matching#non_ip/apple_services.conf,Apple#' \
  's#non_ip/microsoft\.conf,Microsoft,extended-matching#non_ip/microsoft.conf,Microsoft#' \
  's#DOMAIN,ip\.api\.skk\.moe,VLESS-1,extended-matching#DOMAIN,ip.api.skk.moe,VLESS-1#' \
  's#non_ip/reject-drop\.conf,REJECT-DROP,pre-matching,extended-matching#non_ip/reject-drop.conf,REJECT-DROP,pre-matching#' \
  's#non_ip/global\.conf,Proxy,extended-matching#non_ip/global.conf,Proxy#' \
  's#\*\.music\.126\.net#*.126.net#' \
  's#100\.64\.0\.0/10,#100.64.0.0/10, 162.14.0.0/16,#' \
  's#domainset/apple_cdn.conf,DIRECT,extended-matching#domainset/apple_cdn.conf,DIRECT#' \
  's#non_ip/microsoft_cdn.conf,DIRECT,extended-matching#non_ip/microsoft_cdn.conf,DIRECT#' \
  's#domainset/reject.conf,REJECT,pre-matching,extended-matching#domainset/reject.conf,REJECT,pre-matching#' \
  's#ip/neteasemusic.conf,DIRECT,no-resolve#ip/neteasemusic.conf,DIRECT#' \
  's#https://1\.12\.12\.12/dns-query#https://1.12.12.12/dns-query, https://120.53.53.53/dns-query#' \
  's#music\.taihe\.com,#musicapi.taihe.com, music.taihe.com,#' \
  's|^\[Rule\]|[Rule]\nRULE-SET,https://ruleset.skk.moe/List/non_ip/neteasemusic.conf,DIRECT|' \
  '/^PROCESS-NAME,\/Applications\/WeChat\.app\/,/d' \
  's|RULE-SET,https://ruleset.skk.moe/List/non_ip/reject.conf,REJECT,extended-matching|RULE-SET,https://ruleset.skk.moe/List/non_ip/reject.conf,REJECT,extended-matching #!MACOS-ONLY|' \
  '/^DOMAIN,dl\.wechat\.com,DIRECT,extended-matching$/d' \
  '/^DOMAIN-SET,.*domainset\/cdn.conf,Proxy,extended-matching$/d' \
  '/^tun-included-routes = 169\.254\.169\.254\/32$/d' \
  '/^IP-CIDR,169\.254\.169\.254\/32,/d' \
  '/^PROCESS-NAME,XPlayer,/d' \
  '/^RULE-SET,.*\/ai-extra.list,/d' \
  's|PROCESS-NAME,WeChat,DIRECT #!MACOS-ONLY|PROCESS-NAME,WeChat,DIRECT|' \
  's|^\[Rule\]|[Rule]\nRULE-SET,https://raw.githubusercontent.com/Ivan9ua/Surge/main/quic-reject.list,REJECT-NO-DROP,extended-matching|' \
  's|^\[Rule\]|[Rule]\nAND,((PROTOCOL,UDP),(DEST-PORT,443),(DOMAIN-SUFFIX,qpic.cn,extended-matching)),REJECT-NO-DROP|' \
  's|^\[Proxy\]|[Testing]\n\n[Proxy]|'; do
  mutate "$mutation"
  reject '关键规则或平台隔离回退'
done
mutate 's|^\[General\]|[General]\n#!include missing.dconf|'
reject '分离文件引用'

awk '
  /List\/non_ip\/reject-drop\.conf/ { drop=$0; next }
  { print }
  /List\/non_ip\/reject-no-drop\.conf/ && drop { print drop; drop="" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject 'reject-drop 广告规则置后降级'

awk '
  /^DOMAIN,dl\.wechat\.com,DIRECT,extended-matching$/ { dl=$0; next }
  { print }
  /List\/domainset\/download\.conf/ && dl { print dl; dl="" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject 'dl.wechat.com 置后被 download.conf 截胡'

cp "$repo_root/Surge.conf" "$fixture_dir/source/Surge.conf"
printf '# empty retired file\n' > "$fixture_dir/source/quic-reject.list"
reject '重新引入已弃用的 quic-reject.list'
grep -q '已弃用的 quic-reject.list' "$fixture_dir/result.log"
rm -f "$fixture_dir/source/quic-reject.list"

sed 's|DOMAIN-SUFFIX,muse.ai|IP-CIDR,1.1.1.1/32,no-resolve|' "$repo_root/ai-extra.list" > "$fixture_dir/source/ai-extra.list"
reject 'AI 补充混入 IP 规则'
sed 's|DOMAIN-SUFFIX,muse.ai|DOMAIN-SUFFIX,auth0.com|' "$repo_root/ai-extra.list" > "$fixture_dir/source/ai-extra.list"
reject 'AI 补充扩大到共享认证后缀'
sed 's|DOMAIN-SUFFIX,pplx.ai|DOMAIN-SUFFIX,oaiusercontent.com|' "$repo_root/ai-extra.list" > "$fixture_dir/source/ai-extra.list"
reject 'AI 补充重新混入已被 cdn.conf 遮蔽条目'
cp "$repo_root/ai-extra.list" "$fixture_dir/source/ai-extra.list"

sed 's|DOMAIN-SUFFIX,wxgateway.com$|DOMAIN-SUFFIX,wxgateway.com.invalid|' "$repo_root/wechat.list" > "$fixture_dir/source/wechat.list"
reject '微信关键域名被追加后缀后仍被当成原条目'
cp "$repo_root/wechat.list" "$fixture_dir/source/wechat.list"

sed 's|DOMAIN-SUFFIX,wechatlegal.net$|DOMAIN-SUFFIX,wechat.com|' "$repo_root/wechat.list" > "$fixture_dir/source/wechat.list"
reject '微信重复条目掩盖覆盖丢失'
cp "$repo_root/wechat.list" "$fixture_dir/source/wechat.list"

sed 's|DOMAIN-SUFFIX,wechatlegal.net$|DOMAIN-SUFFIX,wechatlegal.net,DIRECT|' "$repo_root/wechat.list" > "$fixture_dir/source/wechat.list"
reject '微信规则集内误带策略字段'
cp "$repo_root/wechat.list" "$fixture_dir/source/wechat.list"

sed 's|DOMAIN-SUFFIX,wechatlegal.net$|DOMAIN,soup.v.qq.com|' "$repo_root/wechat.list" > "$fixture_dir/source/wechat.list"
reject '微信规则重新混入 Sukka 广告冲突域名'
cp "$repo_root/wechat.list" "$fixture_dir/source/wechat.list"

cp "$repo_root/Surge.conf" "$fixture_dir/source/Surge.conf"
if bash "$fixture_dir/public/scripts/sync-local-surge.sh" "$fixture_dir/source" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：同步未要求 --apply' >&2
  exit 1
fi
mv "$fixture_dir/source/Surge.conf" "$fixture_dir/Surge.conf.fixture"
if sync_public > "$fixture_dir/result.log" 2>&1; then
  echo '错误：源文件缺失仍报告同步成功' >&2
  exit 1
fi
[[ "$before" == "$(cksum "$fixture_dir/public/Surge.conf")" ]]
bash "$fixture_dir/public/scripts/validate-public-config.sh"
echo '单文件配置、凭据脱敏、失败不覆盖及关键分流回归检查通过'
