---
title: "CentOS 8 部署（飞书 + 钉钉）"
summary: "在 CentOS 8 上用非 Docker 和 Docker 两种方式部署 OpenClaw，并启用飞书与钉钉"
read_when:
  - "你要在 CentOS 8 服务器部署 OpenClaw"
  - "你希望同时接入飞书和钉钉"
---

# CentOS 8 部署（飞书 + 钉钉）

本文给出一份可直接执行的 CentOS 8 服务器部署手册，包含：

- 非 Docker 部署
- Docker 部署
- 飞书接入
- 钉钉接入（通过插件机制）

> 如果你只需要飞书，优先参考 [Feishu](/channels/feishu) 获取平台侧配置细节。

## 0. 前置准备

- 一台可 SSH 登录的 CentOS 8 服务器
- 具备 sudo 权限
- 已准备好模型提供商 API Key（如 OpenAI/Anthropic 等）
- 飞书应用凭据（`appId`、`appSecret`）
- 可用的钉钉插件安装源（推荐 npm 包；或你自己维护的本地插件目录）

## 1. 非 Docker 部署（推荐）

### 1.1 安装系统依赖和 Node 22+

```bash
sudo dnf -y update
sudo dnf -y install curl ca-certificates git
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf -y install nodejs
node -v
npm -v
```

### 1.2 安装 OpenClaw

```bash
sudo npm install -g openclaw@latest
openclaw --version
```

### 1.3 执行初始化向导并安装网关服务

```bash
openclaw onboard --install-daemon
```

完成后建议检查：

```bash
openclaw doctor
openclaw gateway status
openclaw logs --follow
```

### 1.4 安装飞书与钉钉插件

```bash
openclaw plugins install @openclaw/feishu --pin
openclaw plugins install @your-scope/openclaw-dingtalk --pin
openclaw plugins list
```

说明：

- `@openclaw/feishu` 为飞书插件
- 钉钉插件通过插件机制安装；上面示例使用 npm 包 `@your-scope/openclaw-dingtalk`
- 如果你的团队使用本地插件目录分发，可在仓库目录下执行：`openclaw plugins install ./extensions/dingtalk --pin`

### 1.5 配置飞书与钉钉通道

优先用交互式方式：

```bash
openclaw channels add
```

如果你选择手动配置，可编辑 `~/.openclaw/openclaw.json`，飞书配置示例：

```json5
{
  channels: {
    feishu: {
      enabled: true,
      accounts: {
        main: {
          appId: "cli_xxx",
          appSecret: "xxx",
        },
      },
    },
  },
}
```

钉钉通道字段以你安装的钉钉插件 `configSchema` / README 为准。

### 1.6 防火墙与访问建议

只在本机访问控制台时，使用默认 `127.0.0.1:18789` 即可；远程管理建议通过 SSH 隧道：

```bash
ssh -N -L 18789:127.0.0.1:18789 <user>@<server-ip>
```

然后在本地浏览器打开 `http://127.0.0.1:18789/`。

### 1.7 验证联通性

```bash
openclaw channels status --probe
openclaw logs --follow
```

在飞书和钉钉各发送一条测试消息，确认机器人都能收发。

## 2. Docker 部署

### 2.1 安装 Docker Engine 和 Compose 插件

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

重新登录后验证：

```bash
docker version
docker compose version
```

### 2.2 拉取代码并启动 Docker 快速部署

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
./docker-setup.sh
```

脚本会构建/拉取镜像、执行 onboarding 并启动网关。

### 2.3 在容器环境安装飞书与钉钉插件

```bash
docker compose run --rm openclaw-cli plugins install @openclaw/feishu --pin
docker compose run --rm openclaw-cli plugins install @your-scope/openclaw-dingtalk --pin
docker compose run --rm openclaw-cli plugins list
```

如果你必须用本地目录安装钉钉插件，需要确保插件目录已通过 volume 映射进入容器，再执行本地路径安装。

### 2.4 在容器环境配置通道

```bash
docker compose run --rm openclaw-cli channels add
docker compose run --rm openclaw-cli channels status --probe
```

如需查看日志：

```bash
docker compose logs -f openclaw-gateway
```

## 3. 运维命令速查

非 Docker：

```bash
openclaw gateway status
openclaw gateway restart
openclaw logs --follow
openclaw plugins doctor
```

Docker：

```bash
docker compose ps
docker compose restart openclaw-gateway
docker compose run --rm openclaw-cli gateway status
docker compose logs -f openclaw-gateway
```

## 4. 常见问题

### 4.1 `openclaw: command not found`

```bash
npm prefix -g
echo "$PATH"
```

确保 `$(npm prefix -g)/bin` 在 PATH 中。

### 4.2 通道已配置但没有消息

- 先查 `openclaw logs --follow`（Docker 下用 `docker compose logs -f openclaw-gateway`）
- 飞书检查应用发布状态与事件订阅（`im.message.receive_v1`）
- 钉钉按插件文档核对签名、回调 URL、凭据字段

### 4.3 服务开机不自启

```bash
openclaw gateway install
openclaw gateway status
```

Docker 场景确认 `docker.service` 已 `enable`，并将 compose 启动流程接入系统启动脚本或 systemd。
