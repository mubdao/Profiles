# VPS 流量监控 一键部署脚本

## 功能特性

- 📊 每天早上 9:00 自动推送流量日报到 Telegram
- 🤖 支持发送 `/report` 给 Bot 随时查看流量情况
- ⚙️ 交互式配置，按提示输入即可，无需手动改脚本
- 🔄 支持初始流量对齐（已用流量校准）
- 🔁 Bot 监听服务开机自启，稳定运行
- 🕐 每 5 分钟自动记账，数据准确

---

## 使用前准备

1. 在 Telegram 搜索 `@BotFather`，发送 `/newbot` 创建 Bot，记下 Token
2. 在 Telegram 搜索 `@userinfobot`，发送任意消息，记下 Chat ID
3. 找到你创建的 Bot，点击 Start（重要！否则 Bot 无法主动发消息）
4. 查询网卡名（部署时也可输入 `auto` 自动检测）：
```bash
ip route get 8.8.8.8 | awk '{print $5; exit}'


bash <(curl -s https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/vps-deploy.sh)


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

