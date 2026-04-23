#!/usr/bin/env bash
set -eu

cat <<'EOF'
{
  "systemMessage": "💡 Tip: /clear したタイミングで許可設定の見直しをおすすめします。`/less-permission-prompts` を実行すると、繰り返し許可プロンプトが出るコマンドを検出し、allowlist に追加する候補を提案します。"
}
EOF
