#!/bin/bash

# =============================================
# Snell 管理脚本
# 支持版本检测、自定义安装、TFO 管理等
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

SNELL_BIN="/usr/local/bin/snell-server"
SNELL_CONF="/etc/snell/snell-server.conf"
SNELL_SURGE="/etc/snell/config.txt"
SNELL_SERVICE="/etc/systemd/system/snell.service"

# =============================================
# 工具函数
# =============================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}请以 root 权限运行此脚本${RESET}"
        exit 1
    fi
}

get_system_type() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/arch-release ]; then
        echo "archlinux"
    else
        echo "unknown"
    fi
}

wait_for_apt() {
    if [ "$(get_system_type)" = "debian" ]; then
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
              fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
              fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
            echo -e "${YELLOW}等待 apt 进程释放锁...${RESET}"
            sleep 2
        done
    fi
}

install_deps() {
    local sys=$(get_system_type)
    echo -e "${GREEN}安装依赖包...${RESET}"
    case "$sys" in
        debian)
            wait_for_apt
            apt-get update -qq
            apt-get install -y wget unzip curl >/dev/null 2>&1
            ;;
        centos)
            yum install -y wget unzip curl >/dev/null 2>&1
            ;;
        archlinux)
            pacman -Sy --noconfirm wget unzip curl >/dev/null 2>&1
            ;;
        *)
            echo -e "${RED}不支持的系统类型${RESET}"
            exit 1
            ;;
    esac
}

check_installed() {
    [ -f "$SNELL_BIN" ]
}

check_running() {
    systemctl is-active --quiet snell.service
}

get_local_version() {
    if check_installed; then
        $SNELL_BIN -version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+'
    else
        echo "未安装"
    fi
}

get_latest_version() {
    # 从 nssurge 官方下载页推断最新版，通过尝试下载来确认
    # 使用 GitHub releases API 获取 passeway/Snell 发布的最新版本号
    local latest
    latest=$(curl -s --connect-timeout 5 \
        "https://api.github.com/repos/passeway/Snell/releases/latest" \
        | grep '"tag_name"' \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1)
    if [ -z "$latest" ]; then
        echo "获取失败"
    else
        echo "$latest"
    fi
}

get_arch() {
    local arch=$(uname -m)
    if [ "$arch" = "aarch64" ]; then
        echo "aarch64"
    else
        echo "amd64"
    fi
}

get_download_url() {
    local ver="$1"
    local arch=$(get_arch)
    echo "https://dl.nssurge.com/snell/snell-server-${ver}-linux-${arch}.zip"
}

get_server_ip() {
    curl -s --connect-timeout 5 https://checkip.amazonaws.com \
        || curl -s --connect-timeout 5 https://api.ipify.org
}

get_ip_country() {
    local ip="$1"
    curl -s --connect-timeout 5 "https://ipinfo.io/${ip}/country" 2>/dev/null || echo "UN"
}

conf_get() {
    local key="$1"
    grep -E "^${key}\s*=" "$SNELL_CONF" 2>/dev/null | sed 's/.*= *//' | tr -d ' '
}

conf_set() {
    local key="$1"
    local val="$2"
    if grep -qE "^${key}\s*=" "$SNELL_CONF" 2>/dev/null; then
        sed -i "s|^${key}\s*=.*|${key} = ${val}|" "$SNELL_CONF"
    else
        echo "${key} = ${val}" >> "$SNELL_CONF"
    fi
}

conf_del() {
    local key="$1"
    sed -i "/^${key}\s*=/d" "$SNELL_CONF"
}

update_surge_config() {
    local port=$(conf_get "listen" | grep -oE '[0-9]+$')
    local psk=$(conf_get "psk")
    local ip=$(get_server_ip)
    local country=$(get_ip_country "$ip")
    local tfo=$(conf_get "tfo")

    local line="${country} = snell, ${ip}, ${port}, psk = ${psk}, version = 5, reuse = true"
    [ "$tfo" = "true" ] && line="${line}, tfo = true"

    mkdir -p /etc/snell
    echo "$line" > "$SNELL_SURGE"
}

# =============================================
# 安装
# =============================================

install_snell() {
    if check_installed; then
        echo -e "${YELLOW}Snell 已安装，如需重装请先卸载${RESET}"
        return
    fi

    # 获取最新版本
    echo -e "${CYAN}正在获取最新版本信息...${RESET}"
    local latest_ver=$(get_latest_version)
    if [ "$latest_ver" = "获取失败" ]; then
        echo -e "${YELLOW}无法获取最新版本，使用默认版本 v5.0.1${RESET}"
        latest_ver="v5.0.1"
    fi
    echo -e "${GREEN}将安装版本：${latest_ver}${RESET}"

    # 自定义端口
    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认随机: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    # 验证端口合法性
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    # 自定义 PSK
    local default_psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入 PSK [默认随机: ${default_psk}]: " input_psk
    local psk=${input_psk:-$default_psk}

    # 安装依赖
    install_deps

    # 下载二进制
    local url=$(get_download_url "$latest_ver")
    echo -e "${GREEN}正在下载 Snell ${latest_ver}...${RESET}"
    wget -q --show-progress "$url" -O /tmp/snell-server.zip || {
        echo -e "${RED}下载失败，请检查网络${RESET}"
        exit 1
    }

    unzip -o /tmp/snell-server.zip -d /usr/local/bin >/dev/null || {
        echo -e "${RED}解压失败${RESET}"
        rm -f /tmp/snell-server.zip
        exit 1
    }
    rm -f /tmp/snell-server.zip
    chmod +x "$SNELL_BIN"

    # 创建用户
    if ! id "snell" &>/dev/null; then
        useradd -r -s /usr/sbin/nologin snell
    fi

    # 写配置
    mkdir -p /etc/snell
    cat > "$SNELL_CONF" << EOF
[snell-server]
listen = ::0:${port}
psk = ${psk}
ipv6 = true
EOF

    # 写 systemd 服务
    cat > "$SNELL_SERVICE" << EOF
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=snell
Group=snell
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
LimitNOFILE=32768
Restart=on-failure
StandardOutput=journal
StandardError=journal
SyslogIdentifier=snell-server

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable snell >/dev/null 2>&1
    systemctl start snell

    sleep 2

    if check_running; then
        echo -e "${GREEN}Snell 安装并启动成功！${RESET}"
    else
        echo -e "${RED}Snell 启动失败，请查看日志：journalctl -u snell.service -n 20${RESET}"
        return 1
    fi

    update_surge_config

    echo ""
    echo -e "${CYAN}=== Surge 节点配置 ===${RESET}"
    cat "$SNELL_SURGE"
    echo ""
}

# =============================================
# 更新
# =============================================

update_snell() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    echo -e "${CYAN}正在检查版本...${RESET}"
    local local_ver=$(get_local_version)
    local latest_ver=$(get_latest_version)

    echo -e "当前版本：${YELLOW}${local_ver}${RESET}"
    echo -e "最新版本：${GREEN}${latest_ver}${RESET}"

    if [ "$latest_ver" = "获取失败" ]; then
        echo -e "${RED}无法获取最新版本信息${RESET}"
        return
    fi

    if [ "$local_ver" = "$latest_ver" ]; then
        echo -e "${GREEN}已是最新版本，无需更新${RESET}"
        return
    fi

    echo -e "${GREEN}发现新版本，开始更新...${RESET}"
    systemctl stop snell

    local url=$(get_download_url "$latest_ver")
    wget -q --show-progress "$url" -O /tmp/snell-server.zip || {
        echo -e "${RED}下载失败${RESET}"
        systemctl start snell
        return 1
    }

    unzip -o /tmp/snell-server.zip -d /usr/local/bin >/dev/null
    rm -f /tmp/snell-server.zip
    chmod +x "$SNELL_BIN"

    systemctl start snell
    sleep 2

    if check_running; then
        echo -e "${GREEN}更新成功，当前版本：$(get_local_version)${RESET}"
    else
        echo -e "${RED}更新后启动失败${RESET}"
    fi
}

# =============================================
# 卸载
# =============================================

uninstall_snell() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    read -p "确认卸载 Snell？[y/N]: " confirm
    [ "${confirm,,}" != "y" ] && echo "已取消" && return

    systemctl stop snell 2>/dev/null
    systemctl disable snell 2>/dev/null
    rm -f "$SNELL_SERVICE"
    systemctl daemon-reload
    rm -f "$SNELL_BIN"
    rm -rf /etc/snell

    echo -e "${GREEN}Snell 已卸载${RESET}"
}

# =============================================
# 修改配置
# =============================================

change_port() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    local current_port=$(conf_get "listen" | grep -oE '[0-9]+$')
    echo -e "当前端口：${CYAN}${current_port}${RESET}"
    read -p "请输入新端口: " new_port

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}端口不合法${RESET}"
        return
    fi

    conf_set "listen" "::0:${new_port}"
    systemctl restart snell
    update_surge_config
    echo -e "${GREEN}端口已修改为 ${new_port}，服务已重启${RESET}"
}

change_psk() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    local current_psk=$(conf_get "psk")
    echo -e "当前 PSK：${CYAN}${current_psk}${RESET}"
    local default_psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入新 PSK [默认随机: ${default_psk}]: " new_psk
    new_psk=${new_psk:-$default_psk}

    conf_set "psk" "$new_psk"
    systemctl restart snell
    update_surge_config
    echo -e "${GREEN}PSK 已修改，服务已重启${RESET}"
}

toggle_tfo() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    local current_tfo=$(conf_get "tfo")
    if [ "$current_tfo" = "true" ]; then
        conf_del "tfo"
        systemctl restart snell
        update_surge_config
        echo -e "${GREEN}TFO 已关闭，服务已重启${RESET}"
    else
        conf_set "tfo" "true"
        systemctl restart snell
        update_surge_config
        echo -e "${GREEN}TFO 已开启，服务已重启${RESET}"
    fi
}

# =============================================
# 显示配置
# =============================================

show_config() {
    if ! check_installed; then
        echo -e "${RED}Snell 未安装${RESET}"
        return
    fi

    echo -e "${CYAN}=== 服务配置 ===${RESET}"
    cat "$SNELL_CONF"
    echo ""
    echo -e "${CYAN}=== Surge 节点配置 ===${RESET}"
    if [ -f "$SNELL_SURGE" ]; then
        cat "$SNELL_SURGE"
    else
        update_surge_config
        cat "$SNELL_SURGE"
    fi
    echo ""
}

# =============================================
# 主菜单
# =============================================

show_menu() {
    clear

    local local_ver latest_ver install_status run_status tfo_status update_hint

    if check_installed; then
        local_ver=$(get_local_version)
        install_status="${GREEN}已安装 ${local_ver}${RESET}"
    else
        local_ver="未安装"
        install_status="${RED}未安装${RESET}"
    fi

    if check_running; then
        run_status="${GREEN}运行中${RESET}"
    else
        run_status="${RED}未运行${RESET}"
    fi

    local tfo_val=$(conf_get "tfo")
    if [ "$tfo_val" = "true" ]; then
        tfo_status="${GREEN}已开启${RESET}"
    else
        tfo_status="${YELLOW}已关闭${RESET}"
    fi

    # 版本检测提示（仅已安装时）
    update_hint=""
    if check_installed; then
        latest_ver=$(get_latest_version)
        if [ "$latest_ver" != "获取失败" ] && [ "$latest_ver" != "$local_ver" ]; then
            update_hint=" ${RED}[有新版本: ${latest_ver}]${RESET}"
        fi
    fi

    echo -e "${GREEN}========== Snell 管理工具 ==========${RESET}"
    echo -e " 安装状态：${install_status}${update_hint}"
    echo -e " 运行状态：${run_status}"
    echo -e " TFO 状态：${tfo_status}"
    echo -e "${GREEN}=====================================${RESET}"
    echo " 1. 安装 Snell"
    echo " 2. 更新 Snell"
    echo " 3. 卸载 Snell"
    echo "-------------------------------------"
    if check_running; then
        echo " 4. 停止服务"
    else
        echo " 4. 启动服务"
    fi
    echo " 5. 重启服务"
    echo " 6. 查看服务状态"
    echo "-------------------------------------"
    echo " 7. 修改端口"
    echo " 8. 修改 PSK"
    echo " 9. TFO 开关"
    echo " 10. 查看配置 / Surge 节点"
    echo "-------------------------------------"
    echo " 0. 退出"
    echo -e "${GREEN}=====================================${RESET}"
    read -p "请输入选项: " choice
    echo ""
}

# =============================================
# 主逻辑
# =============================================

trap 'echo -e "\n${RED}已中断${RESET}"; exit 1' INT

main() {
    check_root

    while true; do
        show_menu

        case "$choice" in
            1) install_snell ;;
            2) update_snell ;;
            3) uninstall_snell ;;
            4)
                if check_running; then
                    systemctl stop snell && echo -e "${GREEN}服务已停止${RESET}"
                else
                    systemctl start snell && echo -e "${GREEN}服务已启动${RESET}"
                fi
                ;;
            5)
                systemctl restart snell
                sleep 1
                check_running && echo -e "${GREEN}服务已重启${RESET}" || echo -e "${RED}重启失败${RESET}"
                ;;
            6) systemctl status snell --no-pager ;;
            7) change_port ;;
            8) change_psk ;;
            9) toggle_tfo ;;
            10) show_config ;;
            0) echo -e "${GREEN}再见${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac

        echo ""
        read -p "按 Enter 继续..."
    done
}

main
