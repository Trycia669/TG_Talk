# TG_Talk — Northflank 部署指南

数据库通过 GitHub API 自动备份与恢复，无需持久卷。

---

## 架构说明

```
Northflank Container
  ├─ 启动时：从 GitHub 私有仓库拉取 bot_data.db
  ├─ 运行中：每小时自动备份 bot_data.db → GitHub
  ├─ 退出时：执行最终备份
  └─ 下次启动：自动恢复最新备份
```

---

## 第一步：准备 GitHub 备份仓库

1. 在 GitHub 新建一个**私有仓库**，例如 `tg-talk-data`（空仓库即可）
2. 前往 https://github.com/settings/tokens/new
3. 勾选 `repo`（完整权限），生成 Token，**妥善保存**

---

## 第二步：Fork 并修改代码

将以下文件覆盖/添加到你的 Fork 仓库（`Trycia669/TG_Talk`）：

| 文件 | 说明 |
|------|------|
| `Dockerfile` | 替换原有 Dockerfile |
| `docker-start.sh` | 替换原有启动脚本 |
| `github_backup.sh` | **新增** 备份脚本 |
| `github_restore.sh` | **新增** 恢复脚本 |

---

## 第三步：在 Northflank 创建服务

### 3.1 创建项目
- 登录 [northflank.com](https://northflank.com)
- 新建 Project → Add Service → **Combined Service**

### 3.2 连接 GitHub 仓库
- Source：选择 GitHub → 你的 `TG_Talk` 仓库
- Branch：`main`
- Build type：**Dockerfile**（自动检测）

### 3.3 配置资源（免费套餐可用）
- CPU: 0.1 vCPU
- RAM: 256 MB（推荐 512 MB+）

### 3.4 配置端口（可选）
- 如果不需要 HTTP 访问，**不用添加端口**
- Northflank 要求至少有一个健康检查端口时，添加 `8080/TCP`

### 3.5 设置环境变量
在 **Environment Variables** 中添加：

```
MANAGER_TOKEN        = 你的管理Bot Token
ADMIN_CHANNEL        = 你的管理员频道ID（如 -1001234567890）
GH_USERNAME          = 你的GitHub用户名
GH_REPO              = tg-talk-data（备份仓库名）
GH_TOKEN             = ghp_xxx（GitHub Token）
GITHUB_BACKUP_INTERVAL = 1800   （可选，备份间隔秒数，默认3600）
```

### 3.6 部署
- 点击 **Deploy** 即可
- 在 Logs 页面可以看到启动日志和备份状态

---

## 查看备份日志

容器日志中会显示：
```
[2025-11-18 10:00:00] 尝试从 GitHub 恢复数据库...
[2025-11-18 10:00:01] ✅ 数据库恢复成功
[2025-11-18 10:00:01] 启动后台备份任务（间隔 1800s）
[2025-11-18 10:00:01] 🚀 启动 TG Bot...
```

备份日志在 `/app/data/backup.log` 中。

---

## 更新部署

代码推送到 GitHub 后，在 Northflank 中：
- **手动触发**：Service → Deployments → Redeploy
- **自动触发**：在 Northflank 开启 GitHub 自动部署（推送即部署）

---

## 常见问题

**Q: Northflank 容器重启后数据会丢失吗？**
A: 不会。每次启动时脚本会自动从 GitHub 恢复最新的数据库。

**Q: 备份失败怎么办？**
A: 检查 `GH_TOKEN` 是否有 `repo` 权限，以及备份仓库是否存在。

**Q: 免费套餐支持吗？**
A: Northflank 免费套餐支持运行此服务，但有资源限制（1个免费服务）。

**Q: 如何手动触发备份？**
A: 进入容器终端执行 `/app/github_backup.sh`

---

## 文件结构（部署后）

```
/app/
├── host_bot.py          # 主程序
├── database.py          # 数据库模块
├── docker-start.sh      # 启动脚本
├── github_backup.sh     # 备份到 GitHub
├── github_restore.sh    # 从 GitHub 恢复
└── data/
    ├── bot_data.db      # SQLite 数据库（运行时）
    └── backup.log       # 备份日志
```

GitHub 备份仓库结构：
```
tg-talk-data/
└── data/
    └── bot_data.db      # 备份的数据库
```
