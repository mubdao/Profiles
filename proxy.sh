#!/bin/bash

# =============================================
# 代理协议统一管理脚本
# 支持 Snell v6 / SS2022 / AnyTLS
# 用法: bash proxy.sh
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

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
# 通用工具
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
            apt-get install -y wget unzip curl openssl python3 >/dev/null 2>&1
            ;;
        centos)
            yum install -y wget unzip curl openssl python3 >/dev/null 2>&1
            ;;
        archlinux)
            pacman -Sy --noconfirm wget unzip curl openssl python3 >/dev/null 2>&1
            ;;
        *)
            echo -e "${RED}不支持的系统类型${RESET}"
            exit 1
            ;;
    esac
}

get_arch() {
    local arch=$(uname -m)
    [ "$arch" = "aarch64" ] && echo "aarch64" || echo "amd64"
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
# Snell
# =============================================

snell_installed() { [ -f "$SNELL_BIN" ]; }
snell_running()   { systemctl is-active --quiet snell.service 2>/dev/null; }

snell_local_version() {
    snell_installed && $SNELL_BIN -version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "未安装"
}

snell_latest_version() {
    local major="${1:-6}"
    local ver
    ver=$(curl -s --connect-timeout 5 "https://kb.nssurge.com/surge-knowledge-base/release-notes/snell" \
        | grep -oE "snell-server-v${major}\.[0-9]+\.[0-9]+" \
        | grep -oE "v${major}\.[0-9]+\.[0-9]+" \
        | head -1)
    [ -z "$ver" ] && ver=$(get_latest_github_version "passeway/Snell")
    [ -z "$ver" ] && echo "获取失败" || echo "$ver"
}

snell_download_url() {
    local ver="$1"
    local arch=$(get_arch)
    echo "https://dl.nssurge.com/snell/snell-server-${ver}-linux-${arch}.zip"
}

snell_conf_get() {
    grep -E "^${1}\s*=" "$SNELL_CONF" 2>/dev/null | sed 's/.*= *//' | tr -d ' '
}

snell_conf_set() {
    if grep -qE "^${1}\s*=" "$SNELL_CONF" 2>/dev/null; then
        sed -i "s|^${1}\s*=.*|${1} = ${2}|" "$SNELL_CONF"
    else
        echo "${1} = ${2}" >> "$SNELL_CONF"
    fi
}

snell_conf_del() {
    sed -i "/^${1}\s*=/d" "$SNELL_CONF"
}

snell_get_port() {
    snell_conf_get "listen" | grep -oE '[0-9]+$'
}

snell_update_surge() {
    local port=$(snell_get_port)
    local psk=$(snell_conf_get "psk")
    local tfo=$(snell_conf_get "tfo")
    local ip=$(get_server_ip)
    local country=$(get_ip_country "$ip")
    local ver=$(snell_conf_get "version")
    [ -z "$ver" ] && ver="5"
    local line="${country} = snell, ${ip}, ${port}, psk = ${psk}, version = ${ver}, reuse = true"
    [ "$tfo" = "true" ] && line="${line}, tfo = true"
    mkdir -p /etc/snell
    echo "$line" > "$SNELL_SURGE"
}

snell_write_service() {
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
}

snell_install() {
    if snell_installed; then
        echo -e "${YELLOW}Snell 已安装，请使用「更新」功能升级${RESET}"
        return
    fi

    hr
    echo "  请选择 Snell 版本："
    echo "  1. v6"
    echo "  2. v5"
    hr
    read -p "请选择: " ver_choice
    local snell_major
    case "$ver_choice" in
        2) snell_major="5" ;;
        *) snell_major="6" ;;
    esac

    echo -e "${CYAN}正在获取 v${snell_major} 最新版本...${RESET}"
    local ver=$(snell_latest_version "$snell_major")
    if [ "$ver" = "获取失败" ]; then
        echo -e "${YELLOW}获取失败，使用默认版本 v${snell_major}.0.0${RESET}"
        ver="v${snell_major}.0.0"
    fi
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    local default_psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入 PSK  [默认随机]: " input_psk
    local psk=${input_psk:-$default_psk}

    install_deps

    local url=$(snell_download_url "$ver")
    echo -e "${GREEN}正在下载 Snell ${ver}...${RESET}"
    wget -q --show-progress "$url" -O /tmp/snell.zip || { echo -e "${RED}下载失败${RESET}"; return 1; }
    unzip -o /tmp/snell.zip -d /usr/local/bin >/dev/null || { echo -e "${RED}解压失败${RESET}"; rm -f /tmp/snell.zip; return 1; }
    rm -f /tmp/snell.zip
    chmod +x "$SNELL_BIN"

    id "snell" &>/dev/null || useradd -r -s /usr/sbin/nologin snell
    mkdir -p /etc/snell

    cat > "$SNELL_CONF" << EOF
[snell-server]
listen = 0.0.0.0:${port},[::]:${port}
psk = ${psk}
ipv6 = true
dns-ip-preference = prefer-ipv6
version = ${snell_major}
EOF

    snell_write_service
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
        echo -e "${RED}启动失败，请查看日志：journalctl -u snell.service -n 20${RESET}"
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
    local url=$(snell_download_url "$latest_ver")
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
        local port=$(snell_get_port)
        local tfo=$(snell_conf_get "tfo")
        local run_status tfo_status
        snell_running && run_status="${GREEN}运行中${RESET}" || run_status="${RED}未运行${RESET}"
        [ "$tfo" = "true" ] && tfo_status="${GREEN}已开启${RESET}" || tfo_status="${YELLOW}已关闭${RESET}"
        hr
        echo -e "  Snell ${ver} | 状态: ${run_status} | 端口: ${port} | TFO: ${tfo_status}"
        hr
        if snell_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新版本"
        echo "  4. 修改端口"
        echo "  5. 修改  PSK"
        echo "  6. TFO 开关"
        echo "  7. 查看配置"
        echo "  8. 查看节点"
        echo "  0. 返回主页"
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
            2)
                systemctl restart snell; sleep 1
                snell_running && echo -e "${GREEN}重启成功${RESET}" || echo -e "${RED}重启失败${RESET}"
                ;;
            3) snell_update ;;
            4)
                echo -e "当前端口：${CYAN}${port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    snell_conf_set "listen" "0.0.0.0:${new_port},[::]:${new_port}"
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
                read -p "请输入新 PSK [默认随机]: " new_psk
                new_psk=${new_psk:-$def_psk}
                snell_conf_set "psk" "$new_psk"
                systemctl restart snell
                snell_update_surge
                echo -e "${GREEN}PSK 已修改${RESET}"
                ;;
            6)
                if [ "$(snell_conf_get tfo)" = "true" ]; then
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
                hr
                cat "$SNELL_CONF"
                ;;
            8)
                hr
                [ -f "$SNELL_SURGE" ] || snell_update_surge
                cat "$SNELL_SURGE"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# SS2022
# =============================================

ss_installed() { [ -f "$SS_BIN" ]; }
ss_running()   { systemctl is-active --quiet ss2022.service 2>/dev/null; }

ss_local_version() {
    ss_installed && $SS_BIN --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "未安装"
}

ss_latest_version() {
    get_latest_github_version "shadowsocks/shadowsocks-rust"
}

ss_conf_get() {
    python3 -c "import json; d=json.load(open('$SS_CONF')); print(d.get('$1',''))" 2>/dev/null
}

ss_conf_set() {
    local key="$1" val="$2"
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['${key}'] = ${val}
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

ss_conf_set_str() {
    local key="$1" val="$2"
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['${key}'] = '${val}'
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
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
        echo -e "${YELLOW}SS2022 已安装，请使用「更新」功能升级${RESET}"
        return
    fi

    echo -e "${CYAN}正在获取最新版本...${RESET}"
    local ver=$(ss_latest_version)
    [ "$ver" = "获取失败" ] && { echo -e "${RED}无法获取版本信息${RESET}"; return 1; }
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    local password=$(openssl rand -base64 16)
    echo -e "${GREEN}自动生成密码（SS2022 需 base64 格式）：${password}${RESET}"

    install_deps

    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="aarch64-unknown-linux-gnu" || arch_str="x86_64-unknown-linux-gnu"
    local url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${ver}/shadowsocks-${ver}.${arch_str}.tar.xz"

    echo -e "${GREEN}正在下载 shadowsocks-rust ${ver}...${RESET}"
    wget -q --show-progress "$url" -O /tmp/ss.tar.xz || { echo -e "${RED}下载失败${RESET}"; return 1; }
    tar -xf /tmp/ss.tar.xz -C /tmp/ ssserver 2>/dev/null || tar -xf /tmp/ss.tar.xz -C /tmp/ 2>/dev/null
    mv /tmp/ssserver "$SS_BIN" 2>/dev/null || { echo -e "${RED}安装失败，未找到 ssserver${RESET}"; rm -f /tmp/ss.tar.xz; return 1; }
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
        echo -e "${RED}启动失败，请查看日志：journalctl -u ss2022.service -n 20${RESET}"
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
        echo -e "  SS2022 ${ver} | 状态: ${run_status} | 端口: ${port}"
        hr
        if ss_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新版本"
        echo "  4. 修改端口"
        echo "  5. 修改密码"
        echo "  6. 查看配置"
        echo "  7. 查看节点"
        echo "  0. 返回主页"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if ss_running; then systemctl stop ss2022 && echo -e "${GREEN}服务已停止${RESET}"
                else systemctl start ss2022 && echo -e "${GREEN}服务已启动${RESET}"; fi
                ;;
            2)
                systemctl restart ss2022; sleep 1
                ss_running && echo -e "${GREEN}重启成功${RESET}" || echo -e "${RED}重启失败${RESET}"
                ;;
            3) ss_update ;;
            4)
                echo -e "当前端口：${CYAN}${port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    ss_conf_set "server_port" "$new_port"
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
                read -p "请输入新密码（base64）[默认随机]: " new_pass
                new_pass=${new_pass:-$def_pass}
                ss_conf_set_str "password" "$new_pass"
                systemctl restart ss2022
                ss_update_surge
                echo -e "${GREEN}密码已修改${RESET}"
                ;;
            6)
                hr
                cat "$SS_CONF"
                ;;
            7)
                hr
                [ -f "$SS_SURGE" ] || ss_update_surge
                cat "$SS_SURGE"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# AnyTLS
# =============================================

anytls_installed() { [ -f "$ANYTLS_BIN" ]; }
anytls_running()   { systemctl is-active --quiet anytls.service 2>/dev/null; }

anytls_local_version() {
    anytls_installed && $ANYTLS_BIN --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "未安装"
}

anytls_latest_version() {
    get_latest_github_version "anytls/anytls-go"
}

anytls_conf_get() {
    python3 -c "import json; d=json.load(open('$ANYTLS_CONF')); print(d.get('$1',''))" 2>/dev/null
}

anytls_conf_set_str() {
    local key="$1" val="$2"
    python3 -c "
import json
with open('$ANYTLS_CONF') as f: d=json.load(f)
d['${key}'] = '${val}'
with open('$ANYTLS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

anytls_conf_set_int() {
    local key="$1" val="$2"
    python3 -c "
import json
with open('$ANYTLS_CONF') as f: d=json.load(f)
d['${key}'] = ${val}
with open('$ANYTLS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
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

anytls_install() {
    if anytls_installed; then
        echo -e "${YELLOW}AnyTLS 已安装，请使用「更新」功能升级${RESET}"
        return
    fi

    echo -e "${CYAN}正在获取最新版本...${RESET}"
    local ver=$(anytls_latest_version)
    [ "$ver" = "获取失败" ] && { echo -e "${RED}无法获取版本信息${RESET}"; return 1; }
    echo -e "${GREEN}将安装版本：${ver}${RESET}"

    local default_port=$(shuf -i 30000-65000 -n 1)
    read -p "请输入端口 [默认: ${default_port}]: " input_port
    local port=${input_port:-$default_port}
    if ! validate_port "$port"; then
        echo -e "${RED}端口不合法，使用随机端口 ${default_port}${RESET}"
        port=$default_port
    fi

    local default_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24)
    read -p "请输入密码  [默认随机]: " input_pass
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
        echo -e "${RED}启动失败，请查看日志：journalctl -u anytls.service -n 20${RESET}"
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
        echo -e "  AnyTLS ${ver} | 状态: ${run_status} | 端口: ${port}"
        hr
        if anytls_running; then
            echo "  1. 停止服务"
        else
            echo "  1. 启动服务"
        fi
        echo "  2. 重启服务"
        echo "  3. 更新版本"
        echo "  4. 修改端口"
        echo "  5. 修改密码"
        echo "  6. 查看配置"
        echo "  7. 查看节点"
        echo "  0. 返回主页"
        hr
        read -p "请选择操作: " choice
        echo ""
        case "$choice" in
            1)
                if anytls_running; then systemctl stop anytls && echo -e "${GREEN}服务已停止${RESET}"
                else systemctl start anytls && echo -e "${GREEN}服务已启动${RESET}"; fi
                ;;
            2)
                systemctl restart anytls; sleep 1
                anytls_running && echo -e "${GREEN}重启成功${RESET}" || echo -e "${RED}重启失败${RESET}"
                ;;
            3) anytls_update ;;
            4)
                echo -e "当前端口：${CYAN}${port}${RESET}"
                read -p "请输入新端口: " new_port
                if validate_port "$new_port"; then
                    anytls_conf_set_int "listen_port" "$new_port"
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
                read -p "请输入新密码 [默认随机]: " new_pass
                new_pass=${new_pass:-$def_pass}
                anytls_conf_set_str "password" "$new_pass"
                systemctl restart anytls
                anytls_update_surge
                echo -e "${GREEN}密码已修改${RESET}"
                ;;
            6)
                hr
                cat "$ANYTLS_CONF"
                ;;
            7)
                hr
                [ -f "$ANYTLS_SURGE" ] || anytls_update_surge
                cat "$ANYTLS_SURGE"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        press_enter
    done
}

# =============================================
# 协议管理（安装 / 卸载）
# =============================================

protocol_manage_menu() {
    while true; do
        clear
        hr
        echo "  协议管理（安装 / 卸载）"
        hr

        local options=()
        local labels=()

        # 动态构建选项列表
        snell_installed   || { options+=("install_snell");   labels+=("安装 Snell  "); }
        ss_installed      || { options+=("install_ss");      labels+=("安装 SS2022 "); }
        anytls_installed  || { options+=("install_anytls");  labels+=("安装 AnyTLS "); }
        snell_installed   && { options+=("uninstall_snell");  labels+=("卸载 Snell  "); }
        ss_installed      && { options+=("uninstall_ss");     labels+=("卸载 SS2022 "); }
        anytls_installed  && { options+=("uninstall_anytls"); labels+=("卸载 AnyTLS "); }

        local i
        for i in "${!options[@]}"; do
            echo "  $((i+1)). ${labels[$i]}"
        done
        echo "  0. 返回主页"
        hr
        read -p "请选择操作: " choice
        echo ""

        if [ "$choice" = "0" ]; then return; fi

        local idx=$((choice-1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
            case "${options[$idx]}" in
                install_snell)    snell_install ;;
                install_ss)       ss_install ;;
                install_anytls)   anytls_install ;;
                uninstall_snell)  snell_uninstall ;;
                uninstall_ss)     ss_uninstall ;;
                uninstall_anytls) anytls_uninstall ;;
            esac
        else
            echo -e "${RED}无效选项${RESET}"
        fi
        press_enter
    done
}

# =============================================
# 导出节点配置
# =============================================

export_menu() {
    while true; do
        clear
        hr
        echo "  导出节点配置"
        hr

        local options=()
        local labels=()
        snell_installed   && { options+=("snell");  labels+=("导出 Snell  "); }
        ss_installed      && { options+=("ss");     labels+=("导出 SS2022 "); }
        anytls_installed  && { options+=("anytls"); labels+=("导出 AnyTLS "); }
        if [ "${#options[@]}" -gt 1 ]; then
            options+=("all"); labels+=("全部导出   ")
        fi

        if [ "${#options[@]}" -eq 0 ]; then
            echo "  暂无已安装的协议"
            echo "  0. 返回主页"
            hr
            read -p "请选择操作: " choice
            [ "$choice" = "0" ] && return
            continue
        fi

        local i
        for i in "${!options[@]}"; do
            echo "  $((i+1)). ${labels[$i]}"
        done
        echo "  0. 返回主页"
        hr
        read -p "请选择操作: " choice
        echo ""

        if [ "$choice" = "0" ]; then return; fi

        local idx=$((choice-1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
            hr
            case "${options[$idx]}" in
                snell)
                    snell_update_surge
                    echo -e "${CYAN}Snell：${RESET}"
                    cat "$SNELL_SURGE"
                    ;;
                ss)
                    ss_update_surge
                    echo -e "${CYAN}SS2022：${RESET}"
                    cat "$SS_SURGE"
                    ;;
                anytls)
                    anytls_update_surge
                    echo -e "${CYAN}AnyTLS：${RESET}"
                    cat "$ANYTLS_SURGE"
                    ;;
                all)
                    snell_installed  && { snell_update_surge;  echo -e "${CYAN}Snell：${RESET}";  cat "$SNELL_SURGE";  echo; }
                    ss_installed     && { ss_update_surge;     echo -e "${CYAN}SS2022：${RESET}"; cat "$SS_SURGE";     echo; }
                    anytls_installed && { anytls_update_surge; echo -e "${CYAN}AnyTLS：${RESET}"; cat "$ANYTLS_SURGE"; echo; }
                    ;;
            esac
        else
            echo -e "${RED}无效选项${RESET}"
        fi
        press_enter
    done
}

# =============================================
# 主菜单
# =============================================

show_main_menu() {
    clear

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
    echo -e "  Snell    ${snell_ver}  |  ${snell_stat}"
    echo -e "  SS2022   ${ss_ver}  |  ${ss_stat}"
    echo -e "  AnyTLS   ${anytls_ver}  |  ${anytls_stat}"
    hr

    local options=()
    local labels=()

    snell_installed   && { options+=("snell");   labels+=("Snell  管理"); }
    ss_installed      && { options+=("ss");      labels+=("SS2022 管理"); }
    anytls_installed  && { options+=("anytls");  labels+=("AnyTLS 管理"); }
    options+=("manage"); labels+=("协议安装卸载")
    options+=("export"); labels+=("导出节点配置")
    options+=("exit");   labels+=("退出脚本   ")

    local i
    for i in "${!options[@]}"; do
        if [ "${options[$i]}" = "exit" ]; then
            echo "  0. ${labels[$i]}"
        else
            echo "  $((i+1)). ${labels[$i]}"
        fi
    done
    hr
    read -p "请选择操作: " choice
    echo ""

    # 处理选择
    if [ "$choice" = "0" ]; then
        echo -e "${GREEN}再见${RESET}"; exit 0
    fi

    local idx=$((choice-1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#options[@]}" ]; then
        case "${options[$idx]}" in
            snell)   snell_menu ;;
            ss)      ss_menu ;;
            anytls)  anytls_menu ;;
            manage)  protocol_manage_menu ;;
            export)  export_menu ;;
            exit)    echo -e "${GREEN}再见${RESET}"; exit 0 ;;
        esac
    else
        echo -e "${RED}无效选项${RESET}"; sleep 1
    fi
}

# =============================================
# 主逻辑
# =============================================

trap 'echo -e "\n${RED}已中断${RESET}"; exit 1' INT

main() {
    check_root
    while true; do
        show_main_menu
    done
}

main
