# VPS 流量监控 一键部署脚本

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
