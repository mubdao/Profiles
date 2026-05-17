#!/bin/bash
# =================================================================
# 一键部署脚本: VPS 流量监控 + TG Bot 指令
# 功能: 自动配置监控脚本、Bot监听、定时任务
# =================================================================

export TZ='Asia/Shanghai'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   VPS 流量监控 一键部署脚本${NC}"
echo -e "${GREEN}========================================${NC}\n"

# --- 交互式配置输入 ---
read -p "① TG Bot Token: " TG_TOKEN
read -p "② TG Chat ID: " CHAT_ID
read -p "③ 服务器名称 (如 Hytron): " HOSTNAME
read -p "④ 网卡名 (如 eth0，不知道请输入 auto): " INTERFACE

if [[ "$INTERFACE" == "auto" ]]; then
    INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    echo -e "   ${YELLOW}自动检测到网卡: ${INTERFACE}${NC}"
fi

read -p "⑤ 流量重置日 (每月几号，如 9): " RESET_DAY
read -p "⑥ 流量总配额 (GB，如 1024): " TRAFFIC_QUOTA
read -p "⑦ 当前周期已用流量 (GB，不知道填 0): " INIT_USAGE_GB

echo -e "\n${YELLOW}--- 配置确认 ---${NC}"
echo "  TG Token   : $TG_TOKEN"
echo "  Chat ID    : $CHAT_ID"
echo "  服务器名称  : $HOSTNAME"
echo "  网卡        : $INTERFACE"
echo "  重置日      : 每月 ${RESET_DAY} 号"
echo "  总配额      : ${TRAFFIC_QUOTA} GB"
echo "  已用流量    : ${INIT_USAGE_GB} GB"
echo ""
read -p "确认无误？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${RED}已取消部署。${NC}"
    exit 0
fi

# --- 创建工作目录 ---
mkdir -p /root/505

# --- 写入监控主脚本 ---
echo -e "\n${GREEN}[1/4] 正在写入监控脚本...${NC}"
python3 << PYEOF
script = r"""#!/bin/bash
export TZ='Asia/Shanghai'
TG_TOKEN="${TG_TOKEN}"
CHAT_ID="${CHAT_ID}"
HOSTNAME="${HOSTNAME}"
TRAFFIC_RESET="${RESET_DAY} 00:00"
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
    echo -e "\n[已重置] 流量账单已删除，下次运行将重新对齐。"
    exit 0
fi
RAW_INFO=\$(grep "\$INTERFACE" /proc/net/dev)
[[ -z "\$RAW_INFO" ]] && { echo "\$(date): 错误 - 找不到网卡 \$INTERFACE" >> "\$LOG_FILE"; exit 1; }
CURRENT_RAW=\$(echo "\$RAW_INFO" | awk '{print \$2 + \$10}')
UPTIME_SEC=\$(awk '{print \$1}' /proc/uptime | cut -d. -f1)
BOOT_TIME=\$(((\$(date +%s) - UPTIME_SEC)))
if [ ! -f "\$DATA_FILE" ] || [ ! -s "\$DATA_FILE" ]; then
    INIT_BYTES=\$(awk "BEGIN {print \$INIT_USAGE_GB * 1024^3}")
    echo "\$INIT_BYTES \$CURRENT_RAW 0 0 0 \$INIT_BYTES \$BOOT_TIME" > "\$DATA_FILE"
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
        DELTA=\$(awk "BEGIN {print \$CURRENT_RAW - \$LAST_RAW}")
    else
        DELTA=\$CURRENT_RAW
    fi
fi
LIFE_TOTAL=\$(awk "BEGIN {print \$LIFE_TOTAL + \$DELTA}")
CUR_STAMP=\$(date +%s)
calc_reset_point() {
    local year_month=\$1
    local res=\$(date -d "\${year_month}-\${RESET_DAY} \${RESET_TIME}:00" +%s 2>/dev/null)
    if [[ -z "\$res" ]]; then
        res=\$(date -d "\${year_month}-01 +1 month -1 day \${RESET_TIME}:00" +%s)
    fi
    echo "\$res"
}
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
MTD_BYTES=\$(awk "BEGIN {val=\$LIFE_TOTAL - \$MONTH_BASE; print (val<0 ? 0 : val)}")
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
DAILY_BYTES=\$(awk "BEGIN {val=\$LIFE_TOTAL - \$DAILY_BASE; print (val<0 ? 0 : val)}")
REALTIME_DAILY_GB=\$(awk "BEGIN {printf \"%.2f\", \$DAILY_BYTES / 1024^3}")
ESCAPED_HOST=\$(echo "\$HOSTNAME" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
if [[ "\$1" == "--test" ]]; then
    echo -e "\n[流量审计 V18.5]"
    echo "流量日报 | \${HOSTNAME}"
    echo "距离重置： \${DAYS_LEFT} 天 时间 \${TIME_PERCENT}%"
    echo "昨日消耗： \${REALTIME_DAILY_GB} GB"
    echo "周期累计： \${MTD_GB} GB | \${USED_PERCENT}%"
    echo "剩余可用： \${REMAIN_GB} GB (\${REMAIN_PERCENT}%)"
    exit 0
fi
TODAY=\$(date +%F)
if [[ "\$1" == "--report" && "\$LAST_REPORT_DATE" != "\$TODAY" ]]; then
    MSG_TRAFFIC="\$(printf '📅 <b>流量日报 | %s</b>\n━━━━━━━━━━━━━━━━\n⏳ <b>距离重置：</b> <code>%s 天</code> 时间 <code>%s%%</code>\n📊 <b>昨日消耗：</b> <code>%s GB</code>\n📈 <b>周期累计：</b> <code>%s GB | %s%%</code>\n🚀 <b>剩余可用：</b> <b>%s GB (%s%%)</b>' "\$ESCAPED_HOST" "\$DAYS_LEFT" "\$TIME_PERCENT" "\$REALTIME_DAILY_GB" "\$MTD_GB" "\$USED_PERCENT" "\$REMAIN_GB" "\$REMAIN_PERCENT")"
    RES_REP=\$(curl -s -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=\${CHAT_ID}" \
        --data-urlencode "text=\${MSG_TRAFFIC}" \
        --data-urlencode "parse_mode=HTML")
    if [[ \$RES_REP == *'"ok":true'* ]]; then
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
"""
with open('/root/505/vps_monitor.sh', 'w') as f:
    f.write(script)
print('监控脚本写入成功')
PYEOF

chmod +x /root/505/vps_monitor.sh
echo -e "${GREEN}  ✅ 监控脚本写入完成${NC}"

# --- 写入 Bot 监听脚本 ---
echo -e "${GREEN}[2/4] 正在写入 Bot 监听脚本...${NC}"
python3 << PYEOF
script = r"""#!/bin/bash
export TZ='Asia/Shanghai'
TG_TOKEN="${TG_TOKEN}"
CHAT_ID="${CHAT_ID}"
OFFSET_FILE="/root/505/.tg_offset"
OFFSET=0
[ -f "\$OFFSET_FILE" ] && OFFSET=\$(cat "\$OFFSET_FILE")
while true; do
    UPDATES=\$(curl -s "https://api.telegram.org/bot\${TG_TOKEN}/getUpdates?offset=\${OFFSET}&timeout=30")
    IDS=\$(echo "\$UPDATES" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*')
    TEXTS=\$(echo "\$UPDATES" | grep -o '"text":"[^"]*"' | grep -o '"[^"]*"\$' | tr -d '"')
    for ID in \$IDS; do
        OFFSET=\$((ID + 1))
        echo "\$OFFSET" > "\$OFFSET_FILE"
    done
    if echo "\$TEXTS" | grep -q "/report"; then
        sed -i "s/\$(date +%F)/2000-01-01/" /root/505/.vps_monitor_data
        TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report
    fi
    sleep 3
done
"""
with open('/root/505/tg_bot.sh', 'w') as f:
    f.write(script)
print('Bot脚本写入成功')
PYEOF

chmod +x /root/505/tg_bot.sh
echo -e "${GREEN}  ✅ Bot 监听脚本写入完成${NC}"

# --- 写入 systemd 服务 ---
echo -e "${GREEN}[3/4] 正在配置开机自启服务...${NC}"
cat > /etc/systemd/system/tgbot.service << 'EOF'
[Unit]
Description=TG Bot Listener
After=network.target

[Service]
ExecStart=/bin/bash /root/505/tg_bot.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tgbot
systemctl restart tgbot
echo -e "${GREEN}  ✅ Bot 服务启动完成${NC}"

# --- 写入定时任务 ---
echo -e "${GREEN}[4/4] 正在配置定时任务...${NC}"
(crontab -l 2>/dev/null | grep -v "vps_monitor.sh"; \
echo "0 9 * * * TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report >/dev/null 2>&1"; \
echo "*/5 * * * * TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh >/dev/null 2>&1") | crontab -
echo -e "${GREEN}  ✅ 定时任务配置完成${NC}"

# --- 测试 ---
echo -e "\n${YELLOW}--- 本地测试 ---${NC}"
/bin/bash /root/505/vps_monitor.sh --test

echo -e "\n${YELLOW}--- 测试 TG 推送 ---${NC}"
TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   🎉 部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "每天 09:00 自动推送日报"
echo -e "发送 /report 给 Bot 可随时查看流量"
echo -e "${GREEN}========================================${NC}\n"
