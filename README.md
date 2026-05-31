# TG_Talk

> 双向 Telegram 托管平台 — 一个管理机器人，托管多个子机器人，用户消息双向转发，支持多种验证方式。

**当前版本：v1.0.4**

---

## 功能特性

- **多 Bot 托管**：一个管理机器人同时托管任意数量的子 Bot
- **双向消息转发**：用户 → 主人、主人 → 用户，支持文字/图片/文件/语音/贴纸等所有消息类型
- **两种转发模式**：直连模式（私聊转发）/ 话题模式（Forum 超级群话题转发）
- **四种验证方式**：简单验证码 / 自定义验证题 / CF Turnstile 人机验证 / 人工审核
- **自定义欢迎语**：每个子 Bot 可设置独立欢迎语，管理员可设置全局欢迎语
- **用户管理**：拉黑/解除拉黑、强制取消验证、查看用户清单
- **管理员广播**：向所有用过某 Bot 的用户发送通知
- **GitHub 数据持久化**：SQLite 数据库自动备份到 GitHub，容器重启后自动恢复

---

## 部署到 Northflank

### 第一步：准备 GitHub 备份仓库

数据库备份需要一个 GitHub 私有仓库来存储 SQLite 文件。

1. 登录 [github.com](https://github.com)，点击右上角 **+** → **New repository**
2. 仓库名填 `tg-talk-data`，选择 **Private**，点击 **Create repository**
3. 生成 GitHub Token：
   - 前往 https://github.com/settings/tokens/new
   - Note 随意填写，如 `tg-talk-backup`
   - Expiration 选 **No expiration**（或按需设置）
   - 勾选 **repo**（完整仓库权限）
   - 点击 **Generate token**，**复制并妥善保存**（页面关闭后无法再看到）

---

### 第二步：准备 Telegram Bot

1. 在 Telegram 中找到 [@BotFather](https://t.me/BotFather)
2. 发送 `/newbot`，按提示创建管理机器人，获取 **Bot Token**（格式：`123456789:ABCdef...`）
3. 创建一个 Telegram 群组或频道作为管理员通知频道，将上面的管理机器人加入并设为管理员
4. 获取该群组/频道的 ID：
   - 将 [@userinfobot](https://t.me/userinfobot) 加入群组，它会自动回复群组 ID（以 `-100` 开头）

---

### 第三步：Fork 仓库并提交文件

1. Fork 本仓库到你的 GitHub 账号
2. 确保仓库根目录包含以下文件（v1.0.4 版本已自动包含）：

```
TG_Talk/
├── Dockerfile          ← 已适配 Northflank
├── docker-start.sh     ← 启动脚本（含 GitHub 备份逻辑）
├── host_bot.py         ← 主程序
├── database.py         ← 数据库模块
├── verify_server.py    ← CF 验证服务器
├── github_backup.sh    ← 备份脚本
└── github_restore.sh   ← 恢复脚本
```

> `templates/` 目录的 HTML 文件已内嵌在 Dockerfile 中，无需单独上传。

---

### 第四步：在 Northflank 创建服务

#### 4.1 注册并创建项目

1. 前往 [northflank.com](https://northflank.com) 注册账号（免费套餐即可）
2. 点击 **New Project**，输入项目名称（如 `tg-talk`），点击 **Create Project**

#### 4.2 创建 Combined Service

1. 进入项目后，点击 **Add Service** → **Combined Service**
2. **Source** 选项卡：
   - 点击 **Connect GitHub**，授权 Northflank 访问你的仓库
   - 选择你 Fork 的 `TG_Talk` 仓库
   - Branch 选 `main`
   - Build type 选 **Dockerfile**（会自动检测根目录的 Dockerfile）
3. 点击 **Next**

#### 4.3 配置资源

| 配置项 | 推荐值 | 说明 |
|--------|--------|------|
| CPU | 0.1 vCPU | 免费套餐范围内 |
| Memory | 256 MB | 建议 512 MB 以上更稳定 |
| Replicas | 1 | 单实例即可 |

#### 4.4 配置端口

在 **Ports** 页面添加：

| 端口 | 协议 | 说明 |
|------|------|------|
| 8080 | HTTP | CF 验证页面 / 健康检查 |

添加端口后，Northflank 会自动分配一个公网域名（格式如 `https://xxx-xxx.northflank.app`），**复制这个域名**，后面填写 `VERIFY_SERVER_URL` 时需要用到。

#### 4.5 配置环境变量

在 **Environment Variables** 页面逐条添加以下变量：

---

##### 必需变量

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `MANAGER_TOKEN` | `123456789:ABCdef...` | 管理机器人的 Bot Token（从 @BotFather 获取） |
| `ADMIN_CHANNEL` | `-1001234567890` | 管理员通知频道/群组 ID（以 `-100` 开头） |

##### GitHub 数据备份变量（强烈建议配置）

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `GH_USERNAME` | `your_github_name` | 你的 GitHub 用户名 |
| `GH_REPO` | `tg-talk-data` | 第一步创建的私有备份仓库名 |
| `GH_TOKEN` | `ghp_xxxxxxxxxxxx` | 第一步生成的 GitHub Token |

##### CF Turnstile 验证变量（使用 CF 验证时必填）

| 变量名 | 示例值 | 说明 |
|--------|--------|------|
| `CF_TURNSTILE_SITE_KEY` | `0x4AAAAAAA...` | Cloudflare Turnstile 站点密钥 |
| `CF_TURNSTILE_SECRET_KEY` | `0x4AAAAAAA...` | Cloudflare Turnstile 密钥 |
| `VERIFY_SERVER_URL` | `https://xxx.northflank.app` | Northflank 分配的公网域名（4.4 步骤中复制的） |

> 获取 CF Turnstile 密钥：登录 [Cloudflare Dashboard](https://dash.cloudflare.com/) → Turnstile → Add site → 选择 Managed 类型 → 复制 Site Key 和 Secret Key

##### 可选变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `GITHUB_BACKUP_INTERVAL` | `3600` | 自动备份间隔（秒），建议 `1800`（30 分钟） |
| `GH_BRANCH` | `main` | GitHub 备份仓库的分支名 |
| `GH_DB_PATH` | `data/bot_data.db` | 数据库在备份仓库中的存储路径 |
| `VERIFY_SERVER_PORT` | `8080` | CF 验证服务器监听端口（与 Northflank 端口保持一致） |
| `SECRET_KEY` | `your-secret-key-here` | Flask Session 密钥（建议修改为随机字符串） |

#### 4.6 部署

所有配置完成后，点击 **Deploy**。Northflank 会自动拉取代码、构建 Docker 镜像并启动容器。

---

### 第五步：验证部署

在 Northflank 的 **Logs** 标签页，看到以下输出说明部署成功：

```
TG_Talk v1.0.4 - Northflank 模式
[2025-xx-xx] 尝试从 GitHub 恢复数据库...
[2025-xx-xx] ✅ 数据库恢复成功（首次部署显示：使用全新数据库）
[2025-xx-xx] 🌐 启动 CF 验证服务器 (端口 8080)...
[2025-xx-xx] ✅ 验证服务器已启动
[2025-xx-xx] 启动后台备份任务（间隔 1800s）
[2025-xx-xx] 🚀 启动 TG Bot...
```

---

## 使用说明

### 管理机器人命令

向管理机器人（`MANAGER_TOKEN` 对应的 Bot）发送以下操作：

| 操作 | 说明 |
|------|------|
| `/start` | 打开主菜单 |
| 发送子 Bot 的 Token | 添加一个新的子 Bot 开始托管 |

主菜单按钮说明：

| 按钮 | 功能 |
|------|------|
| ➕ 添加机器人 | 引导添加新的子 Bot |
| 🤖 我的机器人 | 查看已托管的子 Bot 列表及管理选项 |
| 📝 全局欢迎语 | 设置所有子 Bot 的默认欢迎语（管理员专属） |
| 👥 用户清单 | 查看所有用户（管理员专属） |
| 📢 广播通知 | 向所有用户发送通知（管理员专属） |
| 🗑️ 清理失效 Bot | 删除已失效的子 Bot（管理员专属） |

### 子 Bot 管理选项

在「我的机器人」中选择一个子 Bot 后可进行以下设置：

| 选项 | 说明 |
|------|------|
| 🔁 切换转发模式 | 直连模式（私聊）↔ 话题模式（Forum 群组） |
| 🔐 验证设置 | 切换验证方式（简单/自定义/CF/人工） |
| 💬 欢迎语设置 | 设置该 Bot 的专属欢迎语 |
| 🗑️ 删除 Bot | 停止托管并删除配置 |

### 验证方式说明

| 验证类型 | 环境变量依赖 | 适用场景 |
|----------|-------------|----------|
| **简单验证码** | 无 | 随机数学题/逻辑题，自动验证，默认方式 |
| **自定义验证题** | 无 | 在机器人内设置自定义问题和答案 |
| **CF Turnstile** | `CF_TURNSTILE_SITE_KEY`、`CF_TURNSTILE_SECRET_KEY`、`VERIFY_SERVER_URL` | 更强的人机验证，需要 Cloudflare 账号 |
| **人工审核** | 无 | 用户提交申请，主人手动点击通过/拒绝 |

### 话题模式（Forum）

话题模式将每个用户的对话映射到 Telegram 超级群的独立话题中，便于多用户管理。

启用方式：
1. 创建一个开启了「话题」功能的 Telegram 超级群
2. 将子 Bot 加入该群并设为管理员（需要管理话题权限）
3. 在子 Bot 管理菜单中切换到「话题模式」，发送群组 ID 完成绑定

---

## 数据备份说明

配置 GitHub 备份后，系统会：

- **启动时**：自动从 GitHub 仓库拉取最新的 `bot_data.db` 数据库
- **运行中**：每隔 `GITHUB_BACKUP_INTERVAL` 秒自动推送备份（默认每小时一次）
- **退出时**：收到停止信号后执行最终备份，确保数据不丢失

备份文件存储在你的私有仓库 `GH_REPO` 的 `GH_DB_PATH` 路径下。

查看备份日志：

```
容器内路径：/app/data/backup.log
```

---

## 更新部署

代码更新后：
1. 将新版本文件推送到你 Fork 的仓库
2. 在 Northflank → Service → **Deployments** 点击 **Redeploy**

或在 Northflank 的 Settings 中开启 **Auto-deploy on push**，推送即自动部署。

---

## 常见问题

**Q: 容器重启后数据会丢失吗？**  
A: 不会。每次启动时脚本会自动从 GitHub 恢复最新数据库。未配置 GitHub 备份则会丢失，强烈建议配置。

**Q: 构建失败，报 `/templates`: not found？**  
A: templates 目录的 HTML 已内嵌在 Dockerfile 中，此错误说明使用了旧版 Dockerfile。请确认使用的是本仓库提供的 Dockerfile。

**Q: CF 验证链接无法访问？**  
A: 检查 `VERIFY_SERVER_URL` 是否填写了 Northflank 分配的公网域名，且 8080 端口已在 Northflank Ports 中添加。

**Q: 子 Bot 添加失败？**  
A: 确认 Bot Token 正确，且该 Bot 没有被其他程序使用（一个 Token 同时只能有一个 Polling 连接）。

**Q: 免费套餐够用吗？**  
A: Northflank 免费套餐支持运行 1 个服务，对于托管少量 Bot 完全够用。资源紧张时建议升级到 512 MB 内存。

---

## 项目结构

```
TG_Talk/
├── host_bot.py         # 主程序：管理机器人 + 子 Bot 逻辑
├── database.py         # SQLite 数据库操作模块
├── verify_server.py    # CF Turnstile 验证 Flask 服务
├── Dockerfile          # Docker 镜像构建（含内嵌 HTML 模板）
├── docker-start.sh     # 容器启动脚本
├── github_backup.sh    # 数据库备份到 GitHub
├── github_restore.sh   # 从 GitHub 恢复数据库
└── .env.northflank     # 环境变量配置参考（不要提交到仓库）
```

---

## License

MIT
最后感谢ryty1提供的代码以及帮助
