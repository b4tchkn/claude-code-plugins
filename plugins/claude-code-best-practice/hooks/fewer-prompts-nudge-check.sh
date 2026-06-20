#!/usr/bin/env bash
set -eu

COUNT_FILE="$HOME/.claude/perm_count.txt"
count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)

if [ "$count" -ge 5 ]; then
  echo 0 > "$COUNT_FILE"
  echo "{\"systemMessage\": \"このセッションで $count 回パーミッションの要求がありました。/fewer-permission-prompts を実行すると、よく使う操作を settings.json に自動追加してプロンプトを減らせます。\"}"
else
  echo 0 > "$COUNT_FILE"
fi
