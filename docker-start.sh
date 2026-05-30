#!/bin/bash
# docker-start.sh - Northflank 启动脚本
# 启动顺序：恢复数据库 → 启动 Bot → 后台定时备份

set -e

DATA_DIR="${TG_BOT_DATA_DIR:-/app/data}"
DB_FILE="$DATA_DIR/bot_data.db"
LOG_FILE="$DATA_DIR/backup.log"
BACKUP_INTERVAL="${GITHUB_BACKUP_INTERVAL:-3600}"  # 默认每小时备份一次（秒）

echo "======================================"
echo "  TG_Talk 启动 - Northflank 模式"
echo "======================================"

mkdir -p "$DATA_DIR"

# ── 1. 从 GitHub 恢复数据库 ──────────────────────────────────
if [ -n "$GH_TOKEN" ] && [ -n "$GH_USERNAME" ] && [ -n "$GH_REPO" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 尝试从 GitHub 恢复数据库..."
    /app/github_restore.sh && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ 数据库恢复成功" \
        || echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  未找到备份或恢复失败，将使用全新数据库"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  未配置 GitHub 备份环境变量，跳过恢复"
fi

# ── 2. 后台定时备份循环 ──────────────────────────────────────
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
    BACKUP_PID=$!
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 后台备份进程 PID: $BACKUP_PID"
fi

# ── 3. 捕获退出信号，退出前执行最后一次备份 ────────────────
cleanup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛑 收到退出信号，执行最终备份..."
    if [ -n "$GH_TOKEN" ] && [ -n "$GH_USERNAME" ] && [ -n "$GH_REPO" ]; then
        /app/github_backup.sh && echo "✅ 最终备份完成" || echo "❌ 最终备份失败"
    fi
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── 4. 启动 Bot ──────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 启动 TG Bot..."
exec python /app/host_bot.py
