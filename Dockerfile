# 使用 Python 3.11 官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（含 git 用于 GitHub 备份）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    python-telegram-bot==20.7 \
    python-dotenv \
    requests

# 复制应用程序文件
COPY host_bot.py /app/
COPY database.py /app/
COPY docker-start.sh /app/

# 复制 GitHub 备份脚本
COPY github_backup.sh /app/
COPY github_restore.sh /app/

# 创建数据目录
RUN mkdir -p /app/data

# 赋予脚本执行权限
RUN chmod +x /app/docker-start.sh /app/github_backup.sh /app/github_restore.sh

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    TG_BOT_DATA_DIR=/app/data

# Northflank 健康检查端口（可选）
# EXPOSE 8080

# 启动脚本
CMD ["/app/docker-start.sh"]
