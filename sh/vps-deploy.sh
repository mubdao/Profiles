#!/bin/bash
# =================================================================
# 一键部署脚本: VPS 流量监控 + TG Bot 指令
# =================================================================

export TZ='Asia/Shanghai'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TEMPLATE_URL="https://raw.githubusercontent.com/mubdao/Profiles/refs/heads/main/sh/vps-monitor-template.sh"

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

# --- 下载模板并替换占位符 ---
echo -e "\n${GREEN}[1/4] 正在下载并生成监控脚本...${NC}"
curl -s "$TEMPLATE_URL" -o /root/505/vps_monitor.sh

if [[ ! -s /root/505/vps_monitor.sh ]]; then
    echo -e "${RED}下载失败，请检查网络或GitHub地址。${NC}"
    exit 1
fi

sed -i "s|__TG_TOKEN__|${TG_TOKEN}|g" /root/505/vps_monitor.sh
sed -i "s|__CHAT_ID__|${CHAT_ID}|g" /root/505/vps_monitor.sh
sed -i "s|__HOSTNAME__|${HOSTNAME}|g" /root/505/vps_monitor.sh
sed -i "s|__RESET_DAY__|${RESET_DAY}|g" /root/505/vps_monitor.sh
sed -i "s|__INIT_USAGE_GB__|${INIT_USAGE_GB}|g" /root/505/vps_monitor.sh
sed -i "s|__INTERFACE__|${INTERFACE}|g" /root/505/vps_monitor.sh
sed -i "s|__TRAFFIC_QUOTA__|${TRAFFIC_QUOTA}|g" /root/505/vps_monitor.sh

chmod +x /root/505/vps_monitor.sh
echo -e "${GREEN}  ✅ 监控脚本生成完成${NC}"

# --- 写入 Bot 监听脚本 ---
echo -e "${GREEN}[2/4] 正在写入 Bot 监听脚本...${NC}"
cat > /root/505/tg_bot.sh << BOTEOF
#!/bin/bash
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
        OFFSET=\$(( ID + 1 ))
        echo "\$OFFSET" > "\$OFFSET_FILE"
    done
    if echo "\$TEXTS" | grep -q "/report"; then
        sed -i "s/\$(date +%F)/2000-01-01/" /root/505/.vps_monitor_data
        TZ='Asia/Shanghai' /bin/bash /root/505/vps_monitor.sh --report
    fi
    sleep 3
done
BOTEOF

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
