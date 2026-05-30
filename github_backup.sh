#!/bin/bash
# github_backup.sh - 将 SQLite 数据库备份到 GitHub

DATA_DIR="${TG_BOT_DATA_DIR:-/app/data}"
DB_FILE="$DATA_DIR/bot_data.db"
GH_BRANCH="${GH_BRANCH:-main}"
GH_DB_PATH="${GH_DB_PATH:-data/bot_data.db}"

if [ -z "$GH_TOKEN" ] || [ -z "$GH_USERNAME" ] || [ -z "$GH_REPO" ]; then
    echo "❌ 缺少 GitHub 配置变量 (GH_TOKEN / GH_USERNAME / GH_REPO)"
    exit 1
fi

if [ ! -f "$DB_FILE" ]; then
    echo "⚠️  数据库文件不存在: $DB_FILE，跳过备份"
    exit 0
fi

API_BASE="https://api.github.com/repos/${GH_USERNAME}/${GH_REPO}"
AUTH_HEADER="Authorization: token ${GH_TOKEN}"

DB_CONTENT=$(base64 -w 0 "$DB_FILE")
COMMIT_MSG="Auto backup: $(date '+%Y-%m-%d %H:%M:%S UTC')"

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

if [ -n "$CURRENT_SHA" ]; then
    REQUEST_BODY=$(python3 -c "
import json
print(json.dumps({
    'message': '$COMMIT_MSG',
    'content': '$DB_CONTENT',
    'sha': '$CURRENT_SHA',
    'branch': '$GH_BRANCH'
}))
")
else
    REQUEST_BODY=$(python3 -c "
import json
print(json.dumps({
    'message': '$COMMIT_MSG',
    'content': '$DB_CONTENT',
    'branch': '$GH_BRANCH'
}))
")
fi

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
    print('错误:', d.get('message', '未知'))
except:
    pass
" 2>/dev/null
    exit 1
fi
