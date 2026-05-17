# VPS 流量监控 一键部署脚本

基于 [英俊柴 VPS 流量审计 Pro V18.5](https://github.com/mubdao/Profiles) 的一键部署工具。  
支持每日自动推送流量日报到 Telegram，并可通过 Bot 指令随时主动查询。

-----

## 功能特性

- 📊 每天早上 9:00 自动推送流量日报到 Telegram
- 🤖 支持发送 `/report` 给 Bot 随时查看流量情况
- ⚙️ 交互式配置，按提示输入即可，无需手动改脚本
- 🔄 支持初始流量对齐（已用流量校准）
- 🔁 Bot 监听服务开机自启，稳定运行
- 🕐 每 5 分钟自动记账，数据准确

-----

## 使用前准备

**1. 创建 Telegram Bot，获取 Token**

- 在 Telegram 搜索 `@BotFather`
- 发送 `/newbot`，按提示操作
- 记下返回的 Token，格式如：`123456789:AAFxxx`

**2. 获取你的 Chat ID**

- 在 Telegram 搜索 `@userinfobot`
- 发送任意消息，记下返回的 `Id`

**3. 先给 Bot 发一条消息**（重要！）

- 找到你创建的 Bot，点击 Start 或发任意内容
- 否则 Bot 无法主动给你发消息

**4. 查询网卡名**（部署时也可输入 `auto` 自动检测）

```bash
ip route get 8.8.8.8 | awk '{print $5; exit}'
```

-----

## 一键部署

```bash
bash <(curl -s https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/vps-deploy.sh)
```

运行后按提示依次输入：

|序号|配置项         |说明                |
|--|------------|------------------|
|① |TG Bot Token|BotFather 给的 Token|
|② |TG Chat ID  |userinfobot 给的 ID |
|③ |服务器名称       |自定义，用于区分多台 VPS    |
|④ |网卡名         |输入 `auto` 可自动检测   |
|⑤ |流量重置日       |每月几号重置，如 `9`      |
|⑥ |流量总配额       |套餐总流量，如 `1024`    |
|⑦ |当前已用流量      |本周期已用 GB，不知道填 `0` |

-----

## Bot 指令

|指令       |功能        |
|---------|----------|
|`/report`|立即推送当前流量报告|

-----

## 日报样式

```
📅 流量日报 | Hytron
━━━━━━━━━━━━━━━━
⏳ 距离重置： 23 天  时间 28.50%
📊 昨日消耗： 3.08 GB
📈 周期累计： 106.99 GB | 10.45%
🚀 剩余可用： 917.01 GB (89.55%)
```

-----

## 常用维护命令

```bash
# 查看当前流量数据
/bin/bash /root/505/vps_monitor.sh --test

# 手动触发推送
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report

# 查看日志
tail -f /root/505/vps_monitor.log

# 查看原始数据
cat /root/505/.vps_monitor_data

# 重置账本（重装系统后使用）
/bin/bash /root/505/vps_monitor.sh --reset

# 查看 Bot 服务状态
systemctl status tgbot
```

-----

## 文件说明

|文件                                 |说明        |
|-----------------------------------|----------|
|`/root/505/vps_monitor.sh`         |流量监控主脚本   |
|`/root/505/tg_bot.sh`              |Bot 指令监听脚本|
|`/root/505/.vps_monitor_data`      |流量数据账本    |
|`/root/505/vps_monitor.log`        |运行日志      |
|`/etc/systemd/system/tgbot.service`|Bot 开机自启服务|

-----

## 注意事项

- 脚本基于 `/proc/net/dev` 统计流量，统计的是**入站+出站合计**
- 双向各 1024GB 的套餐，配额填 `1024`（按合计算）或 `2048`（按各自算）请根据服务商规则决定
- 多台 VPS 使用同一个 Bot 时，`/report` 指令两台都会响应并各自推送
- 时区默认为 `Asia/Shanghai`（北京时间）