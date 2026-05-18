# VPS 流量监控 一键部署脚本

## 功能特性

- 🤖 发送 `/report` 给 Bot 随时查看流量情况
- 📊 今日消耗：统计从当天 `00:00` 到查询时刻的流量
- 📈 周期累计：统计本周期截止查询时刻的总流量
- ⚙️ 交互式配置，按提示输入即可，无需手动改脚本
- 🔄 支持初始流量对齐（已用流量校准）
- 🔁 Bot 监听服务开机自启，稳定运行
- 🕐 每天 `00:00` 自动重置今日消耗基准

-----

## 使用前准备

1. 在 Telegram 搜索 `@BotFather`，发送 `/newbot` 创建 Bot，记下 Token
1. 在 Telegram 搜索 `@userinfobot`，发送任意消息，记下 Chat ID
1. 找到你创建的 Bot，点击 Start（重要！否则 Bot 无法主动发消息）
1. 查询网卡名（部署时输入 `auto` 可自动检测）：

```bash
ip route get 8.8.8.8 | awk '{print $5; exit}'
```

-----

## 一键部署

```bash
bash <(curl -s https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/vps-deploy.sh)
```

按提示依次输入：

|序号|配置项         |说明                            |
|--|------------|------------------------------|
|① |TG Bot Token|BotFather 给的 Token（注意英文冒号 `:`）|
|② |TG Chat ID  |userinfobot 给的 ID             |
|③ |服务器名称       |自定义，用于区分多台 VPS                |
|④ |网卡名         |直接回车默认 `auto` 自动检测            |
|⑤ |流量重置日       |每月几号重置，如 `9`                  |
|⑥ |流量总配额       |套餐总流量，如 `1024`                |
|⑦ |当前已用流量      |本周期已用 GB，不知道填 `0`             |

-----

## Bot 指令

|指令       |功能        |
|---------|----------|
|`/report`|立即推送当前流量报告|

-----

## 报告样式

```
📅 流量报告 | Hytron
━━━━━━━━━━━━━━━━
⏳ 距离重置： 22 天  时间 30.33%
📊 今日消耗： 1.25 GB
📈 周期累计： 115.00 GB | 11.23%
🚀 剩余可用： 909.00 GB (88.77%)
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

## 卸载 / 重新部署

```bash
ps -ef | grep tg_bot.sh | grep -v grep | awk '{print $2}' | xargs -r kill -9; \
systemctl stop tgbot 2>/dev/null; \
systemctl disable tgbot 2>/dev/null; \
(crontab -l 2>/dev/null | grep -v "vps_monitor.sh") | crontab -; \
rm -f /root/505/vps_monitor.sh /root/505/tg_bot.sh /root/505/.vps_monitor_data /root/505/.tg_offset /root/505/vps_monitor.log /etc/systemd/system/tgbot.service; \
systemctl daemon-reload; \
echo "🔥 清除完成"
```

> ⚠️ 注意：此操作会删除流量数据账本，重新部署时需重新填写已用流量。

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
- 多台 VPS 使用同一个 Bot 时，`/report` 指令两台都会响应并各自推送
- 时区默认为 `Asia/Shanghai`（北京时间）
- Token 中的冒号必须是英文冒号 `:`，不能是中文冒号 `：`