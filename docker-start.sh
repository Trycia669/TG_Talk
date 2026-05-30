#!/bin/bash
# docker-start.sh - Northflank v1.0.4 启动脚本
# 启动顺序：恢复DB → 启动 Flask 验证服务 → 启动 Bot → 后台定时备份

set -e

DATA_DIR="${TG_BOT_DATA_DIR:-/app/data}"
DB_FILE="$DATA_DIR/bot_data.db"
LOG_FILE="$DATA_DIR/backup.log"
BACKUP_INTERVAL="${GITHUB_BACKUP_INTERVAL:-3600}"
VERIFY_PORT="${VERIFY_SERVER_PORT:-8080}"

echo "======================================"
echo "  TG_Talk v1.0.4 - Northflank 模式"
echo "======================================"

mkdir -p "$DATA_DIR"

# ── 1. 从 GitHub 恢复数据库 ──────────────────────────────────
if [ -n "$GH_TOKEN" ] && [ -n "$GH_USERNAME" ] && [ -n "$GH_REPO" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试从 GitHub 恢复数据库..."
    /app/github_restore.sh && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 数据库恢复成功" \
        || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  未找到备份，将使用全新数据库"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  未配置 GitHub 备份，跳过恢复"
fi

# ── 2. 启动 Flask 验证服务器（后台）──────────────────────────
# 仅在配置了 CF Turnstile 时启动
if [ -n "$CF_TURNSTILE_SITE_KEY" ] && [ -n "$CF_TURNSTILE_SECRET_KEY" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🌐 启动 CF 验证服务器 (端口 $VERIFY_PORT)..."
    cd /app
    gunicorn \
        --bind "0.0.0.0:${VERIFY_PORT}" \
        --workers 2 \
        --timeout 30 \
        --log-level info \
        --access-logfile "$DATA_DIR/verify_access.log" \
        --error-logfile "$DATA_DIR/verify_error.log" \
        verify_server:app &
    FLASK_PID=$!
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 验证服务器已启动 PID: $FLASK_PID"
    sleep 2
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  未配置 CF Turnstile，跳过验证服务器"
    # 如果 Northflank 需要健康检查端口，启动一个简单的 HTTP 响应
    python3 -c "
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self, *a): pass
HTTPServer(('0.0.0.0', ${VERIFY_PORT}), H).serve_forever()
" &
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 健康检查服务已启动 (端口 $VERIFY_PORT)"
fi

# ── 3. 后台定时备份 ──────────────────────────────────────────
if [ -n "$GH_TOKEN" ] && [ -n "$GH_USERNAME" ] && [ -n "$GH_REPO" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 启动后台备份任务（间隔 ${BACKUP_INTERVAL}s）"
    (
        while true; do
            sleep "$BACKUP_INTERVAL"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 执行定时备份..." >> "$LOG_FILE"
            /app/github_backup.sh >> "$LOG_FILE" 2>&1 \
                && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 备份成功" >> "$LOG_FILE" \
                || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 备份失败" >> "$LOG_FILE"
        done
    ) &
fi

# ── 4. 退出信号处理：执行最终备份 ─────────────────────────────
cleanup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛑 收到退出信号，执行最终备份..."
    if [ -n "$GH_TOKEN" ] && [ -n "$GH_USERNAME" ] && [ -n "$GH_REPO" ]; then
        /app/github_backup.sh && echo "✅ 最终备份完成" || echo "❌ 最终备份失败"
    fi
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── 5. 启动 Bot ──────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 启动 TG Bot..."
exec python /app/host_bot.py
