#!/bin/bash

# =============================================
# 代理协议统一管理脚本
# 支持 Snell / SS2022 / AnyTLS
# 用法: bash proxy.sh
# =============================================

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# 路径常量
SNELL_BIN="/usr/local/bin/snell-server"
SNELL_CONF="/etc/snell/snell-server.conf"
SNELL_SURGE="/etc/snell/config.txt"
SNELL_SERVICE="/etc/systemd/system/snell.service"

SS_BIN="/usr/local/bin/ssserver"
SS_CONF="/etc/ss2022/config.json"
SS_SURGE="/etc/ss2022/config.txt"
SS_SERVICE="/etc/systemd/system/ss2022.service"

ANYTLS_BIN="/usr/local/bin/anytls-server"
ANYTLS_CONF="/etc/anytls/config.json"
ANYTLS_SURGE="/etc/anytls/config.txt"
ANYTLS_SERVICE="/etc/systemd/system/anytls.service"

# =============================================
# 通用工具函数
# =============================================

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}请以 root 权限运行此脚本${RESET}"
        exit 1
    fi
}

get_system_type() {
    if [ -f /etc/debian_version ]; then echo "debian"
    elif [ -f /etc/redhat-release ]; then echo "centos"
    elif [ -f /etc/arch-release ]; then echo "archlinux"
    else echo "unknown"
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
            apt-get install -y wget unzip curl openssl >/dev/null 2>&1
            ;;
        centos)
            yum install -y wget unzip curl openssl >/dev/null 2>&1
            ;;
        archlinux)
            pacman -Sy --noconfirm wget unzip curl openssl >/dev/null 2>&1
            ;;
        *)
            echo -e "${RED}不支持的系统类型${RESET}"
            exit 1
            ;;
    esac
}

get_arch() {
    local arch=$(uname -m)
    if [ "$arch" = "aarch64" ]; then echo "aarch64"
    else echo "amd64"
    fi
}

get_server_ip() {
    curl -s --connect-timeout 5 https://checkip.amazonaws.com \
        || curl -s --connect-timeout 5 https://api.ipify.org
}

get_ip_country() {
    local ip="$1"
    curl -s --connect-timeout 5 "https://ipinfo.io/${ip}/country" 2>/dev/null || echo "UN"
}

get_latest_github_version() {
    local repo="$1"
    local ver
    ver=$(curl -s --connect-timeout 5 \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"tag_name"' \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1)
    [ -z "$ver" ] && echo "获取失败" || echo "$ver"
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

press_enter() {
    echo ""
    read -p "按 Enter 继续..."
}

hr() {
    echo "--------------------------------------------------------"
}

# =============================================
# Snell 相关函数
# =============================================

snell_installed() { [ -f "$SNELL_BIN" ]; }
snell_running() { systemctl is-active --quiet snell.service 2>/dev/null; }

snell_local_version() {
    snell_installed && $SNELL_BIN -version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "未安装"
}

snell_latest_version() {
    get_latest_github_version "passeway/Snell"
}

snell_conf_get() {
    local key="$1"
    grep -E "^${key}\s*=" "$SNELL_CONF" 2>/dev/null | sed 's/.*= *//' | tr -d ' '
}

snell_conf_set() {
    local key="$1" val="$2"
    if grep -qE "^${key}\s*=" "$SNELL_CONF" 2>/dev/null; then
        sed -i "s|^${key}\s*=.*|${key} = ${val}|" "$SNELL_CONF"
    else
        echo "${key} = ${val}" >> "$SNELL_CONF"
    fi
}

snell_conf_del() {
    sed -i "/^${1}\s*=/d" "$SNELL_CONF"
}

snell_update_surge() {
    local port=$(snell_conf_get "listen" | grep -oE '[0-9]+$')
    local psk=$(snell_conf_get "psk")
    local tfo=$(snell_conf_get "tfo")
    local ip=$(get_server_ip)
    local country=$(get_ip_country "$ip")
    local line="${country} = snell, ${ip}, ${port}, psk = ${psk}, version = 5, reuse = true"
    [ "$tfo" = "true" ] && line="${line}, tfo = true"
    mkdir -p /etc/snell
    echo "$line" > "$SNELL_SURGE"
}

snell_install() {
    if snell_installed; then
        echo -e "${YELLOW}Snell 已安装，如需重装请先卸载${RESET}"
        return
    fi

    echo -e "${CYAN}正在获取最新版本...${RESET}"
    local ver=$(snell_latest_version)
    [ "$ver" = "获取失败" ] && ver="v5.0.1" && echo -e "${YELLOW}获取失败，使用默认版本 v5.0.1${RESET}"
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认随机: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    local default_psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入 PSK [默认随机: ${default_psk}]: " input_psk
    local psk=${input_psk:-$default_psk}

    install_deps

    local arch=$(get_arch)
    local url="https://dl.nssurge.com/snell/snell-server-${ver}-linux-${arch}.zip"
    echo -e "${GREEN}正在下载 Snell ${ver}...${RESET}"
    wget -q --show-progress "$url" -O /tmp/snell.zip || { echo -e "${RED}下载失败${RESET}"; return 1; }
    unzip -o /tmp/snell.zip -d /usr/local/bin >/dev/null || { echo -e "${RED}解压失败${RESET}"; rm -f /tmp/snell.zip; return 1; }
    rm -f /tmp/snell.zip
    chmod +x "$SNELL_BIN"

    id "snell" &>/dev/null || useradd -r -s /usr/sbin/nologin snell
    mkdir -p /etc/snell

    cat > "$SNELL_CONF" << EOF
[snell-server]
listen = ::0:${port}
psk = ${psk}
ipv6 = true
EOF

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

    if snell_running; then
        echo -e "${GREEN}Snell 安装并启动成功！${RESET}"
        snell_update_surge
        echo ""
        echo -e "${CYAN}Surge 节点配置：${RESET}"
        cat "$SNELL_SURGE"
    else
        echo -e "${RED}Snell 启动失败，请查看日志：journalctl -u snell.service -n 20${RESET}"
    fi
}

snell_uninstall() {
    if ! snell_installed; then echo -e "${RED}Snell 未安装${RESET}"; return; fi
    read -p "确认卸载 Snell？[y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "已取消" && return
    systemctl stop snell 2>/dev/null
    systemctl disable snell 2>/dev/null
    rm -f "$SNELL_SERVICE"
    systemctl daemon-reload
    rm -f "$SNELL_BIN"
    rm -rf /etc/snell
    echo -e "${GREEN}Snell 已卸载${RESET}"
}

snell_update() {
    if ! snell_installed; then echo -e "${RED}Snell 未安装${RESET}"; return; fi
    local local_ver=$(snell_local_version)
    echo -e "${CYAN}正在检查版本...${RESET}"
    local latest_ver=$(snell_latest_version)
    echo -e "当前版本：${YELLOW}${local_ver}${RESET}"
    echo -e "最新版本：${GREEN}${latest_ver}${RESET}"
    [ "$latest_ver" = "获取失败" ] && echo -e "${RED}无法获取最新版本${RESET}" && return
    [ "$local_ver" = "$latest_ver" ] && echo -e "${GREEN}已是最新版本${RESET}" && return

    echo -e "${GREEN}开始更新...${RESET}"
    systemctl stop snell
    local arch=$(get_arch)
    local url="https://dl.nssurge.com/snell/snell-server-${latest_ver}-linux-${arch}.zip"
    wget -q --show-progress "$url" -O /tmp/snell.zip || { echo -e "${RED}下载失败${RESET}"; systemctl start snell; return 1; }
    unzip -o /tmp/snell.zip -d /usr/local/bin >/dev/null
    rm -f /tmp/snell.zip
    chmod +x "$SNELL_BIN"
    systemctl start snell
    sleep 2
    snell_running && echo -e "${GREEN}更新成功：$(snell_local_version)${RESET}" || echo -e "${RED}更新后启动失败${RESET}"
}

snell_menu() {
    while true; do
        clear
        local ver=$(snell_local_version)
        local port=$(snell_conf_get "listen" | grep -oE '[0-9]+$')
        local tfo=$(snell_conf_get "tfo")
        local status run_status tfo_status
        snell_running && run_status="${GREEN}运行中${RESET}" || run_status="${RED}未运行${RESET}"
        [ "$tfo" = "true" ] && tfo_status="${GREEN}已开启${RESET}" || tfo_status="${YELLOW}已关闭${RESET}"
        hr
        echo -e "  Snell ${ver} | ${run_status} | 端口: ${port} | TFO: ${tfo_status}"
        hr
        if snell_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新 Snell"
        echo "  4. 修改端口"
        echo "  5. 修改 PSK"
        echo "  6. TFO 开关"
        echo "  7. 查看配置"
        echo "  8. 查看 Surge 节点"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if snell_running; then
                    systemctl stop snell && echo -e "${GREEN}服务已停止${RESET}"
                else
                    systemctl start snell && echo -e "${GREEN}服务已启动${RESET}"
                fi
                ;;
            2) systemctl restart snell; sleep 1; snell_running && echo -e "${GREEN}已重启${RESET}" || echo -e "${RED}重启失败${RESET}" ;;
            3) snell_update ;;
            4)
                local cur_port=$(snell_conf_get "listen" | grep -oE '[0-9]+$')
                echo -e "当前端口：${CYAN}${cur_port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    snell_conf_set "listen" "::0:${new_port}"
                    systemctl restart snell
                    snell_update_surge
                    echo -e "${GREEN}端口已修改为 ${new_port}${RESET}"
                else
                    echo -e "${RED}端口不合法${RESET}"
                fi
                ;;
            5)
                local cur_psk=$(snell_conf_get "psk")
                echo -e "当前 PSK：${CYAN}${cur_psk}${RESET}"
                local def_psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
                read -p "请输入新 PSK [默认随机: ${def_psk}]: " new_psk
                new_psk=${new_psk:-$def_psk}
                snell_conf_set "psk" "$new_psk"
                systemctl restart snell
                snell_update_surge
                echo -e "${GREEN}PSK 已修改${RESET}"
                ;;
            6)
                local cur_tfo=$(snell_conf_get "tfo")
                if [ "$cur_tfo" = "true" ]; then
                    snell_conf_del "tfo"
                    echo -e "${GREEN}TFO 已关闭${RESET}"
                else
                    snell_conf_set "tfo" "true"
                    echo -e "${GREEN}TFO 已开启${RESET}"
                fi
                systemctl restart snell
                snell_update_surge
                ;;
            7)
                echo -e "${CYAN}=== 服务配置 ===${RESET}"
                cat "$SNELL_CONF"
                ;;
            8)
                echo -e "${CYAN}=== Surge 节点配置 ===${RESET}"
                if [ -f "$SNELL_SURGE" ]; then cat "$SNELL_SURGE"
                else snell_update_surge && cat "$SNELL_SURGE"; fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# SS2022 相关函数
# =============================================

ss_installed() { [ -f "$SS_BIN" ]; }
ss_running() { systemctl is-active --quiet ss2022.service 2>/dev/null; }

ss_local_version() {
    ss_installed && $SS_BIN --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "未安装"
}

ss_latest_version() {
    get_latest_github_version "shadowsocks/shadowsocks-rust"
}

ss_conf_get() {
    local key="$1"
    python3 -c "import json,sys; d=json.load(open('$SS_CONF')); print(d.get('$key',''))" 2>/dev/null
}

ss_update_surge() {
    local port=$(ss_conf_get "server_port")
    local password=$(ss_conf_get "password")
    local ip=$(get_server_ip)
    local country=$(get_ip_country "$ip")
    local line="${country} = ss, ${ip}, ${port}, encrypt-method = 2022-blake3-aes-128-gcm, password = ${password}"
    mkdir -p /etc/ss2022
    echo "$line" > "$SS_SURGE"
}

ss_install() {
    if ss_installed; then
        echo -e "${YELLOW}SS2022 已安装，如需重装请先卸载${RESET}"
        return
    fi

    echo -e "${CYAN}正在获取最新版本...${RESET}"
    local ver=$(ss_latest_version)
    [ "$ver" = "获取失败" ] && { echo -e "${RED}无法获取版本信息，请检查网络${RESET}"; return 1; }
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认随机: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    # SS2022 密码必须是 base64 编码的 16 字节
    local password=$(openssl rand -base64 16)
    echo -e "${GREEN}自动生成 SS2022 密码（base64）：${password}${RESET}"

    install_deps

    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="aarch64-unknown-linux-gnu" || arch_str="x86_64-unknown-linux-gnu"
    local url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${ver}/shadowsocks-${ver}.${arch_str}.tar.xz"

    echo -e "${GREEN}正在下载 shadowsocks-rust ${ver}...${RESET}"
    wget -q --show-progress "$url" -O /tmp/ss.tar.xz || { echo -e "${RED}下载失败${RESET}"; return 1; }
    tar -xf /tmp/ss.tar.xz -C /tmp/ ssserver 2>/dev/null || \
    tar -xf /tmp/ss.tar.xz -C /tmp/ 2>/dev/null
    mv /tmp/ssserver "$SS_BIN" 2>/dev/null || { echo -e "${RED}安装失败，未找到 ssserver 二进制${RESET}"; rm -f /tmp/ss.tar.xz; return 1; }
    rm -f /tmp/ss.tar.xz
    chmod +x "$SS_BIN"

    mkdir -p /etc/ss2022
    cat > "$SS_CONF" << EOF
{
    "server": "::",
    "server_port": ${port},
    "password": "${password}",
    "method": "2022-blake3-aes-128-gcm",
    "mode": "tcp_and_udp"
}
EOF

    cat > "$SS_SERVICE" << EOF
[Unit]
Description=Shadowsocks-rust SS2022 Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ssserver -c /etc/ss2022/config.json
LimitNOFILE=32768
Restart=on-failure
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ss2022

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ss2022 >/dev/null 2>&1
    systemctl start ss2022
    sleep 2

    if ss_running; then
        echo -e "${GREEN}SS2022 安装并启动成功！${RESET}"
        ss_update_surge
        echo ""
        echo -e "${CYAN}Surge 节点配置：${RESET}"
        cat "$SS_SURGE"
    else
        echo -e "${RED}SS2022 启动失败，请查看日志：journalctl -u ss2022.service -n 20${RESET}"
    fi
}

ss_uninstall() {
    if ! ss_installed; then echo -e "${RED}SS2022 未安装${RESET}"; return; fi
    read -p "确认卸载 SS2022？[y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "已取消" && return
    systemctl stop ss2022 2>/dev/null
    systemctl disable ss2022 2>/dev/null
    rm -f "$SS_SERVICE"
    systemctl daemon-reload
    rm -f "$SS_BIN"
    rm -rf /etc/ss2022
    echo -e "${GREEN}SS2022 已卸载${RESET}"
}

ss_update() {
    if ! ss_installed; then echo -e "${RED}SS2022 未安装${RESET}"; return; fi
    local local_ver=$(ss_local_version)
    echo -e "${CYAN}正在检查版本...${RESET}"
    local latest_ver=$(ss_latest_version)
    echo -e "当前版本：${YELLOW}${local_ver}${RESET}"
    echo -e "最新版本：${GREEN}${latest_ver}${RESET}"
    [ "$latest_ver" = "获取失败" ] && echo -e "${RED}无法获取最新版本${RESET}" && return
    [ "$local_ver" = "$latest_ver" ] && echo -e "${GREEN}已是最新版本${RESET}" && return

    echo -e "${GREEN}开始更新...${RESET}"
    systemctl stop ss2022
    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="aarch64-unknown-linux-gnu" || arch_str="x86_64-unknown-linux-gnu"
    local url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${latest_ver}/shadowsocks-${latest_ver}.${arch_str}.tar.xz"
    wget -q --show-progress "$url" -O /tmp/ss.tar.xz || { echo -e "${RED}下载失败${RESET}"; systemctl start ss2022; return 1; }
    tar -xf /tmp/ss.tar.xz -C /tmp/ ssserver 2>/dev/null || tar -xf /tmp/ss.tar.xz -C /tmp/ 2>/dev/null
    mv /tmp/ssserver "$SS_BIN" 2>/dev/null
    rm -f /tmp/ss.tar.xz
    chmod +x "$SS_BIN"
    systemctl start ss2022
    sleep 2
    ss_running && echo -e "${GREEN}更新成功：$(ss_local_version)${RESET}" || echo -e "${RED}更新后启动失败${RESET}"
}

ss_menu() {
    while true; do
        clear
        local ver=$(ss_local_version)
        local port=$(ss_conf_get "server_port")
        local run_status
        ss_running && run_status="${GREEN}运行中${RESET}" || run_status="${RED}未运行${RESET}"
        hr
        echo -e "  SS2022 ${ver} | ${run_status} | 端口: ${port}"
        hr
        if ss_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新 SS2022"
        echo "  4. 修改端口"
        echo "  5. 修改密码"
        echo "  6. 查看配置"
        echo "  7. 查看 Surge 节点"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if ss_running; then systemctl stop ss2022 && echo -e "${GREEN}服务已停止${RESET}"
                else systemctl start ss2022 && echo -e "${GREEN}服务已启动${RESET}"; fi
                ;;
            2) systemctl restart ss2022; sleep 1; ss_running && echo -e "${GREEN}已重启${RESET}" || echo -e "${RED}重启失败${RESET}" ;;
            3) ss_update ;;
            4)
                local cur_port=$(ss_conf_get "server_port")
                echo -e "当前端口：${CYAN}${cur_port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['server_port']=${new_port}
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
"
                    systemctl restart ss2022
                    ss_update_surge
                    echo -e "${GREEN}端口已修改为 ${new_port}${RESET}"
                else
                    echo -e "${RED}端口不合法${RESET}"
                fi
                ;;
            5)
                local cur_pass=$(ss_conf_get "password")
                echo -e "当前密码：${CYAN}${cur_pass}${RESET}"
                local def_pass=$(openssl rand -base64 16)
                read -p "请输入新密码（SS2022 需 base64 格式）[默认随机: ${def_pass}]: " new_pass
                new_pass=${new_pass:-$def_pass}
                python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['password']='${new_pass}'
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
"
                systemctl restart ss2022
                ss_update_surge
                echo -e "${GREEN}密码已修改${RESET}"
                ;;
            6)
                echo -e "${CYAN}=== 服务配置 ===${RESET}"
                cat "$SS_CONF"
                ;;
            7)
                echo -e "${CYAN}=== Surge 节点配置 ===${RESET}"
                if [ -f "$SS_SURGE" ]; then cat "$SS_SURGE"
                else ss_update_surge && cat "$SS_SURGE"; fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# AnyTLS 相关函数
# =============================================

anytls_installed() { [ -f "$ANYTLS_BIN" ]; }
anytls_running() { systemctl is-active --quiet anytls.service 2>/dev/null; }

anytls_local_version() {
    anytls_installed && $ANYTLS_BIN --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "未安装"
}

anytls_latest_version() {
    get_latest_github_version "anytls/anytls-go"
}

anytls_conf_get() {
    local key="$1"
    python3 -c "import json,sys; d=json.load(open('$ANYTLS_CONF')); print(d.get('$key',''))" 2>/dev/null
}

anytls_update_surge() {
    local port=$(anytls_conf_get "listen_port")
    local password=$(anytls_conf_get "password")
    local ip=$(get_server_ip)
    local country=$(get_ip_country "$ip")
    local line="${country} = anytls, ${ip}, ${port}, password = ${password}, skip-cert-verify = true"
    mkdir -p /etc/anytls
    echo "$line" > "$ANYTLS_SURGE"
}

anytls_gen_cert() {
    local port="$1"
    local crt="/etc/anytls/server.crt"
    local key="/etc/anytls/server.key"
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
        -keyout "$key" -out "$crt" -days 36500 -nodes \
        -subj "/CN=anytls-server" >/dev/null 2>&1
    echo "$crt:$key"
}

anytls_install() {
    if anytls_installed; then
        echo -e "${YELLOW}AnyTLS 已安装，如需重装请先卸载${RESET}"
        return
    fi

    echo -e "${CYAN}正在获取最新版本...${RESET}"
    local ver=$(anytls_latest_version)
    [ "$ver" = "获取失败" ] && { echo -e "${RED}无法获取版本信息，请检查网络${RESET}"; return 1; }
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认随机: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    local default_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入密码 [默认随机: ${default_pass}]: " input_pass
    local password=${input_pass:-$default_pass}

    install_deps

    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="linux-arm64" || arch_str="linux-amd64"
    local url="https://github.com/anytls/anytls-go/releases/download/${ver}/anytls-server-${arch_str}"

    echo -e "${GREEN}正在下载 AnyTLS ${ver}...${RESET}"
    wget -q --show-progress "$url" -O "$ANYTLS_BIN" || { echo -e "${RED}下载失败${RESET}"; return 1; }
    chmod +x "$ANYTLS_BIN"

    mkdir -p /etc/anytls

    # 生成自签名证书
    echo -e "${GREEN}生成自签名证书...${RESET}"
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
        -keyout /etc/anytls/server.key -out /etc/anytls/server.crt \
        -days 36500 -nodes -subj "/CN=anytls-server" >/dev/null 2>&1

    cat > "$ANYTLS_CONF" << EOF
{
    "listen_port": ${port},
    "password": "${password}",
    "certificate": "/etc/anytls/server.crt",
    "private_key": "/etc/anytls/server.key"
}
EOF

    cat > "$ANYTLS_SERVICE" << EOF
[Unit]
Description=AnyTLS Server Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/anytls-server -c /etc/anytls/config.json
LimitNOFILE=32768
Restart=on-failure
StandardOutput=journal
StandardError=journal
SyslogIdentifier=anytls

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable anytls >/dev/null 2>&1
    systemctl start anytls
    sleep 2

    if anytls_running; then
        echo -e "${GREEN}AnyTLS 安装并启动成功！${RESET}"
        anytls_update_surge
        echo ""
        echo -e "${CYAN}Surge 节点配置：${RESET}"
        cat "$ANYTLS_SURGE"
    else
        echo -e "${RED}AnyTLS 启动失败，请查看日志：journalctl -u anytls.service -n 20${RESET}"
    fi
}

anytls_uninstall() {
    if ! anytls_installed; then echo -e "${RED}AnyTLS 未安装${RESET}"; return; fi
    read -p "确认卸载 AnyTLS？[y/N]: " confirm
    [[ "${confirm,,}" != "y" ]] && echo "已取消" && return
    systemctl stop anytls 2>/dev/null
    systemctl disable anytls 2>/dev/null
    rm -f "$ANYTLS_SERVICE"
    systemctl daemon-reload
    rm -f "$ANYTLS_BIN"
    rm -rf /etc/anytls
    echo -e "${GREEN}AnyTLS 已卸载${RESET}"
}

anytls_update() {
    if ! anytls_installed; then echo -e "${RED}AnyTLS 未安装${RESET}"; return; fi
    local local_ver=$(anytls_local_version)
    echo -e "${CYAN}正在检查版本...${RESET}"
    local latest_ver=$(anytls_latest_version)
    echo -e "当前版本：${YELLOW}${local_ver}${RESET}"
    echo -e "最新版本：${GREEN}${latest_ver}${RESET}"
    [ "$latest_ver" = "获取失败" ] && echo -e "${RED}无法获取最新版本${RESET}" && return
    [ "$local_ver" = "$latest_ver" ] && echo -e "${GREEN}已是最新版本${RESET}" && return

    echo -e "${GREEN}开始更新...${RESET}"
    systemctl stop anytls
    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="linux-arm64" || arch_str="linux-amd64"
    local url="https://github.com/anytls/anytls-go/releases/download/${latest_ver}/anytls-server-${arch_str}"
    wget -q --show-progress "$url" -O "$ANYTLS_BIN" || { echo -e "${RED}下载失败${RESET}"; systemctl start anytls; return 1; }
    chmod +x "$ANYTLS_BIN"
    systemctl start anytls
    sleep 2
    anytls_running && echo -e "${GREEN}更新成功：$(anytls_local_version)${RESET}" || echo -e "${RED}更新后启动失败${RESET}"
}

anytls_menu() {
    while true; do
        clear
        local ver=$(anytls_local_version)
        local port=$(anytls_conf_get "listen_port")
        local run_status
        anytls_running && run_status="${GREEN}运行中${RESET}" || run_status="${RED}未运行${RESET}"
        hr
        echo -e "  AnyTLS ${ver} | ${run_status} | 端口: ${port}"
        hr
        if anytls_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新 AnyTLS"
        echo "  4. 修改端口"
        echo "  5. 修改密码"
        echo "  6. 查看配置"
        echo "  7. 查看 Surge 节点"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if anytls_running; then systemctl stop anytls && echo -e "${GREEN}服务已停止${RESET}"
                else systemctl start anytls && echo -e "${GREEN}服务已启动${RESET}"; fi
                ;;
            2) systemctl restart anytls; sleep 1; anytls_running && echo -e "${GREEN}已重启${RESET}" || echo -e "${RED}重启失败${RESET}" ;;
            3) anytls_update ;;
            4)
                local cur_port=$(anytls_conf_get "listen_port")
                echo -e "当前端口：${CYAN}${cur_port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    python3 -c "
import json
with open('$ANYTLS_CONF') as f: d=json.load(f)
d['listen_port']=${new_port}
with open('$ANYTLS_CONF','w') as f: json.dump(d,f,indent=4)
"
                    systemctl restart anytls
                    anytls_update_surge
                    echo -e "${GREEN}端口已修改为 ${new_port}${RESET}"
                else
                    echo -e "${RED}端口不合法${RESET}"
                fi
                ;;
            5)
                local cur_pass=$(anytls_conf_get "password")
                echo -e "当前密码：${CYAN}${cur_pass}${RESET}"
                local def_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
                read -p "请输入新密码 [默认随机: ${def_pass}]: " new_pass
                new_pass=${new_pass:-$def_pass}
                python3 -c "
import json
with open('$ANYTLS_CONF') as f: d=json.load(f)
d['password']='${new_pass}'
with open('$ANYTLS_CONF','w') as f: json.dump(d,f,indent=4)
"
                systemctl restart anytls
                anytls_update_surge
                echo -e "${GREEN}密码已修改${RESET}"
                ;;
            6)
                echo -e "${CYAN}=== 服务配置 ===${RESET}"
                cat "$ANYTLS_CONF"
                ;;
            7)
                echo -e "${CYAN}=== Surge 节点配置 ===${RESET}"
                if [ -f "$ANYTLS_SURGE" ]; then cat "$ANYTLS_SURGE"
                else anytls_update_surge && cat "$ANYTLS_SURGE"; fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# 协议管理菜单（安装/卸载）
# =============================================

protocol_manage_menu() {
    while true; do
        clear
        hr
        echo "  协议管理"
        hr
        # 安装
        echo "  [ 安装协议 ]"
        snell_installed   || echo "  i1. 安装 Snell"
        ss_installed      || echo "  i2. 安装 SS2022"
        anytls_installed  || echo "  i3. 安装 AnyTLS"
        echo ""
        # 卸载
        echo "  [ 卸载协议 ]"
        snell_installed   && echo "  u1. 卸载 Snell"
        ss_installed      && echo "  u2. 卸载 SS2022"
        anytls_installed  && echo "  u3. 卸载 AnyTLS"
        echo ""
        echo "  0. 返回"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            i1) snell_install ;;
            i2) ss_install ;;
            i3) anytls_install ;;
            u1) snell_uninstall ;;
            u2) ss_uninstall ;;
            u3) anytls_uninstall ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# 导出节点配置
# =============================================

export_surge_configs() {
    while true; do
        clear
        hr
        echo "  导出节点配置"
        hr
        snell_installed   && echo "  1. 导出 Snell"
        ss_installed      && echo "  2. 导出 SS2022"
        anytls_installed  && echo "  3. 导出 AnyTLS"
        echo "  4. 全部导出"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if snell_installed; then
                    snell_update_surge
                    echo -e "${CYAN}=== Snell ===${RESET}"
                    cat "$SNELL_SURGE"
                else echo -e "${RED}Snell 未安装${RESET}"; fi
                ;;
            2)
                if ss_installed; then
                    ss_update_surge
                    echo -e "${CYAN}=== SS2022 ===${RESET}"
                    cat "$SS_SURGE"
                else echo -e "${RED}SS2022 未安装${RESET}"; fi
                ;;
            3)
                if anytls_installed; then
                    anytls_update_surge
                    echo -e "${CYAN}=== AnyTLS ===${RESET}"
                    cat "$ANYTLS_SURGE"
                else echo -e "${RED}AnyTLS 未安装${RESET}"; fi
                ;;
            4)
                echo -e "${CYAN}=== 全部节点配置 ===${RESET}"
                if snell_installed; then snell_update_surge; cat "$SNELL_SURGE"; fi
                if ss_installed; then ss_update_surge; cat "$SS_SURGE"; fi
                if anytls_installed; then anytls_update_surge; cat "$ANYTLS_SURGE"; fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# 主菜单
# =============================================

show_main_menu() {
    clear

    # 版本与状态
    local snell_ver ss_ver anytls_ver
    local snell_stat ss_stat anytls_stat

    if snell_installed; then
        snell_ver=$(snell_local_version)
        snell_running && snell_stat="${GREEN}运行中${RESET}" || snell_stat="${RED}未运行${RESET}"
    else
        snell_ver="未安装"; snell_stat="${RED}未安装${RESET}"
    fi

    if ss_installed; then
        ss_ver=$(ss_local_version)
        ss_running && ss_stat="${GREEN}运行中${RESET}" || ss_stat="${RED}未运行${RESET}"
    else
        ss_ver="未安装"; ss_stat="${RED}未安装${RESET}"
    fi

    if anytls_installed; then
        anytls_ver=$(anytls_local_version)
        anytls_running && anytls_stat="${GREEN}运行中${RESET}" || anytls_stat="${RED}未运行${RESET}"
    else
        anytls_ver="未安装"; anytls_stat="${RED}未安装${RESET}"
    fi

    hr
    echo -e "  Snell    ${snell_ver} | ${snell_stat}"
    echo -e "  SS2022   ${ss_ver} | ${ss_stat}"
    echo -e "  AnyTLS   ${anytls_ver} | ${anytls_stat}"
    hr
    snell_installed   && echo "  1. Snell 管理"
    ss_installed      && echo "  2. SS2022 管理"
    anytls_installed  && echo "  3. AnyTLS 管理"
    echo "  4. 协议管理"
    echo "  5. 导出节点配置"
    echo "  0. 退出"
    hr
    read -p "请选择操作: " choice
    echo ""
}

# =============================================
# 主逻辑
# =============================================

trap 'echo -e "\n${RED}已中断${RESET}"; exit 1' INT

main() {
    check_root
    while true; do
        show_main_menu
        case "$choice" in
            1) snell_installed && snell_menu || echo -e "${RED}Snell 未安装${RESET}" ;;
            2) ss_installed && ss_menu || echo -e "${RED}SS2022 未安装${RESET}" ;;
            3) anytls_installed && anytls_menu || echo -e "${RED}AnyTLS 未安装${RESET}" ;;
            4) protocol_manage_menu ;;
            5) export_surge_configs ;;
            0) echo -e "${GREEN}再见${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
        esac
    done
}

main
