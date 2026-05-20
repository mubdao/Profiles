# VPS 流量监控 · 使用手册

每天定时推送流量日报到 Telegram，记录周期累计用量和昨日消耗。

-----

## 一、安装

SSH 登录服务器后，复制粘贴下面这条命令回车执行：

```bash
bash <(curl -s https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/monitorinstaller.sh)
```

向导会依次问你 7 个问题，按提示填入即可，**直接回车则使用括号内的默认值**。

|步骤|问的内容              |默认值              |
|--|------------------|-----------------|
|1 |Telegram Bot Token|必填，不能跳过          |
|2 |Telegram Chat ID  |必填，不能跳过          |
|3 |服务器显示名            |`MyVPS`          |
|4 |流量重置日期            |`1 00:00`（每月1日零点）|
|5 |周期配额 / 初始偏移       |`500` GB / `0` GB|
|6 |每日推送时间            |`9:30`           |
|7 |监控网卡              |自动检测推荐           |

最后确认一次，输入 `y` 回车，自动完成安装。

-----

## 二、日常使用命令

### 查看当前状态（不推送，只在终端显示）

```bash
/bin/bash /root/505/vps_monitor.sh --test
```

显示内容示例：

```
📅 流量日报 | MyVPS
⏳ 距离重置： 9 天  时间 70.21%
📊 昨日消耗： 1.23 GB
📈 周期累计： 87.45 GB | 17.49%
🚀 剩余可用： 412.55 GB (82.51%)
```

### 立即手动推送一次到 Telegram

```bash
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report
```

> 注意：同一天内只会推送一次，重复执行不会重复发送。

### 查看定时任务（确认自动推送是否生效）

```bash
crontab -l
```

正常应该看到两条记录：

- `*/5 * * *` 开头的：每5分钟记账一次（后台静默运行）
- `30 9 * * *` 开头的：每天9:30自动推送日报（时间是你安装时设置的）

### 实时查看运行日志

```bash
tail -f /root/505/vps_monitor.log
```

按 `Ctrl + C` 退出。

### 查看原始账本数据

```bash
cat /root/505/.vps_monitor_data
```

7个数字依次是：累计总字节 / 上次网卡读数 / 月基准 / 上次重置时间戳 / 上次推送日期 / 日基准 / 上次开机时间。看不懂没关系，正常情况不需要手动看这个。

-----

## 三、重置与卸载

### 重置流量账本（服务器重装、流量清零后用）

```bash
/bin/bash /root/505/vps_monitor.sh --reset
```

账本清空，下次运行会重新从零开始计算。定时任务和脚本本身不受影响。

### 重置月累计基准（账期对不上时用）

```bash
sed -i 's/^\([^ ]\+ [^ ]\+\) [^ ]\+/\1 0/' /root/505/.vps_monitor_data
/bin/bash /root/505/vps_monitor.sh --test
```

### 完全卸载（删除所有文件和定时任务）

```bash
ps -ef | grep vps_monitor.sh | grep -v grep | awk '{print $2}' | xargs -r kill -9
(crontab -l 2>/dev/null | grep -v "vps_monitor.sh") | crontab -
rm -rf /root/505
echo "✅ 已完全卸载"
```

-----

## 四、重新安装 / 修改配置

直接重新运行安装命令即可，安装脚本会自动清理旧版本：

```bash
bash <(curl -s https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/monitorinstaller.sh)
```

-----

## 五、常见问题

**Q：安装完没收到 Telegram 消息？**
先用 `--test` 确认数据正常，再用 `--report` 手动推送一次，看终端有没有报错。检查 Token 和 Chat ID 是否填对。

**Q：昨日消耗是怎么算的？**
是两次成功推送之间产生的流量差值。比如今天 9:30 推送了，明天 9:30 再推送，「昨日消耗」就是这24小时内的用量。

**Q：服务器重启后会不会乱？**
不会，脚本检测到重启后会自动建立新的采样基准，不会重复计算。

**Q：想改推送时间怎么办？**
重新运行安装命令，在第6步填新的时间即可。

-----

## 六、文件位置速查

|文件  |路径                           |说明        |
|----|-----------------------------|----------|
|监控脚本|`/root/505/vps_monitor.sh`   |核心程序      |
|账本数据|`/root/505/.vps_monitor_data`|流量记录（隐藏文件）|
|运行日志|`/root/505/vps_monitor.log`  |最近50条日志   |