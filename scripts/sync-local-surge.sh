#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${1:-}"

candidates=()
if [[ -n "$source_dir" ]]; then
  candidates+=("$source_dir")
else
  candidates+=(
    "$HOME/Library/Mobile Documents/iCloud~com~nssurge~inc/Documents"
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Surge"
    "$HOME/Library/Application Support/Surge"
    "$HOME/Documents/Surge"
  )
fi

files=("Surge.conf" "Shared.dconf" "bilibili.sgmodule")

found_dir=""
for dir in "${candidates[@]}"; do
  if [[ -d "$dir" ]]; then
    for file in "${files[@]}"; do
      if [[ -f "$dir/$file" ]]; then
        found_dir="$dir"
        break 2
      fi
    done
  fi
done

if [[ -z "$found_dir" ]]; then
  echo "未找到本地 Surge 配置目录。请传入包含 Surge.conf / Shared.dconf / bilibili.sgmodule 的目录。" >&2
  echo "用法: scripts/sync-local-surge.sh /path/to/Surge" >&2
  exit 1
fi

echo "从本地目录同步: $found_dir"
for file in "${files[@]}"; do
  if [[ -f "$found_dir/$file" ]]; then
    if [[ "$(cd "$(dirname "$found_dir/$file")" && pwd)/$(basename "$file")" == "$repo_root/$file" ]]; then
      echo "跳过 $file（源文件已在仓库中）"
      continue
    fi
    cp "$found_dir/$file" "$repo_root/$file"
    echo "已更新 $file"
  else
    echo "跳过 $file（本地目录中不存在）"
  fi
done
