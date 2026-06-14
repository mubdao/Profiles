#!/bin/bash

# =============================================
# 代理协议统一管理脚本
# 支持 Snell v6 / SS2022 / AnyTLS
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

SNELL_BIN="/usr/local/bin/snell-server"
SNELL_CONF="/etc/snell/snell-server.conf"
SNELL_SERVICE="/etc/systemd/system/snell.service"

SS_BIN="/usr/local/bin/ssserver"
SS_CONF="/etc/ss2022/config.json"
SS_SERVICE="/etc/systemd/system/ss2022.service"

ANYTLS_BIN="/usr/local/bin/anytls-server"
ANYTLS_DIR="/etc/anytls"
ANYTLS_CONF="/etc/anytls/anytls.conf"
ANYTLS_SCHEME="/etc/anytls/scheme.txt"
ANYTLS_VER_FILE="/etc/anytls/version"
ANYTLS_SERVICE="/etc/systemd/system/anytls.service"
ANYTLS_DEFAULT_SNI="iosapps.itunes.apple.com"

# =============================================
# 通用工具
# =============================================

check_root() {
    [ "$(id -u)" != "0" ] && echo -e "${RED}请以 root 权限运行${PLAIN}" && exit 1
}

get_sys() {
    [ -f /etc/debian_version ] && echo "debian" && return
    [ -f /etc/redhat-release ] && echo "centos" && return
    [ -f /etc/arch-release ]   && echo "arch"   && return
    echo "unknown"
}

wait_apt() {
    [ "$(get_sys)" != "debian" ] && return
    while fuser /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        echo -e "${YELLOW}等待 apt 锁释放...${PLAIN}"; sleep 2
    done
}

install_deps() {
    echo -e "${GREEN}安装依赖...${PLAIN}"
    case "$(get_sys)" in
        debian) wait_apt; apt-get update -qq; apt-get install -y wget unzip curl openssl >/dev/null 2>&1 ;;
        centos) yum install -y wget unzip curl openssl >/dev/null 2>&1 ;;
        arch)   pacman -Sy --noconfirm wget unzip curl openssl >/dev/null 2>&1 ;;
        *)      echo -e "${RED}不支持的系统${PLAIN}"; exit 1 ;;
    esac
}

get_arch() {
    [ "$(uname -m)" = "aarch64" ] && echo "aarch64" || echo "amd64"
}

get_ip() {
    curl -s --connect-timeout 5 https://checkip.amazonaws.com \
        || curl -s --connect-timeout 5 https://api.ipify.org
}

get_country() {
    curl -s --connect-timeout 5 "https://ipinfo.io/${1}/country" 2>/dev/null | tr -d '\n' || echo "UN"
}

get_latest_github() {
    local repo="$1"
    curl -s --connect-timeout 5 "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"tag_name"' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

rand_port() { shuf -i 30000-65000 -n 1; }
rand_pass()  { tr -dc A-Za-z0-9 </dev/urandom | head -c 24; }

# 防火墙自动放行端口
firewall_allow() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "$port"/tcp >/dev/null 2>&1
        echo -e "${GREEN}已放行端口 ${port}（ufw）${PLAIN}"
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        firewall-cmd --permanent --add-port="${port}"/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo -e "${GREEN}已放行端口 ${port}（firewalld）${PLAIN}"
    fi
}

press_enter() { echo ""; read -p "按 Enter 继续..."; }
hr() { echo "--------------------------------------------------------"; }

# =============================================
# 状态检测
# =============================================

snell_installed()  { [ -f "$SNELL_BIN" ]; }
ss_installed()     { [ -f "$SS_BIN" ]; }
snell_running()    { systemctl is-active --quiet snell.service  2>/dev/null; }
ss_running()       { systemctl is-active --quiet ss2022.service 2>/dev/null; }

snell_version() {
    snell_installed && "$SNELL_BIN" -version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+[a-z0-9]*' | head -1 || echo "-"
}

ss_version() {
    if ! ss_installed; then echo "-"; return; fi
    local ver
    ver=$("$SS_BIN" --version 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -z "$ver" ] && echo "-" || echo "$ver"
}

# =============================================
# Snell 配置读写
# =============================================

snell_get() { grep -E "^${1}\s*=" "$SNELL_CONF" 2>/dev/null | sed 's/.*=\s*//' | tr -d ' '; }

snell_set() {
    if grep -qE "^${1}\s*=" "$SNELL_CONF" 2>/dev/null; then
        sed -i "s|^${1}\s*=.*|${1} = ${2}|" "$SNELL_CONF"
    else
        echo "${1} = ${2}" >> "$SNELL_CONF"
    fi
}

snell_del() { sed -i "/^${1}\s*=/d" "$SNELL_CONF"; }
snell_port() { snell_get "listen" | grep -oE '[0-9]+$'; }

# =============================================
# SS2022 配置读写
# =============================================

ss_get() {
    python3 -c "import json; d=json.load(open('$SS_CONF')); print(d.get('$1',''))" 2>/dev/null
}

ss_set_int() {
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['$1']=$2
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

ss_set_str() {
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['$1']='$2'
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

ss_set_bool() {
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d['$1']=$2
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

ss_del_key() {
    python3 -c "
import json
with open('$SS_CONF') as f: d=json.load(f)
d.pop('$1', None)
with open('$SS_CONF','w') as f: json.dump(d,f,indent=4)
" 2>/dev/null
}

# =============================================
# Surge 节点生成
# =============================================

snell_surge_line() {
    local port=$(snell_port)
    local psk=$(snell_get "psk")
    local tfo=$(snell_get "tfo")
    local ip=$(get_ip)
    local country=$(get_country "$ip")
    # 从二进制版本号提取大版本数字
    local bin_ver=$(snell_version)
    local ver=$(echo "$bin_ver" | grep -oE '^v[0-9]+' | tr -d 'v')
    [ -z "$ver" ] && ver="6"
    local line="${country} = snell, ${ip}, ${port}, psk = ${psk}, version = ${ver}, reuse = true, ecn = true"
    [ "$tfo" = "true" ] && line="${line}, tfo = true"
    echo "$line"
}

ss_surge_line() {
    local port=$(ss_get "server_port")
    local pass=$(ss_get "password")
    local tfo=$(ss_get "fast_open")
    local ip=$(get_ip)
    local country=$(get_country "$ip")
    local line="${country} = ss, ${ip}, ${port}, encrypt-method = 2022-blake3-aes-128-gcm, password = ${pass}"
    [ "$tfo" = "True" ] && line="${line}, tfo = true"
    echo "$line"
}


# =============================================
# AnyTLS 状态检测
# =============================================

anytls_installed() { [ -f "$ANYTLS_BIN" ]; }
anytls_running()   { systemctl is-active --quiet anytls.service 2>/dev/null; }

anytls_version() {
    anytls_installed && cat "$ANYTLS_VER_FILE" 2>/dev/null || echo "-"
}

anytls_conf_get() {
    [ -f "$ANYTLS_CONF" ] || return
    grep -E "^${1}=" "$ANYTLS_CONF" 2>/dev/null | cut -d= -f2- | tr -d "'"
}

anytls_conf_set() {
    mkdir -p "$ANYTLS_DIR"
    if grep -qE "^${1}=" "$ANYTLS_CONF" 2>/dev/null; then
        sed -i "s|^${1}=.*|${1}=$(printf '%q' "${2}")|" "$ANYTLS_CONF"
    else
        echo "${1}=$(printf '%q' "${2}")" >> "$ANYTLS_CONF"
    fi
}

anytls_port() { anytls_conf_get "ANYTLS_LISTEN" | grep -oE '[0-9]+$'; }

# =============================================
# AnyTLS Surge节点生成
# =============================================

anytls_surge_line() {
    local port=$(anytls_port)
    local pass=$(anytls_conf_get "ANYTLS_PASSWORD")
    local sni=$(anytls_conf_get "ANYTLS_CLIENT_SNI")
    local ip=$(get_ip)
    local country=$(get_country "$ip")
    local line="${country} = anytls, ${ip}, ${port}, password = ${pass}, skip-cert-verify = true"
    [ -n "$sni" ] && line="${line}, sni = ${sni}"
    echo "$line"
}

# =============================================
# AnyTLS scheme文件
# =============================================

anytls_write_scheme() {
    mkdir -p "$ANYTLS_DIR"
    cat > "$ANYTLS_SCHEME" << 'SCHEME'
stop=8
0=30-30
1=100-400
2=400-500,c,500-1000,c,500-1000,c,500-1000,c,500-1000
3=9-9,500-1000
4=500-1000
5=500-1000
6=500-1000
7=500-1000
SCHEME
    chmod 600 "$ANYTLS_SCHEME"
}

# =============================================
# AnyTLS systemd服务
# =============================================

anytls_write_service() {
    local port=$(anytls_port)
    local pass=$(anytls_conf_get "ANYTLS_PASSWORD")
    cat > "$ANYTLS_SERVICE" << EOF
[Unit]
Description=AnyTLS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=LOG_LEVEL=warn
ExecStart=${ANYTLS_BIN} -l 0.0.0.0:${port} -p ${pass} --padding-scheme ${ANYTLS_SCHEME}
LimitNOFILE=1048576
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=anytls

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

# =============================================
# AnyTLS 安装
# =============================================

anytls_install() {
    if anytls_installed; then
        echo -e "${YELLOW}AnyTLS 已安装，请使用更新功能${PLAIN}"; press_enter; return
    fi

    echo -e "${CYAN}获取最新版本...${PLAIN}"
    local ver=$(get_latest_github "anytls/anytls-go")
    if [ -z "$ver" ]; then
        echo -e "${RED}获取失败，请检查网络${PLAIN}"; return 1
    fi
    echo -e "${GREEN}最新版本：${ver}${PLAIN}"

    local def_port=$(rand_port)
    read -p "端口 [默认随机: ${def_port}]: " inp_port
    local port=${inp_port:-$def_port}
    if ! valid_port "$port"; then
        echo -e "${RED}端口不合法，使用 ${def_port}${PLAIN}"; port=$def_port
    fi

    local def_pass=$(rand_pass)
    read -p "密码 [默认随机]: " inp_pass
    local pass=${inp_pass:-$def_pass}

    local sni="$ANYTLS_DEFAULT_SNI"
    read -p "SNI  [默认: ${sni}，留空不发送]: " inp_sni
    [ -n "$inp_sni" ] && sni="$inp_sni"
    [ "$inp_sni" = "none" ] && sni=""

    install_deps

    local arch=$(get_arch)
    local ver_num="${ver#v}"
    local url="https://github.com/anytls/anytls-go/releases/download/${ver}/anytls_${ver_num}_linux_${arch}.zip"

    echo -e "${GREEN}下载 AnyTLS ${ver}...${PLAIN}"
    local tmpdir=$(mktemp -d)
    wget -q --show-progress "$url" -O "${tmpdir}/anytls.zip"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败${PLAIN}"; rm -rf "$tmpdir"; return 1
    fi

    unzip -oq "${tmpdir}/anytls.zip" -d "${tmpdir}" 2>/dev/null
    local found_bin=$(find "${tmpdir}" -type f -name "anytls-server" | head -1)
    if [ -z "$found_bin" ]; then
        echo -e "${RED}未找到 anytls-server 二进制${PLAIN}"; rm -rf "$tmpdir"; return 1
    fi
    install -m 0755 "$found_bin" "$ANYTLS_BIN"
    rm -rf "$tmpdir"

    mkdir -p "$ANYTLS_DIR"
    chmod 700 "$ANYTLS_DIR"

    # 写配置
    cat > "$ANYTLS_CONF" << EOF
ANYTLS_LISTEN=$(printf '%q' "0.0.0.0:${port}")
ANYTLS_PASSWORD=$(printf '%q' "${pass}")
ANYTLS_CLIENT_SNI=$(printf '%q' "${sni}")
ANYTLS_VERSION=$(printf '%q' "${ver}")
EOF
    chmod 600 "$ANYTLS_CONF"

    # 写版本文件
    echo "$ver" > "$ANYTLS_VER_FILE"

    # 写scheme文件
    anytls_write_scheme

    # 写服务
    anytls_write_service

    systemctl enable anytls >/dev/null 2>&1
    systemctl start anytls
    sleep 2

    # 防火墙放行
    firewall_allow "$port"

    if anytls_running; then
        echo -e "${GREEN}AnyTLS 安装成功！${PLAIN}"
        echo ""; hr
        echo -e "${CYAN}Surge 节点：${PLAIN}"
        anytls_surge_line
        hr
    else
        echo -e "${RED}启动失败：journalctl -u anytls.service -n 20 --no-pager${PLAIN}"
    fi
}

# =============================================
# AnyTLS 卸载
# =============================================

anytls_uninstall() {
    ! anytls_installed && echo -e "${RED}AnyTLS 未安装${PLAIN}" && return
    read -p "确认卸载 AnyTLS？[y/N]: " c
    [[ "${c,,}" != "y" ]] && echo "已取消" && return
    systemctl stop anytls 2>/dev/null
    systemctl disable anytls 2>/dev/null
    rm -f "$ANYTLS_SERVICE"
    systemctl daemon-reload
    rm -f "$ANYTLS_BIN"
    rm -rf "$ANYTLS_DIR"
    echo -e "${GREEN}AnyTLS 已卸载${PLAIN}"
}

# =============================================
# AnyTLS 更新
# =============================================

anytls_update() {
    ! anytls_installed && echo -e "${RED}AnyTLS 未安装${PLAIN}" && return
    local cur=$(anytls_version)
    echo -e "${CYAN}检查版本...${PLAIN}"
    local new=$(get_latest_github "anytls/anytls-go")
    if [ -z "$new" ]; then
        echo -e "${RED}获取失败${PLAIN}"; return
    fi
    echo -e "当前：${YELLOW}${cur}${PLAIN}  最新：${GREEN}${new}${PLAIN}"
    [ "$cur" = "$new" ] && echo -e "${GREEN}已是最新版本${PLAIN}" && return

    echo -e "${GREEN}开始更新...${PLAIN}"
    systemctl stop anytls

    local arch=$(get_arch)
    local ver_num="${new#v}"
    local url="https://github.com/anytls/anytls-go/releases/download/${new}/anytls_${ver_num}_linux_${arch}.zip"
    local tmpdir=$(mktemp -d)
    wget -q --show-progress "$url" -O "${tmpdir}/anytls.zip"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，保持当前版本${PLAIN}"
        systemctl start anytls; rm -rf "$tmpdir"; return 1
    fi

    unzip -oq "${tmpdir}/anytls.zip" -d "${tmpdir}" 2>/dev/null
    local found_bin=$(find "${tmpdir}" -type f -name "anytls-server" | head -1)
    if [ -n "$found_bin" ]; then
        install -m 0755 "$found_bin" "$ANYTLS_BIN"
        echo "$new" > "$ANYTLS_VER_FILE"
        anytls_conf_set "ANYTLS_VERSION" "$new"
    fi
    rm -rf "$tmpdir"

    anytls_write_service
    systemctl start anytls
    sleep 2
    anytls_running && echo -e "${GREEN}更新成功：$(anytls_version)${PLAIN}"                    || echo -e "${RED}启动失败${PLAIN}"
}

# =============================================
# Snell 最新版本获取
# =============================================

snell_latest_version() {
    local ver
    # 从官方知识库页面抓取（支持 beta 后缀如 v6.0.0b2）
    ver=$(curl -s --connect-timeout 5 "https://kb.nssurge.com/surge-knowledge-base/release-notes/snell" \
        | grep -oE 'snell-server-v6\.[0-9]+\.[0-9]+[a-z]*[0-9]*-linux' \
        | grep -oE 'v6\.[0-9]+\.[0-9]+[a-z]*[0-9]*' \
        | head -1)
    [ -z "$ver" ] && ver=$(get_latest_github "passeway/Snell")
    [ -z "$ver" ] && ver="v6.0.0b2"
    echo "$ver"
}

# =============================================
# Snell 安装
# =============================================

snell_install() {
    if snell_installed; then
        echo -e "${YELLOW}Snell 已安装，请使用更新功能${PLAIN}"; press_enter; return
    fi

    echo -e "${CYAN}获取最新版本...${PLAIN}"
    local ver=$(snell_latest_version)
    echo -e "${GREEN}最新版本：${ver}${PLAIN}"

    local def_port=$(rand_port)
    read -p "端口 [默认随机: ${def_port}]: " inp_port
    local port=${inp_port:-$def_port}
    if ! valid_port "$port"; then
        echo -e "${RED}端口不合法，使用 ${def_port}${PLAIN}"; port=$def_port
    fi

    local def_psk=$(rand_pass)
    while true; do
        read -p "PSK  [默认随机，至少16位]: " inp_psk
        local psk=${inp_psk:-$def_psk}
        if [ ${#psk} -ge 16 ]; then break
        else echo -e "${RED}PSK 至少需要 16 位${PLAIN}"; fi
    done

    read -p "开启 TFO？[Y/n，默认Y]: " inp_tfo
    local tfo="true"
    [ "${inp_tfo,,}" = "n" ] && tfo="false"

    install_deps

    local arch=$(get_arch)
    local url="https://dl.nssurge.com/snell/snell-server-${ver}-linux-${arch}.zip"
    echo -e "${GREEN}下载 Snell ${ver}...${PLAIN}"
    wget -q --show-progress "$url" -O /tmp/snell.zip
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，请检查网络${PLAIN}"; return 1
    fi

    unzip -o /tmp/snell.zip -d /usr/local/bin >/dev/null 2>&1
    if [ $? -ne 0 ] || [ ! -f "$SNELL_BIN" ]; then
        echo -e "${RED}解压失败${PLAIN}"; rm -f /tmp/snell.zip; return 1
    fi
    rm -f /tmp/snell.zip
    chmod +x "$SNELL_BIN"

    id snell &>/dev/null || useradd -r -s /usr/sbin/nologin snell
    mkdir -p /etc/snell

    cat > "$SNELL_CONF" << EOF
[snell-server]
listen = 0.0.0.0:${port},[::]:${port}
psk = ${psk}
ipv6 = true
dns-ip-preference = prefer-ipv6
EOF
    [ "$tfo" = "true" ] && echo "tfo = true" >> "$SNELL_CONF"

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
RestartSec=3
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

    # 防火墙放行
    firewall_allow "$port"

    if snell_running; then
        echo -e "${GREEN}Snell 安装成功！${PLAIN}"
        echo ""; hr
        echo -e "${CYAN}Surge 节点：${PLAIN}"
        snell_surge_line
        hr
    else
        echo -e "${RED}启动失败：journalctl -u snell.service -n 20 --no-pager${PLAIN}"
    fi
}

# =============================================
# Snell 卸载
# =============================================

snell_uninstall() {
    ! snell_installed && echo -e "${RED}Snell 未安装${PLAIN}" && return
    read -p "确认卸载 Snell？[y/N]: " c
    [[ "${c,,}" != "y" ]] && echo "已取消" && return
    systemctl stop snell 2>/dev/null
    systemctl disable snell 2>/dev/null
    rm -f "$SNELL_SERVICE"
    systemctl daemon-reload
    rm -f "$SNELL_BIN"
    rm -rf /etc/snell
    echo -e "${GREEN}Snell 已卸载${PLAIN}"
}

# =============================================
# Snell 更新
# =============================================

snell_update() {
    ! snell_installed && echo -e "${RED}Snell 未安装${PLAIN}" && return
    local cur=$(snell_version)
    echo -e "${CYAN}检查版本...${PLAIN}"
    local new=$(snell_latest_version)
    echo -e "当前：${YELLOW}${cur}${PLAIN}  最新：${GREEN}${new}${PLAIN}"
    [ "$cur" = "$new" ] && echo -e "${GREEN}已是最新版本${PLAIN}" && return

    echo -e "${GREEN}开始更新...${PLAIN}"
    systemctl stop snell
    local arch=$(get_arch)
    local url="https://dl.nssurge.com/snell/snell-server-${new}-linux-${arch}.zip"
    wget -q --show-progress "$url" -O /tmp/snell.zip
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，保持当前版本${PLAIN}"
        systemctl start snell; return 1
    fi
    unzip -o /tmp/snell.zip -d /usr/local/bin >/dev/null 2>&1
    rm -f /tmp/snell.zip
    chmod +x "$SNELL_BIN"
    systemctl daemon-reload
    systemctl start snell
    sleep 2
    snell_running && echo -e "${GREEN}更新成功：$(snell_version)${PLAIN}" \
                  || echo -e "${RED}启动失败${PLAIN}"
}

# =============================================
# SS2022 安装
# =============================================

ss_install() {
    if ss_installed; then
        echo -e "${YELLOW}SS2022 已安装，请使用更新功能${PLAIN}"; press_enter; return
    fi

    echo -e "${CYAN}获取最新版本...${PLAIN}"
    local ver=$(get_latest_github "shadowsocks/shadowsocks-rust")
    if [ -z "$ver" ]; then
        echo -e "${RED}获取失败，请检查网络${PLAIN}"; return 1
    fi
    echo -e "${GREEN}最新版本：${ver}${PLAIN}"

    local def_port=$(rand_port)
    read -p "端口    [默认随机: ${def_port}]: " inp_port
    local port=${inp_port:-$def_port}
    if ! valid_port "$port"; then
        echo -e "${RED}端口不合法，使用 ${def_port}${PLAIN}"; port=$def_port
    fi

    local def_pass=$(openssl rand -base64 16)
    echo -e "${GREEN}SS2022 密码须为 base64 格式，自动生成：${def_pass}${PLAIN}"
    read -p "密码    [默认随机，直接回车]: " inp_pass
    local pass=${inp_pass:-$def_pass}

    read -p "开启 TFO？[Y/n，默认Y]: " inp_tfo
    local tfo="True"
    [ "${inp_tfo,,}" = "n" ] && tfo=""

    install_deps

    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="aarch64-unknown-linux-gnu" || arch_str="x86_64-unknown-linux-gnu"
    local url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${ver}/shadowsocks-${ver}.${arch_str}.tar.xz"

    echo -e "${GREEN}下载 shadowsocks-rust ${ver}...${PLAIN}"
    wget -q --show-progress "$url" -O /tmp/ss.tar.xz
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败${PLAIN}"; return 1
    fi

    tar -xf /tmp/ss.tar.xz -C /tmp/ ssserver 2>/dev/null
    if [ ! -f /tmp/ssserver ]; then
        tar -xf /tmp/ss.tar.xz -C /tmp/ 2>/dev/null
    fi
    if [ ! -f /tmp/ssserver ]; then
        echo -e "${RED}未找到 ssserver 二进制${PLAIN}"; rm -f /tmp/ss.tar.xz; return 1
    fi
    mv /tmp/ssserver "$SS_BIN"
    rm -f /tmp/ss.tar.xz
    chmod +x "$SS_BIN"

    mkdir -p /etc/ss2022

    if [ -n "$tfo" ]; then
        cat > "$SS_CONF" << EOF
{
    "server": "::",
    "server_port": ${port},
    "password": "${pass}",
    "method": "2022-blake3-aes-128-gcm",
    "mode": "tcp_and_udp",
    "fast_open": true
}
EOF
    else
        cat > "$SS_CONF" << EOF
{
    "server": "::",
    "server_port": ${port},
    "password": "${pass}",
    "method": "2022-blake3-aes-128-gcm",
    "mode": "tcp_and_udp"
}
EOF
    fi

    cat > "$SS_SERVICE" << EOF
[Unit]
Description=Shadowsocks-rust SS2022 Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ssserver -c /etc/ss2022/config.json
LimitNOFILE=32768
Restart=on-failure
RestartSec=3
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

    # 防火墙放行
    firewall_allow "$port"

    if ss_running; then
        echo -e "${GREEN}SS2022 安装成功！${PLAIN}"
        echo ""; hr
        echo -e "${CYAN}Surge 节点：${PLAIN}"
        ss_surge_line
        hr
    else
        echo -e "${RED}启动失败：journalctl -u ss2022.service -n 20 --no-pager${PLAIN}"
    fi
}

# =============================================
# SS2022 卸载
# =============================================

ss_uninstall() {
    ! ss_installed && echo -e "${RED}SS2022 未安装${PLAIN}" && return
    read -p "确认卸载 SS2022？[y/N]: " c
    [[ "${c,,}" != "y" ]] && echo "已取消" && return
    systemctl stop ss2022 2>/dev/null
    systemctl disable ss2022 2>/dev/null
    rm -f "$SS_SERVICE"
    systemctl daemon-reload
    rm -f "$SS_BIN"
    rm -rf /etc/ss2022
    echo -e "${GREEN}SS2022 已卸载${PLAIN}"
}

# =============================================
# SS2022 更新
# =============================================

ss_update() {
    ! ss_installed && echo -e "${RED}SS2022 未安装${PLAIN}" && return
    local cur=$(ss_version)
    echo -e "${CYAN}检查版本...${PLAIN}"
    local new=$(get_latest_github "shadowsocks/shadowsocks-rust")
    if [ -z "$new" ]; then
        echo -e "${RED}获取失败${PLAIN}"; return
    fi
    echo -e "当前：${YELLOW}${cur}${PLAIN}  最新：${GREEN}${new}${PLAIN}"
    [ "$cur" = "$new" ] && echo -e "${GREEN}已是最新版本${PLAIN}" && return

    echo -e "${GREEN}开始更新...${PLAIN}"
    systemctl stop ss2022
    local arch=$(get_arch)
    local arch_str
    [ "$arch" = "aarch64" ] && arch_str="aarch64-unknown-linux-gnu" || arch_str="x86_64-unknown-linux-gnu"
    local url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${new}/shadowsocks-${new}.${arch_str}.tar.xz"
    wget -q --show-progress "$url" -O /tmp/ss.tar.xz
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败，保持当前版本${PLAIN}"
        systemctl start ss2022; return 1
    fi
    tar -xf /tmp/ss.tar.xz -C /tmp/ ssserver 2>/dev/null || tar -xf /tmp/ss.tar.xz -C /tmp/ 2>/dev/null
    [ -f /tmp/ssserver ] && mv /tmp/ssserver "$SS_BIN" && chmod +x "$SS_BIN"
    rm -f /tmp/ss.tar.xz
    systemctl start ss2022
    sleep 2
    ss_running && echo -e "${GREEN}更新成功：$(ss_version)${PLAIN}" \
               || echo -e "${RED}启动失败${PLAIN}"
}

# =============================================
# 1. 协议管理菜单
# =============================================

protocol_menu() {
    while true; do
        clear; hr
        echo "  协议管理"
        hr
        if snell_installed; then
            snell_running && echo -e "  Snell   |  ${GREEN}运行中${PLAIN}" \
                          || echo -e "  Snell   |  ${RED}未运行${PLAIN}"
        else
            echo -e "  Snell   |  ${RED}未安装${PLAIN}"
        fi
        if ss_installed; then
            ss_running && echo -e "  SS2022  |  ${GREEN}运行中${PLAIN}" \
                       || echo -e "  SS2022  |  ${RED}未运行${PLAIN}"
        else
            echo -e "  SS2022  |  ${RED}未安装${PLAIN}"
        fi
        if anytls_installed; then
            anytls_running && echo -e "  AnyTLS  |  ${GREEN}运行中${PLAIN}" \
                           || echo -e "  AnyTLS  |  ${RED}未运行${PLAIN}"
        else
            echo -e "  AnyTLS  |  ${RED}未安装${PLAIN}"
        fi
        hr

        local opts=() labels=()
        snell_installed   || { opts+=("ins");  labels+=("安装 Snell  "); }
        ss_installed      || { opts+=("iss");  labels+=("安装 SS2022 "); }
        anytls_installed  || { opts+=("iat");  labels+=("安装 AnyTLS "); }
        snell_installed   && { opts+=("uns");  labels+=("卸载 Snell  "); }
        ss_installed      && { opts+=("uss");  labels+=("卸载 SS2022 "); }
        anytls_installed  && { opts+=("uat");  labels+=("卸载 AnyTLS "); }

        for i in "${!opts[@]}"; do echo "  $((i+1)). ${labels[$i]}"; done
        echo "  0. 返回主菜单"
        hr
        read -p "请选择操作: " c; echo ""

        [ "$c" = "0" ] && return
        local idx=$((c-1))
        if [[ "$idx" -ge 0 && "$idx" -lt "${#opts[@]}" ]]; then
            case "${opts[$idx]}" in
                ins) snell_install    ;;
                iss) ss_install       ;;
                iat) anytls_install   ;;
                uns) snell_uninstall  ;;
                uss) ss_uninstall     ;;
                uat) anytls_uninstall ;;
            esac
        else
            echo -e "${RED}无效选项${PLAIN}"
        fi
        press_enter
    done
}

# =============================================
# 2. 查看配置菜单
# =============================================

view_config_menu() {
    while true; do
        clear; hr
        echo "  查看配置"
        hr
        echo "  1. 查看配置文件"
        echo "  2. 导出节点信息"
        echo "  0. 返回主菜单"
        hr
        read -p "请选择操作: " c; echo ""
        case "$c" in
            1)
                if snell_installed; then
                    echo -e "${CYAN}=== Snell 配置 ===${PLAIN}"
                    cat "$SNELL_CONF"; echo ""
                fi
                if ss_installed; then
                    echo -e "${CYAN}=== SS2022 配置 ===${PLAIN}"
                    cat "$SS_CONF"; echo ""
                fi
                if anytls_installed; then
                    echo -e "${CYAN}=== AnyTLS 配置 ===${PLAIN}"
                    echo "端口：$(anytls_port)"
                    echo "密码：$(anytls_conf_get ANYTLS_PASSWORD)"
                    echo "SNI ：$(anytls_conf_get ANYTLS_CLIENT_SNI)"; echo ""
                fi
                ! snell_installed && ! ss_installed && ! anytls_installed && echo "  暂无已安装的协议"
                ;;
            2)
                hr
                if snell_installed; then
                    echo -e "${CYAN}Snell：${PLAIN}"
                    snell_surge_line; echo ""
                fi
                if ss_installed; then
                    echo -e "${CYAN}SS2022：${PLAIN}"
                    ss_surge_line; echo ""
                fi
                if anytls_installed; then
                    echo -e "${CYAN}AnyTLS：${PLAIN}"
                    anytls_surge_line; echo ""
                fi
                ! snell_installed && ! ss_installed && ! anytls_installed && echo "  暂无已安装的协议"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${PLAIN}" ;;
        esac
        press_enter
    done
}

# =============================================
# 3. 修改配置菜单
# =============================================

snell_modify_menu() {
    while true; do
        clear; hr
        local port=$(snell_port)
        local tfo=$(snell_get "tfo")
        local tfo_s; [ "$tfo" = "true" ] && tfo_s="${GREEN}开启${PLAIN}" || tfo_s="${YELLOW}关闭${PLAIN}"
        echo -e "  修改 Snell | 端口: ${port} | TFO: ${tfo_s}"
        hr
        echo "  1. 修改端口"
        echo "  2. 修改 PSK"
        echo "  3. TFO 开关"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " c; echo ""
        case "$c" in
            1)
                echo -e "当前端口：${CYAN}${port}${PLAIN}"
                read -p "新端口: " np
                if valid_port "$np"; then
                    snell_set "listen" "0.0.0.0:${np},[::]:${np}"
                    systemctl restart snell
                    firewall_allow "$np"
                    echo -e "${GREEN}端口已改为 ${np}${PLAIN}"
                else
                    echo -e "${RED}端口不合法${PLAIN}"
                fi
                ;;
            2)
                echo -e "当前 PSK：${CYAN}$(snell_get psk)${PLAIN}"
                while true; do
                    local dp=$(rand_pass)
                    read -p "新 PSK [默认随机，至少16位]: " np
                    np=${np:-$dp}
                    if [ ${#np} -ge 16 ]; then
                        snell_set "psk" "$np"
                        systemctl restart snell
                        echo -e "${GREEN}PSK 已修改${PLAIN}"
                        break
                    else
                        echo -e "${RED}PSK 至少需要 16 位${PLAIN}"
                    fi
                done
                ;;
            3)
                if [ "$(snell_get tfo)" = "true" ]; then
                    snell_del "tfo"
                    echo -e "${GREEN}TFO 已关闭${PLAIN}"
                else
                    snell_set "tfo" "true"
                    echo -e "${GREEN}TFO 已开启${PLAIN}"
                fi
                systemctl restart snell
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${PLAIN}" ;;
        esac
        press_enter
    done
}

ss_modify_menu() {
    while true; do
        clear; hr
        local port=$(ss_get "server_port")
        local tfo=$(ss_get "fast_open")
        local tfo_s; [ "$tfo" = "True" ] && tfo_s="${GREEN}开启${PLAIN}" || tfo_s="${YELLOW}关闭${PLAIN}"
        echo -e "  修改 SS2022 | 端口: ${port} | TFO: ${tfo_s}"
        hr
        echo "  1. 修改端口"
        echo "  2. 修改密码"
        echo "  3. TFO 开关"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " c; echo ""
        case "$c" in
            1)
                echo -e "当前端口：${CYAN}${port}${PLAIN}"
                read -p "新端口: " np
                if valid_port "$np"; then
                    ss_set_int "server_port" "$np"
                    systemctl restart ss2022
                    firewall_allow "$np"
                    echo -e "${GREEN}端口已改为 ${np}${PLAIN}"
                else
                    echo -e "${RED}端口不合法${PLAIN}"
                fi
                ;;
            2)
                echo -e "当前密码：${CYAN}$(ss_get password)${PLAIN}"
                local dp=$(openssl rand -base64 16)
                read -p "新密码（base64）[默认随机]: " np
                np=${np:-$dp}
                ss_set_str "password" "$np"
                systemctl restart ss2022
                echo -e "${GREEN}密码已修改${PLAIN}"
                ;;
            3)
                if [ "$(ss_get fast_open)" = "True" ]; then
                    ss_del_key "fast_open"
                    echo -e "${GREEN}TFO 已关闭${PLAIN}"
                else
                    ss_set_bool "fast_open" "True"
                    echo -e "${GREEN}TFO 已开启${PLAIN}"
                fi
                systemctl restart ss2022
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${PLAIN}" ;;
        esac
        press_enter
    done
}


anytls_modify_menu() {
    while true; do
        clear; hr
        local port=$(anytls_port)
        echo -e "  修改 AnyTLS | 端口: ${port}"
        hr
        echo "  1. 修改端口"
        echo "  2. 修改密码"
        echo "  3. 修改 SNI"
        echo "  0. 返回"
        hr
        read -p "请选择操作: " c; echo ""
        case "$c" in
            1)
                echo -e "当前端口：${CYAN}${port}${PLAIN}"
                read -p "新端口: " np
                if valid_port "$np"; then
                    anytls_conf_set "ANYTLS_LISTEN" "0.0.0.0:${np}"
                    anytls_write_service
                    systemctl restart anytls
                    firewall_allow "$np"
                    echo -e "${GREEN}端口已改为 ${np}${PLAIN}"
                else
                    echo -e "${RED}端口不合法${PLAIN}"
                fi
                ;;
            2)
                echo -e "当前密码：${CYAN}$(anytls_conf_get ANYTLS_PASSWORD)${PLAIN}"
                local dp=$(rand_pass)
                read -p "新密码 [默认随机]: " np; np=${np:-$dp}
                anytls_conf_set "ANYTLS_PASSWORD" "$np"
                anytls_write_service
                systemctl restart anytls
                echo -e "${GREEN}密码已修改${PLAIN}"
                ;;
            3)
                local cur_sni=$(anytls_conf_get "ANYTLS_CLIENT_SNI")
                echo -e "当前 SNI：${CYAN}${cur_sni:-不发送}${PLAIN}"
                read -p "新 SNI [输入 none 清空]: " np
                [ "$np" = "none" ] && np=""
                anytls_conf_set "ANYTLS_CLIENT_SNI" "$np"
                echo -e "${GREEN}SNI 已修改${PLAIN}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项${PLAIN}" ;;
        esac
        press_enter
    done
}

modify_config_menu() {
    while true; do
        clear; hr
        echo "  修改配置"
        hr

        local opts=() labels=()
        snell_installed   && { opts+=("s");   labels+=("修改 Snell  "); }
        ss_installed      && { opts+=("ss");  labels+=("修改 SS2022 "); }
        anytls_installed  && { opts+=("at");  labels+=("修改 AnyTLS "); }

        if [ "${#opts[@]}" -eq 0 ]; then
            echo "  暂无已安装的协议"
            echo "  0. 返回主菜单"
            hr; read -p "请选择操作: " c
            [ "$c" = "0" ] && return; continue
        fi

        for i in "${!opts[@]}"; do echo "  $((i+1)). ${labels[$i]}"; done
        echo "  0. 返回主菜单"
        hr
        read -p "请选择操作: " c; echo ""

        [ "$c" = "0" ] && return
        local idx=$((c-1))
        if [[ "$idx" -ge 0 && "$idx" -lt "${#opts[@]}" ]]; then
            case "${opts[$idx]}" in
                s)  snell_modify_menu  ;;
                ss) ss_modify_menu     ;;
                at) anytls_modify_menu ;;
            esac
        else
            echo -e "${RED}无效选项${PLAIN}"; press_enter
        fi
    done
}

# =============================================
# 4. 查看状态菜单
# =============================================

status_menu() {
    while true; do
        clear; hr
        echo "  协议状态"
        hr
        if snell_installed; then
            local sv=$(snell_version); local sv_s
            snell_running && sv_s="${GREEN}运行中${PLAIN}" || sv_s="${RED}未运行${PLAIN}"
            echo -e "  Snell   |  ${sv_s}  |  ${sv}  |  端口: $(snell_port)"
        fi
        if ss_installed; then
            local sv2=$(ss_version); local ss_s
            ss_running && ss_s="${GREEN}运行中${PLAIN}" || ss_s="${RED}未运行${PLAIN}"
            echo -e "  SS2022  |  ${ss_s}  |  ${sv2}  |  端口: $(ss_get server_port)"
        fi
        if anytls_installed; then
            local av=$(anytls_version); local at_s
            anytls_running && at_s="${GREEN}运行中${PLAIN}" || at_s="${RED}未运行${PLAIN}"
            echo -e "  AnyTLS  |  ${at_s}  |  ${av}  |  端口: $(anytls_port)"
        fi
        ! snell_installed && ! ss_installed && ! anytls_installed && echo "  暂无已安装的协议"
        hr

        local opts=() labels=()
        local any_running=false
        snell_running  && any_running=true
        ss_running     && any_running=true
        anytls_running && any_running=true

        $any_running && { opts+=("stop");    labels+=("停止所有服务"); } \
                     || { opts+=("start");   labels+=("启动所有服务"); }
        opts+=("restart"); labels+=("重启所有服务")
        snell_installed   && { opts+=("us");  labels+=("更新 Snell  "); }
        ss_installed      && { opts+=("uss"); labels+=("更新 SS2022 "); }
        anytls_installed  && { opts+=("uat"); labels+=("更新 AnyTLS "); }

        for i in "${!opts[@]}"; do echo "  $((i+1)). ${labels[$i]}"; done
        echo "  0. 返回主菜单"
        hr
        read -p "请选择操作: " c; echo ""

        [ "$c" = "0" ] && return
        local idx=$((c-1))
        if [[ "$idx" -ge 0 && "$idx" -lt "${#opts[@]}" ]]; then
            case "${opts[$idx]}" in
                stop)
                    snell_installed   && systemctl stop snell
                    ss_installed      && systemctl stop ss2022
                    anytls_installed  && systemctl stop anytls
                    echo -e "${GREEN}所有服务已停止${PLAIN}"
                    ;;
                start)
                    snell_installed   && systemctl start snell
                    ss_installed      && systemctl start ss2022
                    anytls_installed  && systemctl start anytls
                    echo -e "${GREEN}所有服务已启动${PLAIN}"
                    ;;
                restart)
                    snell_installed   && systemctl restart snell
                    ss_installed      && systemctl restart ss2022
                    anytls_installed  && systemctl restart anytls
                    sleep 1; echo -e "${GREEN}所有服务已重启${PLAIN}"
                    ;;
                us)  snell_update  ;;
                uss) ss_update     ;;
                uat) anytls_update ;;
            esac
        else
            echo -e "${RED}无效选项${PLAIN}"
        fi
        press_enter
    done
}

# =============================================
# 5. 卸载脚本
# =============================================

uninstall_all() {
    clear; hr
    echo -e "  ${RED}警告：此操作将卸载所有已安装的协议${PLAIN}"
    hr
    read -p "确认卸载？请输入 YES（大写）: " confirm
    [ "$confirm" != "YES" ] && echo "已取消" && return

    echo -e "${YELLOW}正在卸载...${PLAIN}"
    if snell_installed; then
        systemctl stop snell 2>/dev/null
        systemctl disable snell 2>/dev/null
        rm -f "$SNELL_SERVICE"
        systemctl daemon-reload
        rm -f "$SNELL_BIN"
        rm -rf /etc/snell
        echo -e "${GREEN}Snell 已卸载${PLAIN}"
    fi
    if ss_installed; then
        systemctl stop ss2022 2>/dev/null
        systemctl disable ss2022 2>/dev/null
        rm -f "$SS_SERVICE"
        systemctl daemon-reload
        rm -f "$SS_BIN"
        rm -rf /etc/ss2022
        echo -e "${GREEN}SS2022 已卸载${PLAIN}"
    fi
    if anytls_installed; then
        systemctl stop anytls 2>/dev/null
        systemctl disable anytls 2>/dev/null
        rm -f "$ANYTLS_SERVICE"
        systemctl daemon-reload
        rm -f "$ANYTLS_BIN"
        rm -rf "$ANYTLS_DIR"
        echo -e "${GREEN}AnyTLS 已卸载${PLAIN}"
    fi

    local script_path
    script_path=$(realpath "$0" 2>/dev/null || echo "$0")
    echo -e "${GREEN}卸载完成${PLAIN}"
    read -p "是否同时删除脚本文件？[y/N]: " dc
    [[ "${dc,,}" = "y" ]] && rm -f "$script_path" && echo -e "${GREEN}脚本已删除${PLAIN}"
    exit 0
}

# =============================================
# 主菜单
# =============================================

main_menu() {
    while true; do
        clear; hr
        echo "  代理管理工具"
        hr
        if snell_installed; then
            snell_running && echo -e "  Snell   |  ${GREEN}运行中${PLAIN}" \
                          || echo -e "  Snell   |  ${RED}未运行${PLAIN}"
        else
            echo -e "  Snell   |  ${RED}未安装${PLAIN}"
        fi
        if ss_installed; then
            ss_running && echo -e "  SS2022  |  ${GREEN}运行中${PLAIN}" \
                       || echo -e "  SS2022  |  ${RED}未运行${PLAIN}"
        else
            echo -e "  SS2022  |  ${RED}未安装${PLAIN}"
        fi
        if anytls_installed; then
            anytls_running && echo -e "  AnyTLS  |  ${GREEN}运行中${PLAIN}" \
                           || echo -e "  AnyTLS  |  ${RED}未运行${PLAIN}"
        else
            echo -e "  AnyTLS  |  ${RED}未安装${PLAIN}"
        fi
        hr
        echo "  1. 协议管理"
        echo "  2. 查看配置"
        echo "  3. 修改配置"
        echo "  4. 查看状态"
        echo "  5. 卸载脚本"
        echo "  0. 退出脚本"
        hr
        read -p "请选择操作: " c; echo ""
        case "$c" in
            1) protocol_menu      ;;
            2) view_config_menu   ;;
            3) modify_config_menu ;;
            4) status_menu        ;;
            5) uninstall_all      ;;
            0) echo -e "${GREEN}再见${PLAIN}"; exit 0 ;;
            *) echo -e "${RED}无效选项${PLAIN}"; sleep 1 ;;
        esac
    done
}

# =============================================
# 入口
# =============================================

trap 'echo -e "\n${RED}已中断${PLAIN}"; exit 1' INT
check_root
main_menu
