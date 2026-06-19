# VPS 流量监控 · 一键部署脚本

通过定时读取 `/proc/net/dev` 统计指定网卡的流量，按自定义周期（如每月某天某时）重置账期，并每天定时把"昨日消耗 / 周期累计 / 剩余可用"推送到 Telegram。

脚本地址：
```
https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/monitor.sh
```

## 功能特性

- 按月自定义重置点（可指定哪一天、几点重置，处理 2 月没有 30/31 日等边界情况）
- 支持初始流量偏移（已经用掉一部分配额时可直接对齐）
- 自动检测服务器重启，重启不会把开机瞬间的计数器跳变算成流量暴增
- 每日定时推送 Telegram 日报，两次推送之间的用量即为"昨日消耗"
- 自动检测默认出网网卡，也可手动指定
- 数据落盘在本地文件，重启 / 重新部署（在不清空数据文件的前提下）不丢历史累计量

## 环境要求

- Linux（依赖 GNU `date` 的相对日期计算，不支持 macOS / BSD date）
- root 权限（写入 `/root/505`、操作 `crontab`）
- 已安装 `curl`、`awk`、`flock`、`grep`（多数发行版默认自带）
- 一个 Telegram Bot 的 Token，以及你要接收消息的 Chat ID

## 部署方法

直接运行远端脚本，不在本地落地保存（运行结束后不会残留脚本文件）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/monitor.sh)
```

> 之所以用 `bash <(curl ...)` 而不是 `curl ... | bash`：脚本里全是交互式 `read` 输入，`curl | bash` 会把标准输入占用掉，导致读不到你的键盘输入；`bash <(...)` 这种进程替换写法不会有这个问题。

按提示依次填写 7 项配置：

| 步骤 | 内容 | 说明 |
|---|---|---|
| 1/7 | Telegram Bot Token | 从 @BotFather 获取 |
| 2/7 | Telegram Chat ID | 接收日报的用户/群组/频道 ID |
| 3/7 | 服务器显示名称 | 日报里显示的名字，默认 `MyVPS` |
| 4/7 | 流量重置日期 | 格式 `日 时:分`，如 `29 00:00` 表示每月 29 日零点重置 |
| 5/7 | 流量配额与初始偏移 | 周期总配额（GB）+ 已用流量（GB，用于对齐） |
| 6/7 | 每日推送时间 | 格式 `时:分`，如 `9:30` |
| 7/7 | 网卡选择 | 默认自动检测出网网卡，可手动覆盖 |

最后会列出配置摘要，输入 `y` 确认部署。脚本会自动：

1. 清理同名旧进程 / 旧 crontab 条目 / 旧数据文件
2. 在 `/root/505/vps_monitor.sh` 生成实际运行的监控脚本
3. 写入两条 crontab：每日定点推送一次、每 5 分钟采样一次
4. 立即跑一次初始化并展示当前状态

⚠️ **输入 Token 时的注意事项**：粘贴前确认输入法是英文状态。中文输入法有时会把 Token 里的英文冒号 `:` 自动转成全角冒号 `：`，导致 Telegram API 返回 `404 Not Found`、消息推送失败。粘贴后建议肉眼检查一下终端回显的内容。

## 部署后的文件

| 路径 | 用途 |
|---|---|
| `/root/505/vps_monitor.sh` | 实际运行的监控脚本 |
| `/root/505/.vps_monitor_data` | 累计字节数 / 账期基准等持久化数据 |
| `/root/505/vps_monitor.log` | 运行日志（自动保留最近 50 行） |
| `/root/505/.vps_lock` | 写数据文件时的文件锁，防止并发写坏 |

两条 crontab 任务（关键字都是 `vps_monitor.sh`）：
- 每日定点：触发 `--report`，推送日报到 Telegram
- 每 5 分钟：无参数运行，采样累计流量

## 常用命令

```bash
# 查看当前流量状态（不推送，仅打印到终端）
/bin/bash /root/505/vps_monitor.sh --test

# 手动触发一次 Telegram 日报（当天已推送过则不会重复推送）
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report

# 查看运行日志
tail -f /root/505/vps_monitor.log

# 查看账本原始数据
cat /root/505/.vps_monitor_data

# 清空账本，下次运行重新对齐（保留配置，不算完全卸载）
/bin/bash /root/505/vps_monitor.sh --reset

# 查看定时任务
crontab -l
```

## 完全清理 / 卸载

按顺序执行以下命令，可以把这个脚本在系统里留下的所有东西彻底清掉：

```bash
# 1. 移除 crontab 里的两条定时任务
crontab -l 2>/dev/null | grep -v "vps_monitor.sh" | crontab -

# 2. 杀掉可能正在运行的进程（一般是 cron 触发的短任务，通常用不到，保险起见执行一下）
ps -ef | grep vps_monitor.sh | grep -v grep | awk '{print $2}' | xargs -r kill -9

# 3. 删除脚本、数据文件、日志、锁文件（整个目录一次性删干净）
rm -rf /root/505
```

**验证是否清理干净：**
```bash
crontab -l            # 不应再出现 vps_monitor.sh 相关的行
ls /root/505 2>/dev/null   # 应该提示目录不存在 / No such file or directory
ps -ef | grep vps_monitor.sh | grep -v grep   # 应该没有任何输出
```

三条都符合预期，就说明卸载彻底了。之后可以用上面【部署方法】里的命令重新部署一份全新的。

## 本次修复的问题（Changelog）

- **修复**：每日推送时间输入 `08`、`09` 这类带前导 0 的小时/分钟时，bash 会把它当八进制数解析，因 8、9 不是合法八进制数字而报错 `value too great for base` / `invalid octal number`。现已统一用 `10#` 前缀强制按十进制解析。
- **修复**：网卡匹配由子串匹配（`grep "$INTERFACE"`）改为锚点匹配，避免 `ens3` 误匹配到 `ens33` 等相似命名的网卡导致流量统计出错。
- **优化**：服务器名称变量由 `HOSTNAME` 改名为 `VPS_NAME`，避免与 bash 内置的 `HOSTNAME` 环境变量同名混淆。

## 已知限制

- 仅适配 Linux + GNU date，不支持 macOS
- 网卡计数器为 32 位时（少数老旧驱动）可能在约 4GB 处溢出，脚本对"计数器变小"的情况按"本次全部计入"处理，极端情况下可能有少量误差
- 重新部署（不先执行【完全清理】）会清空旧的累计数据文件，相当于流量账本从 0 重新开始，请按需先做好记录
