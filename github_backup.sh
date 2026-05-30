#!/bin/bash
# github_backup.sh - 将 SQLite 数据库备份到 GitHub

DATA_DIR="${TG_BOT_DATA_DIR:-/app/data}"
DB_FILE="$DATA_DIR/bot_data.db"
GH_BRANCH="${GH_BRANCH:-main}"
GH_DB_PATH="${GH_DB_PATH:-data/bot_data.db}"  # 在 GitHub 仓库中的路径

# 检查必要变量
if [ -z "$GH_TOKEN" ] || [ -z "$GH_USERNAME" ] || [ -z "$GH_REPO" ]; then
    echo "❌ 缺少 GitHub 配置变量 (GH_TOKEN / GH_USERNAME / GH_REPO)"
    exit 1
fi

# 检查数据库文件是否存在
if [ ! -f "$DB_FILE" ]; then
    echo "⚠️  数据库文件不存在: $DB_FILE，跳过备份"
    exit 0
fi

API_BASE="https://api.github.com/repos/${GH_USERNAME}/${GH_REPO}"
AUTH_HEADER="Authorization: token ${GH_TOKEN}"

# 将数据库文件转为 base64
DB_CONTENT=$(base64 -w 0 "$DB_FILE")
COMMIT_MSG="Auto backup: $(date '+%Y-%m-%d %H:%M:%S UTC')"

# 获取当前文件的 SHA（更新文件时需要）
SHA_RESPONSE=$(curl -s -H "$AUTH_HEADER" \
    "${API_BASE}/contents/${GH_DB_PATH}?ref=${GH_BRANCH}")
CURRENT_SHA=$(echo "$SHA_RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('sha', ''))
except:
    print('')
")

# 构建请求体
if [ -n "$CURRENT_SHA" ]; then
    # 更新已有文件
    REQUEST_BODY=$(python3 -c "
import json
print(json.dumps({
    'message': '$(echo $COMMIT_MSG | sed "s/'/\\\\'/g")',
    'content': '$DB_CONTENT',
    'sha': '$CURRENT_SHA',
    'branch': '$GH_BRANCH'
}))
")
else
    # 创建新文件
    REQUEST_BODY=$(python3 -c "
import json
print(json.dumps({
    'message': '$(echo $COMMIT_MSG | sed "s/'/\\\\'/g")',
    'content': '$DB_CONTENT',
    'branch': '$GH_BRANCH'
}))
")
fi

# 发送请求
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PUT \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY" \
    "${API_BASE}/contents/${GH_DB_PATH}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ 数据库备份成功 → ${GH_USERNAME}/${GH_REPO}/${GH_DB_PATH}"
else
    echo "❌ 备份失败 (HTTP $HTTP_CODE)"
    echo "$BODY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print('错误信息:', d.get('message', '未知'))
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "$BODY"
    exit 1
fi
