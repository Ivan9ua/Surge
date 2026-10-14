#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/surge-public-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/public/scripts" "$fixture_dir/source"
cp "$repo_root/scripts/sync-local-surge.sh" "$repo_root/scripts/validate-public-config.sh" "$fixture_dir/public/scripts/"
for name in Surge.conf wechat.list quic-reject.list; do
  cp "$repo_root/$name" "$fixture_dir/public/$name"
  cp "$repo_root/$name" "$fixture_dir/source/$name"
done

validate() { bash "$fixture_dir/public/scripts/validate-public-config.sh" --root "$fixture_dir/source"; }
sync_public() { bash "$fixture_dir/public/scripts/sync-local-surge.sh" "$fixture_dir/source" --apply; }
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

mutate 's#https://dns.alidns.com/dns-query#https://test-account.alidns.com/dns-query#g; s#^dns.alidns.com =#test-account.alidns.com =#'
reject '个人 DNS 与 Host'
sync_public
grep -q '^encrypted-dns-server = .*https://dns.alidns.com/dns-query' "$fixture_dir/public/Surge.conf"
grep -q '^dns.alidns.com = 223.5.5.5, 223.6.6.6' "$fixture_dir/public/Surge.conf"
assert_absent 'test-account'

mutate 's#server-proxy-name= Hysteria#server-proxy-name= private-relay#'
reject '非占位 Ponte'
sync_public
grep -q '^server-proxy-name= Hysteria' "$fixture_dir/public/Surge.conf"

mutate 's#hysteria2, example.com, 443, password=YOUR_PROXY_PASSWORD#hysteria2, private-proxy.invalid, 8443, password=synthetic-secret#; s#sni=example.com#sni=private-sni.invalid#; s#gecko-password=YOUR_PROXY_PASSWORD#gecko-password=synthetic-gecko-secret#'
reject '代理地址及多个凭据'
sync_public
assert_absent 'private-(proxy|sni).invalid|synthetic-'
grep -q 'hysteria2, example.com, 443, password=YOUR_PROXY_PASSWORD' "$fixture_dir/public/Surge.conf"

mutate 's#gecko-password=YOUR_PROXY_PASSWORD#gecko-password=synthetic-gecko-secret#'
reject '被同一行占位密码掩盖的 gecko-password'

mutate 's#policy-path=YOUR_SURGE_SUBSCRIPTION_URL#policy-path=https://converter.invalid/sub?url=https%3A%2F%2Fprovider.invalid%2Fapi%3Ftoken2%3Dsynthetic-token#'
reject '订阅令牌'
sync_public
assert_absent 'synthetic-token'

awk '
  { print }
  /^\[General\]$/ { print "external-controller-access = synthetic-controller@127.0.0.1:6170"; print "http-api = synthetic-api@127.0.0.1:6171" }
  /^\[MITM\]$/ { print "ca-keystore-name = synthetic-ca"; print "ca-passphrase = synthetic-ca-password" }
  END { print "\n[Keystore]\nsynthetic-ca = type = p12, base64 = SYNTHETIC_NOT_A_CERTIFICATE, password = synthetic-ca-password" }
' "$repo_root/Surge.conf" > "$fixture_dir/source/Surge.conf"
reject '证书与控制器'
sync_public
assert_absent 'synthetic-|\[Keystore\]|ca-keystore-name|external-controller-access|http-api'

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
  's#domainset/download.conf,Proxy#domainset/download.conf,DIRECT#' \
  '/^DOMAIN-SET,.*domainset\/cdn.conf,Proxy$/d' \
  '/^PROCESS-NAME,XPlayer,/d' \
  's|icmp-forwarding = true #!MACOS-ONLY|icmp-forwarding = true|'; do
  mutate "$mutation"
  reject '关键规则或平台隔离回退'
done
mutate 's|^\[General\]|[General]\n#!include missing.dconf|'
reject '分离文件引用'

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
