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
sed 's#https://dns.alidns.com/dns-query#https://test-account.alidns.com/dns-query#g' \
  "$repo_root/Shared-General.dconf" > "$fixture_dir/Shared-General.dconf"
if bash "$fixture_dir/scripts/validate-public-config.sh" > "$fixture_dir/result.log" 2>&1; then
  echo '错误：个人 DNS 地址未被拒绝' >&2
  exit 1
fi
grep -q '个人 AliDNS 地址' "$fixture_dir/result.log"
bash "$fixture_dir/scripts/sync-local-surge.sh" "$fixture_dir" --apply
grep -q '^encrypted-dns-server = https://dns.alidns.com/dns-query$' "$fixture_dir/Shared-General.dconf"
if grep -q 'test-account.alidns.com' "$fixture_dir/Shared-General.dconf"; then
  exit 1
fi
echo 'DNS 脱敏回归检查通过'
