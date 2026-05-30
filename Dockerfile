FROM python:3.11-slim

WORKDIR /app

# 系统依赖（git/curl 用于 GitHub 备份）
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc git curl && \
    rm -rf /var/lib/apt/lists/*

# Python 依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    python-telegram-bot==20.7 \
    python-dotenv \
    requests \
    flask \
    gunicorn

# 复制应用文件
COPY host_bot.py /app/
COPY database.py /app/
COPY verify_server.py /app/
COPY templates/ /app/templates/

# 复制启动和备份脚本
COPY docker-start.sh /app/
COPY github_backup.sh /app/
COPY github_restore.sh /app/

# 创建数据目录
RUN mkdir -p /app/data

# 赋予脚本执行权限
RUN chmod +x /app/docker-start.sh /app/github_backup.sh /app/github_restore.sh

ENV PYTHONUNBUFFERED=1 \
    TG_BOT_DATA_DIR=/app/data

# Northflank 健康检查端口（Flask 验证服务器）
EXPOSE 8080

CMD ["/app/docker-start.sh"]
