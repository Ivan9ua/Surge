#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/surge-dns-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir "$fixture_dir/scripts"
cp "$repo_root/scripts/sync-local-surge.sh" "$repo_root/scripts/validate-public-config.sh" "$fixture_dir/scripts/"
for name in Surge.conf iPhone.conf Shared-Routing.dconf Shared-General.dconf wechat.list; do
  cp "$repo_root/$name" "$fixture_dir/$name"
done

# 使用合成账号验证拒绝发布及同步脱敏，不读取个人配置。
cp "$repo_root/Surge.conf" "$fixture_dir/Mac.conf"
if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：未纳入脱敏流程的配置文件未被拒绝' >&2
  exit 1
fi
grep -q '未纳入脱敏流程' "$fixture_dir/result.log"
mv "$fixture_dir/Mac.conf" "$fixture_dir/Mac.conf.fixture"

sed 's#https://dns.alidns.com/dns-query#https://test-account.alidns.com/dns-query#g' \
  "$repo_root/Shared-General.dconf" > "$fixture_dir/Shared-General.dconf"
if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：个人 DNS 地址未被拒绝' >&2
  exit 1
fi
grep -q '个人 AliDNS 地址' "$fixture_dir/result.log"
bash "$fixture_dir/scripts/sync-local-surge.sh" "$fixture_dir" --apply
grep -q '^encrypted-dns-server = .*https://dns.alidns.com/dns-query' "$fixture_dir/Shared-General.dconf"
if grep -q 'test-account.alidns.com' "$fixture_dir/Shared-General.dconf"; then
  exit 1
fi

sed -E \
  -e 's#Hysteria = hysteria2, example\.com, 443, password=YOUR_PROXY_PASSWORD#Hysteria = hysteria2, private-proxy.invalid, 8443, password=synthetic-secret#' \
  -e 's#sni=example\.com#sni=private-sni.invalid#' \
  -e 's#anytls, example\.com, 443, password=YOUR_PROXY_PASSWORD#anytls, private-anytls.invalid, 8443, password=synthetic-secret#' \
  "$repo_root/Shared-Routing.dconf" > "$fixture_dir/Shared-Routing.dconf"
if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：代理地址或凭据未被拒绝' >&2
  exit 1
fi
bash "$fixture_dir/scripts/sync-local-surge.sh" "$fixture_dir" --apply
grep -q 'Hysteria = hysteria2, example.com, 443, password=YOUR_PROXY_PASSWORD.*sni=example.com' "$fixture_dir/Shared-Routing.dconf"
if grep -qE 'private-(proxy|sni|anytls)\.invalid|synthetic-secret' "$fixture_dir/Shared-Routing.dconf"; then
  exit 1
fi

sed 's#policy-path=YOUR_SURGE_SUBSCRIPTION_URL#policy-path=https://converter.invalid/sub?url=https%3A%2F%2Fprovider.invalid%2Fapi%3Ftoken2%3Dsynthetic-token#' \
  "$repo_root/Shared-Routing.dconf" > "$fixture_dir/Shared-Routing.dconf"
if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：带令牌的订阅地址未被拒绝' >&2
  exit 1
fi
bash "$fixture_dir/scripts/sync-local-surge.sh" "$fixture_dir" --apply
grep -q 'policy-path=YOUR_SURGE_SUBSCRIPTION_URL' "$fixture_dir/Shared-Routing.dconf"
if grep -q 'synthetic-token' "$fixture_dir/Shared-Routing.dconf"; then
  exit 1
fi

# 确认关键分流参数与顺序发生回退时，校验器确实会拒绝。
for mutation in \
  's#non_ip/ai.conf,Intelligence,extended-matching#non_ip/ai.conf,Intelligence#' \
  's#ip/china_ip.conf,DIRECT#ip/china_ip.conf,DIRECT,no-resolve#' \
  's#domainset/download.conf,Proxy#domainset/download.conf,DIRECT#' \
  '/^DOMAIN-SET,.*domainset\/cdn.conf,Proxy$/d'; do
  sed "$mutation" "$repo_root/Shared-Routing.dconf" > "$fixture_dir/Shared-Routing.dconf"
  if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
    echo '错误：关键分流配置回退未被拒绝' >&2
    exit 1
  fi
done
cp "$repo_root/Shared-Routing.dconf" "$fixture_dir/Shared-Routing.dconf"
bash "$fixture_dir/scripts/validate-public-config.sh"

echo 'DNS、代理、订阅脱敏与关键分流回归检查通过'
