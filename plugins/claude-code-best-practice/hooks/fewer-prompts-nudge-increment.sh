#!/usr/bin/env bash
set -eu

COUNT_FILE="$HOME/.claude/perm_count.txt"
count=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
echo $((count + 1)) > "$COUNT_FILE"
