# ClawDock <!-- omit in toc -->

不用再手敲 `docker-compose`，直接执行 `clawdock-start`。

Inspired by Simon Willison's [Running OpenClaw in Docker](https://til.simonwillison.net/llms/openclaw-docker).

- [快速开始](#quickstart)
- [可用命令](#available-commands)
  - [基础操作](#basic-operations)
  - [容器访问](#container-access)
  - [Web UI 与设备](#web-ui--devices)
  - [初始化与配置](#setup--configuration)
  - [维护命令](#maintenance)
  - [工具命令](#utilities)
- [常见工作流](#common-workflows)
  - [查看状态与日志](#check-status-and-logs)
  - [配置 WhatsApp 机器人](#set-up-whatsapp-bot)
  - [排查设备配对问题](#troubleshooting-device-pairing)
  - [修复令牌不一致问题](#fix-token-mismatch-issues)
  - [权限不足](#permission-denied)
- [环境要求](#requirements)

## Quickstart

**安装：**

```bash
mkdir -p ~/.clawdock && curl -sL https://raw.githubusercontent.com/marvel1203/openclaw/main/scripts/shell-helpers/clawdock-helpers.sh -o ~/.clawdock/clawdock-helpers.sh
```

```bash
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.zshrc && source ~/.zshrc
```

**查看可用命令：**

```bash
clawdock-help
```

首次执行命令时，ClawDock 会自动检测 OpenClaw 目录：

- 检查常见路径（如 `~/openclaw`、`~/workspace/openclaw`）
- 找到后会让你确认
- 结果会保存到 `~/.clawdock/config`

**首次配置：**

```bash
clawdock-start
```

```bash
clawdock-fix-token
```

```bash
clawdock-dashboard
```

如果看到 “pairing required”：

```bash
clawdock-devices
```

然后审批对应设备的请求：

```bash
clawdock-approve <request-id>
```

## Available Commands

### Basic Operations

| 命令               | 说明                     |
| ------------------ | ------------------------ |
| `clawdock-start`   | 启动 gateway             |
| `clawdock-stop`    | 停止 gateway             |
| `clawdock-restart` | 重启 gateway             |
| `clawdock-status`  | 查看容器状态             |
| `clawdock-logs`    | 查看实时日志（持续跟随） |

### Container Access

| 命令                      | 说明                        |
| ------------------------- | --------------------------- |
| `clawdock-shell`          | 进入 gateway 容器交互 Shell |
| `clawdock-cli <command>`  | 在容器内执行 OpenClaw CLI   |
| `clawdock-exec <command>` | 在容器内执行任意命令        |

### Web UI & Devices

| 命令                    | 说明                          |
| ----------------------- | ----------------------------- |
| `clawdock-dashboard`    | 在浏览器中打开带认证的 Web UI |
| `clawdock-devices`      | 列出设备配对请求              |
| `clawdock-approve <id>` | 审批指定设备配对请求          |

### Setup & Configuration

| 命令                 | 说明                                    |
| -------------------- | --------------------------------------- |
| `clawdock-fix-token` | 配置 gateway 认证 token（一般只需一次） |

### Maintenance

| 命令               | 说明                             |
| ------------------ | -------------------------------- |
| `clawdock-rebuild` | 重新构建 Docker 镜像             |
| `clawdock-clean`   | 删除所有容器与数据卷（危险操作） |

### Utilities

| 命令                 | 说明                     |
| -------------------- | ------------------------ |
| `clawdock-health`    | 执行 gateway 健康检查    |
| `clawdock-token`     | 显示 gateway 认证 token  |
| `clawdock-cd`        | 跳转到 OpenClaw 项目目录 |
| `clawdock-config`    | 打开 OpenClaw 配置目录   |
| `clawdock-workspace` | 打开工作目录             |
| `clawdock-help`      | 显示全部命令和示例       |

## Common Workflows

### Check Status and Logs

**重启 gateway：**

```bash
clawdock-restart
```

**查看容器状态：**

```bash
clawdock-status
```

**查看实时日志：**

```bash
clawdock-logs
```

### Set Up WhatsApp Bot

**进入容器 shell：**

```bash
clawdock-shell
```

**在容器内登录 WhatsApp：**

```bash
openclaw channels login --channel whatsapp --verbose
```

使用手机 WhatsApp 扫描二维码。

**验证连接：**

```bash
openclaw status
```

### Troubleshooting Device Pairing

**查看待审批的配对请求：**

```bash
clawdock-devices
```

**从 “Pending” 表中复制 Request ID 并审批：**

```bash
clawdock-approve <request-id>
```

然后刷新浏览器。

### Fix Token Mismatch Issues

如果你看到 “gateway token mismatch” 错误：

```bash
clawdock-fix-token
```

该命令会：

1. 从 `.env` 读取 token
2. 写入 OpenClaw 配置
3. 重启 gateway
4. 校验配置

### Permission Denied

**先确认 Docker 正在运行且当前用户有权限：**

```bash
docker ps
```

## Requirements

- 已安装 Docker 与 Docker Compose
- Bash 或 Zsh shell
- 已拉取 OpenClaw 项目（执行过 `docker-setup.sh`）

## Development

**使用全新配置测试（模拟首次安装）：**

```bash
unset CLAWDOCK_DIR && rm -f ~/.clawdock/config && source scripts/shell-helpers/clawdock-helpers.sh
```

Then run any command to trigger auto-detect:

```bash
clawdock-start
```
