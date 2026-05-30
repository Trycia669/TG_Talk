#!/bin/bash
# github_restore.sh - 从 GitHub 恢复 SQLite 数据库

DATA_DIR="${TG_BOT_DATA_DIR:-/app/data}"
DB_FILE="$DATA_DIR/bot_data.db"
GH_BRANCH="${GH_BRANCH:-main}"
GH_DB_PATH="${GH_DB_PATH:-data/bot_data.db}"

# 检查必要变量
if [ -z "$GH_TOKEN" ] || [ -z "$GH_USERNAME" ] || [ -z "$GH_REPO" ]; then
    echo "❌ 缺少 GitHub 配置变量 (GH_TOKEN / GH_USERNAME / GH_REPO)"
    exit 1
fi

API_URL="https://api.github.com/repos/${GH_USERNAME}/${GH_REPO}/contents/${GH_DB_PATH}?ref=${GH_BRANCH}"
AUTH_HEADER="Authorization: token ${GH_TOKEN}"

echo "📥 从 GitHub 下载数据库: ${GH_USERNAME}/${GH_REPO}/${GH_DB_PATH}"

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github.v3+json" \
    "$API_URL")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    # 提取 base64 内容并解码
    mkdir -p "$DATA_DIR"
    echo "$BODY" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
content = base64.b64decode(data['content'])
with open('$DB_FILE', 'wb') as f:
    f.write(content)
print('✅ 数据库写入成功:', len(content), '字节')
"
    exit $?
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  GitHub 仓库中未找到数据库文件（首次部署，将创建新库）"
    exit 1
else
    echo "❌ 下载失败 (HTTP $HTTP_CODE)"
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
