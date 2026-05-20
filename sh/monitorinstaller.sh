#!/bin/bash

export TZ='Asia/Shanghai'
export LC_ALL=C

# ── 颜色定义 ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║     VPS 流量监控 · 一键部署向导 V18.5    ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${RESET}"

# ── 1. TG Token ──
while true; do
    echo -e "${BOLD}[1/7] Telegram Bot Token${RESET}"
    read -rp "    → 请输入 Token: " INPUT_TOKEN
    INPUT_TOKEN=$(echo "$INPUT_TOKEN" | xargs)
    if [[ -z "$INPUT_TOKEN" ]]; then
        echo -e "${RED}    ✗ Token 不能为空，请重新输入。${RESET}\n"
    else
        TG_TOKEN="$INPUT_TOKEN"
        echo -e "${GREEN}    ✓ Token 已录入${RESET}\n"
        break
    fi
done

# ── 2. TG Chat ID ──
while true; do
    echo -e "${BOLD}[2/7] Telegram Chat ID${RESET}"
    read -rp "    → 请输入 Chat ID: " INPUT_CHATID
    INPUT_CHATID=$(echo "$INPUT_CHATID" | xargs)
    if [[ -z "$INPUT_CHATID" ]]; then
        echo -e "${RED}    ✗ Chat ID 不能为空，请重新输入。${RESET}\n"
    else
        CHAT_ID="$INPUT_CHATID"
        echo -e "${GREEN}    ✓ Chat ID 已录入${RESET}\n"
        break
    fi
done

# ── 3. 服务器显示名 ──
echo -e "${BOLD}[3/7] 服务器显示名称${RESET}"
read -rp "    → 请输入名称（直接回车使用默认 MyVPS）: " INPUT_HOSTNAME
INPUT_HOSTNAME=$(echo "$INPUT_HOSTNAME" | xargs)
HOSTNAME="${INPUT_HOSTNAME:-MyVPS}"
echo -e "${GREEN}    ✓ 显示名: ${HOSTNAME}${RESET}\n"

# ── 4. 流量重置日期 ──
while true; do
    echo -e "${BOLD}[4/7] 流量重置日期${RESET}"
    echo -e "    格式: 日 时:分，例如 ${CYAN}29 00:00${RESET} 表示每月29日零点"
    read -rp "    → 请输入重置时间（直接回车使用默认 1 00:00）: " INPUT_RESET
    INPUT_RESET=$(echo "$INPUT_RESET" | xargs)
    INPUT_RESET="${INPUT_RESET:-1 00:00}"
    RESET_DAY_TEST=$(echo "$INPUT_RESET" | awk '{print $1}')
    RESET_TIME_TEST=$(echo "$INPUT_RESET" | awk '{print $2}')
    if [[ -z "$RESET_DAY_TEST" || -z "$RESET_TIME_TEST" ]]; then
        echo -e "${RED}    ✗ 格式无效，请重新输入（例如: 29 00:00）${RESET}\n"
        continue
    fi
    TEST_STAMP=$(date -d "2026-01-01 ${RESET_TIME_TEST}:00" +%s 2>/dev/null)
    if [[ -z "$TEST_STAMP" ]]; then
        echo -e "${RED}    ✗ 时间格式无效，请重新输入${RESET}\n"
        continue
    fi
    TRAFFIC_RESET="$INPUT_RESET"
    echo -e "${GREEN}    ✓ 重置时间: 每月 ${RESET_DAY_TEST} 日 ${RESET_TIME_TEST}${RESET}\n"
    break
done

# ── 5. 流量配额与初始偏移 ──
echo -e "${BOLD}[5/7] 流量配额与初始偏移${RESET}"

while true; do
    read -rp "    → 周期总配额 GB（直接回车使用默认 500）: " INPUT_QUOTA
    INPUT_QUOTA=$(echo "$INPUT_QUOTA" | xargs)
    INPUT_QUOTA="${INPUT_QUOTA:-500}"
    if ! [[ "$INPUT_QUOTA" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}    ✗ 请输入有效数字${RESET}"
        continue
    fi
    TRAFFIC_QUOTA="$INPUT_QUOTA"
    break
done

while true; do
    echo -e "    提示: 初始偏移用于对齐已使用的流量（若从头开始填 0）"
    read -rp "    → 初始已用流量 GB（直接回车使用默认 0）: " INPUT_INIT
    INPUT_INIT=$(echo "$INPUT_INIT" | xargs)
    INPUT_INIT="${INPUT_INIT:-0}"
    if ! [[ "$INPUT_INIT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}    ✗ 请输入有效数字${RESET}"
        continue
    fi
    INIT_USAGE_GB="$INPUT_INIT"
    echo -e "${GREEN}    ✓ 配额: ${TRAFFIC_QUOTA} GB，初始偏移: ${INIT_USAGE_GB} GB${RESET}\n"
    break
done

# ── 6. 每日推送时间 ──
while true; do
    echo -e "${BOLD}[6/7] 每日推送时间${RESET}"
    echo -e "    格式: 时:分，例如 ${CYAN}9:30${RESET} 表示每天早上9点30分推送"
    echo -e "    提示: 两次推送之间的流量即为「昨日消耗」"
    read -rp "    → 请输入推送时间（直接回车使用默认 9:30）: " INPUT_PUSH_TIME
    INPUT_PUSH_TIME=$(echo "$INPUT_PUSH_TIME" | xargs)
    INPUT_PUSH_TIME="${INPUT_PUSH_TIME:-9:30}"
    PUSH_HOUR=$(echo "$INPUT_PUSH_TIME" | cut -d: -f1)
    PUSH_MIN=$(echo "$INPUT_PUSH_TIME" | cut -d: -f2)
    if ! [[ "$PUSH_HOUR" =~ ^[0-9]+$ && "$PUSH_MIN" =~ ^[0-9]+$ ]] \
        || [[ "$PUSH_HOUR" -gt 23 || "$PUSH_MIN" -gt 59 ]]; then
        echo -e "${RED}    ✗ 格式无效，请重新输入（例如: 9:30 或 18:00）${RESET}\n"
        continue
    fi
    CRON_HOUR=$PUSH_HOUR
    CRON_MIN=$PUSH_MIN
    echo -e "${GREEN}    ✓ 推送时间: 每天 ${PUSH_HOUR}:$(printf '%02d' $PUSH_MIN)${RESET}\n"
    break
done

# ── 7. 网卡选择 ──
echo -e "${BOLD}[7/7] 网卡选择${RESET}"

# 自动检测主网卡
AUTO_IF=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
[[ -z "$AUTO_IF" ]] && AUTO_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)

echo -e "    可用网卡列表:"
ip -o link show | awk -F': ' '{print $2}' | grep -v lo | while read -r iface; do
    if [[ "$iface" == "$AUTO_IF" ]]; then
        echo -e "      ${CYAN}● ${iface}${RESET}（自动检测推荐）"
    else
        echo -e "      ○ ${iface}"
    fi
done

echo ""
read -rp "    → 请输入网卡名（直接回车使用自动检测: ${AUTO_IF}）: " INPUT_IF
INPUT_IF=$(echo "$INPUT_IF" | xargs)
INTERFACE="${INPUT_IF:-$AUTO_IF}"

if ! grep -q "$INTERFACE" /proc/net/dev 2>/dev/null; then
    echo -e "${YELLOW}    ⚠ 警告: 未在 /proc/net/dev 中找到 ${INTERFACE}，已记录但请核实${RESET}\n"
else
    echo -e "${GREEN}    ✓ 网卡: ${INTERFACE}${RESET}\n"
fi

# ── 确认配置 ──
echo -e "${CYAN}${BOLD}══════════════ 配置确认 ══════════════${RESET}"
echo -e "  服务器名称:   ${BOLD}${HOSTNAME}${RESET}"
echo -e "  TG Token:     ${BOLD}${TG_TOKEN:0:10}...${RESET}"
echo -e "  Chat ID:      ${BOLD}${CHAT_ID}${RESET}"
echo -e "  重置时间:     ${BOLD}每月 ${TRAFFIC_RESET}${RESET}"
echo -e "  每日推送:     ${BOLD}每天 ${PUSH_HOUR}:$(printf '%02d' $PUSH_MIN)${RESET}"
echo -e "  流量配额:     ${BOLD}${TRAFFIC_QUOTA} GB${RESET}"
echo -e "  初始偏移:     ${BOLD}${INIT_USAGE_GB} GB${RESET}"
echo -e "  监控网卡:     ${BOLD}${INTERFACE}${RESET}"
echo -e "${CYAN}${BOLD}══════════════════════════════════════${RESET}\n"

read -rp "确认部署？(y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消部署。${RESET}"
    exit 0
fi

# ── 停止旧进程 & 清理 ──
echo -e "\n${YELLOW}▶ 清理旧版本...${RESET}"
ps -ef | grep vps_monitor.sh | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
(crontab -l 2>/dev/null | grep -v "vps_monitor.sh") | crontab - 2>/dev/null
rm -f /root/505/.vps_monitor_data /root/505/vps_monitor.log /root/505/.vps_lock

# ── 写入监控脚本 ──
echo -e "${YELLOW}▶ 部署监控脚本...${RESET}"
mkdir -p /root/505

cat > /root/505/vps_monitor.sh << SCRIPTEOF
#!/bin/bash

export TZ='Asia/Shanghai'

TG_TOKEN="${TG_TOKEN}"
CHAT_ID="${CHAT_ID}"
HOSTNAME="${HOSTNAME}"
TRAFFIC_RESET="${TRAFFIC_RESET}"
INIT_USAGE_GB=${INIT_USAGE_GB}
INTERFACE="${INTERFACE}"
TRAFFIC_QUOTA=${TRAFFIC_QUOTA}

DATA_DIR="/root/505"
DATA_FILE="\$DATA_DIR/.vps_monitor_data"
LOG_FILE="\$DATA_DIR/vps_monitor.log"
LOCK_FILE="\$DATA_DIR/.vps_lock"
export LC_ALL=C
mkdir -p "\$DATA_DIR"

for cmd in curl awk date flock grep; do
    command -v \$cmd &> /dev/null || exit 1
done

RESET_DAY=\$(echo "\$TRAFFIC_RESET" | awk '{print \$1}')
RESET_TIME=\$(echo "\$TRAFFIC_RESET" | awk '{print \$2}')
TEST_STAMP=\$(date -d "2026-01-01 \${RESET_TIME}:00" +%s 2>/dev/null)
if [[ -z "\$TEST_STAMP" ]]; then
    echo "\$(date): [致命错误] TRAFFIC_RESET 时间格式无效: \${TRAFFIC_RESET}" >> "\$LOG_FILE"
    exit 1
fi

if [[ "\$1" == "--reset" ]]; then
    rm -f "\$DATA_FILE"
    echo -e "\n\033[32m✨ [已重置] 流量账单已删除，下次运行将重新对齐。\033[0m"
    exit 0
fi

RAW_INFO=\$(grep "\$INTERFACE" /proc/net/dev)
[[ -z "\$RAW_INFO" ]] && { echo "\$(date): 错误 - 找不到网卡 \$INTERFACE" >> "\$LOG_FILE"; exit 1; }
CURRENT_RAW=\$(echo "\$RAW_INFO" | awk '{printf "%.0f", \$2 + \$10}')
UPTIME_SEC=\$(awk '{print \$1}' /proc/uptime | cut -d. -f1)
BOOT_TIME=\$(( \$(date +%s) - UPTIME_SEC ))

RESET_DAY_VAL=\$(echo "\$TRAFFIC_RESET" | awk '{print \$1}')
RESET_TIME_VAL=\$(echo "\$TRAFFIC_RESET" | awk '{print \$2}')

calc_reset_point() {
    local year_month=\$1
    local res=\$(date -d "\${year_month}-\${RESET_DAY} \${RESET_TIME}:00" +%s 2>/dev/null)
    if [[ -z "\$res" ]]; then
        res=\$(date -d "\${year_month}-01 +1 month -1 day \${RESET_TIME}:00" +%s)
    fi
    echo "\$res"
}

if [ ! -f "\$DATA_FILE" ] || [ ! -s "\$DATA_FILE" ]; then
    INIT_BYTES=\$(awk "BEGIN {printf \"%.0f\", \$INIT_USAGE_GB * 1024^3}")
    INIT_RESET_MARK=\$(calc_reset_point "\$(date +%Y-%m)")
    if [[ "\$(date +%s)" -lt "\$INIT_RESET_MARK" ]]; then
        INIT_RESET_MARK=\$(calc_reset_point "\$(date -d "\$(date +%Y-%m-01) -1 month" +%Y-%m)")
    fi
    echo "\$INIT_BYTES \$CURRENT_RAW 0 \$INIT_RESET_MARK 0 \$INIT_BYTES \$BOOT_TIME" > "\$DATA_FILE"
fi
read LIFE_TOTAL LAST_RAW MONTH_BASE LAST_RESET_MARK LAST_REPORT_DATE DAILY_BASE LAST_BOOT_TIME < "\$DATA_FILE"

HAS_REBOOTED=0
BOOT_DIFF=\$((BOOT_TIME - LAST_BOOT_TIME))
[[ \${BOOT_DIFF#-} -gt 10 ]] && HAS_REBOOTED=1

if [ "\$HAS_REBOOTED" -eq 1 ]; then
    DELTA=0
    echo "\$(date): [系统重启] 已建立新采样基准。" >> "\$LOG_FILE"
else
    if awk "BEGIN {exit (\$CURRENT_RAW >= \$LAST_RAW ? 0 : 1)}"; then
        DELTA=\$(awk "BEGIN {printf \"%.0f\", \$CURRENT_RAW - \$LAST_RAW}")
    else
        DELTA=\$CURRENT_RAW
    fi
fi

LIFE_TOTAL=\$(awk "BEGIN {printf \"%.0f\", \$LIFE_TOTAL + \$DELTA}")
CUR_STAMP=\$(date +%s)

CUR_MONTH_RESET=\$(calc_reset_point "\$(date +%Y-%m)")

if [[ "\$CUR_STAMP" -ge "\$CUR_MONTH_RESET" ]]; then
    NEXT_RESET_STAMP=\$(calc_reset_point "\$(date -d "\$(date +%Y-%m-01) +1 month" +%Y-%m)")
    CYCLE_START_STAMP=\$CUR_MONTH_RESET
    if [[ "\$LAST_RESET_MARK" -lt "\$CUR_MONTH_RESET" ]]; then
        MONTH_BASE=\$LIFE_TOTAL
        LAST_RESET_MARK=\$CUR_MONTH_RESET
        echo "\$(date): [重置成功] 已跨越账期节点。" >> "\$LOG_FILE"
    fi
else
    NEXT_RESET_STAMP=\$CUR_MONTH_RESET
    CYCLE_START_STAMP=\$(calc_reset_point "\$(date -d "\$(date +%Y-%m-01) -1 month" +%Y-%m)")
fi

DAYS_LEFT=\$(( (NEXT_RESET_STAMP - CUR_STAMP) / 86400 + 1 ))
MTD_BYTES=\$(awk "BEGIN {val=\$LIFE_TOTAL - \$MONTH_BASE; printf \"%.0f\", (val<0 ? 0 : val)}")
MTD_GB=\$(awk "BEGIN {printf \"%.2f\", \$MTD_BYTES / 1024^3}")

REMAIN_GB=\$(awk "BEGIN {printf \"%.2f\", \$TRAFFIC_QUOTA - \$MTD_GB}")
[[ \$(awk "BEGIN {print (\$REMAIN_GB < 0 ? 1 : 0)}") -eq 1 ]] && REMAIN_GB="0.00"

if [[ \$(awk "BEGIN {print (\$TRAFFIC_QUOTA > 0 ? 1 : 0)}") -eq 1 ]]; then
    USED_PERCENT=\$(awk "BEGIN {printf \"%.2f\", (\$MTD_GB / \$TRAFFIC_QUOTA) * 100}")
else
    USED_PERCENT="0.00"
fi
[[ \$(awk "BEGIN {print (\$USED_PERCENT > 100 ? 1 : 0)}") -eq 1 ]] && USED_PERCENT="100.00"
REMAIN_PERCENT=\$(awk "BEGIN {printf \"%.2f\", 100 - \$USED_PERCENT}")

TOTAL_CYCLE_SEC=\$(awk "BEGIN {print \$NEXT_RESET_STAMP - \$CYCLE_START_STAMP}")
ELAPSED_SEC=\$(awk "BEGIN {print \$CUR_STAMP - \$CYCLE_START_STAMP}")

if [[ \$(awk "BEGIN {print (\$TOTAL_CYCLE_SEC > 0 ? 1 : 0)}") -eq 1 ]]; then
    TIME_PERCENT=\$(awk "BEGIN {printf \"%.2f\", (\$ELAPSED_SEC / \$TOTAL_CYCLE_SEC) * 100}")
else
    TIME_PERCENT="0.00"
fi
[[ \$(awk "BEGIN {print (\$TIME_PERCENT > 100 ? 1 : 0)}") -eq 1 ]] && TIME_PERCENT="100.00"
[[ \$(awk "BEGIN {print (\$TIME_PERCENT < 0 ? 1 : 0)}") -eq 1 ]] && TIME_PERCENT="0.00"

DAILY_BYTES=\$(awk "BEGIN {val=\$LIFE_TOTAL - \$DAILY_BASE; printf \"%.0f\", (val<0 ? 0 : val)}")
REALTIME_DAILY_GB=\$(awk "BEGIN {printf \"%.2f\", \$DAILY_BYTES / 1024^3}")

ESCAPED_HOST=\$(echo "\$HOSTNAME" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

if [[ "\$1" == "--test" ]]; then
    echo -e "\n\033[34m🔍 [流量审计 V18.5]\033[0m"
    echo "━━━━━━━━━━━━━━━━"
    echo "📅 流量日报 | \${HOSTNAME}"
    echo "⏳ 距离重置： \${DAYS_LEFT} 天 时间 \${TIME_PERCENT}%"
    echo "📊 昨日消耗： \${REALTIME_DAILY_GB} GB"
    echo "📈 周期累计： \${MTD_GB} GB | \${USED_PERCENT}%"
    echo "🚀 剩余可用： \${REMAIN_GB} GB (\${REMAIN_PERCENT}%)"
    exit 0
fi

TODAY=\$(date +%F)
if [[ "\$1" == "--report" && "\$LAST_REPORT_DATE" != "\$TODAY" ]]; then
    MSG_TRAFFIC="📅 <b>流量日报 | \${ESCAPED_HOST}</b>
━━━━━━━━━━━━━━━━
⏳ <b>距离重置：</b> <code>\${DAYS_LEFT} 天</code> 时间 <code>\${TIME_PERCENT}%</code>
📊 <b>昨日消耗：</b> <code>\${REALTIME_DAILY_GB} GB</code>
📈 <b>周期累计：</b> <code>\${MTD_GB} GB | \${USED_PERCENT}%</code>
🚀 <b>剩余可用：</b> <b>\${REMAIN_GB} GB (\${REMAIN_PERCENT}%)</b>"

    RES_REP=\$(curl -s -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=\${CHAT_ID}" \
        --data-urlencode "text=\${MSG_TRAFFIC}" \
        --data-urlencode "parse_mode=HTML")

    if [[ \$RES_REP == *"\"ok\":true"* ]]; then
        LAST_REPORT_DATE=\$TODAY
        DAILY_BASE=\$LIFE_TOTAL
    else
        echo "\$(date): 日报推送失败: \$RES_REP" >> "\$LOG_FILE"
    fi
fi

(
    flock -x 9
    echo "\$LIFE_TOTAL \$CURRENT_RAW \$MONTH_BASE \$LAST_RESET_MARK \$LAST_REPORT_DATE \$DAILY_BASE \$BOOT_TIME" > "\$DATA_FILE"
    echo "\$(date): MTD \${MTD_GB}GB, Today \${REALTIME_DAILY_GB}GB" >> "\$LOG_FILE"
    tmp_log=\$(tail -n 50 "\$LOG_FILE")
    echo "\$tmp_log" > "\$LOG_FILE"
) 9>"\$LOCK_FILE"

exit 0
SCRIPTEOF

chmod +x /root/505/vps_monitor.sh

# ── 写入 Crontab ──
echo -e "${YELLOW}▶ 配置 Crontab...${RESET}"
(
    crontab -l 2>/dev/null | grep -v "vps_monitor.sh"
    echo "${CRON_MIN} ${CRON_HOUR} * * * TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report >/dev/null 2>&1"
    echo "*/5 * * * * TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh >/dev/null 2>&1"
) | crontab -

# ── 初次运行 ──
echo -e "${YELLOW}▶ 初始化数据...${RESET}"
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh

# ── 完成 ──
echo -e "\n${GREEN}${BOLD}✅ 部署完成！${RESET}\n"
echo -e "当前监控状态:"
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --test

echo -e "\n${CYAN}${BOLD}── 常用命令 ──${RESET}"
echo -e "  测试输出:   ${BOLD}/bin/bash /root/505/vps_monitor.sh --test${RESET}"
echo -e "  手动日报:   ${BOLD}TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report${RESET}"
echo -e "  查看日志:   ${BOLD}tail -f /root/505/vps_monitor.log${RESET}"
echo -e "  查看账本:   ${BOLD}cat /root/505/.vps_monitor_data${RESET}"
echo -e "  完全重置:   ${BOLD}/bin/bash /root/505/vps_monitor.sh --reset${RESET}"
echo -e "  查看定时:   ${BOLD}crontab -l${RESET}"
echo ""
