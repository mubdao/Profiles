# =============================================
# 主菜单与动态执行逻辑
# =============================================

main() {
    check_root
    while true; do
        clear
        
        # 顶部状态显示面板
        local snell_ver="未安装" ss_ver="未安装" anytls_ver="未安装"
        local snell_stat="${RED}未安装${RESET}" ss_stat="${RED}未安装${RESET}" anytls_stat="${RED}未安装${RESET}"

        if snell_installed; then
            snell_ver=$(snell_local_version)
            snell_running && snell_stat="${GREEN}运行中${RESET}" || snell_stat="${RED}未运行${RESET}"
        fi

        if ss_installed; then
            ss_ver=$(ss_local_version)
            ss_running && ss_stat="${GREEN}运行中${RESET}" || ss_stat="${RED}未运行${RESET}"
        fi

        if anytls_installed; then
            anytls_ver=$(anytls_local_version)
            anytls_running && anytls_stat="${GREEN}运行中${RESET}" || anytls_stat="${RED}未运行${RESET}"
        fi

        hr
        echo -e "  Snell    ${snell_ver} | ${snell_stat}"
        echo -e "  SS2022   ${ss_ver} | ${ss_stat}"
        echo -e "  AnyTLS   ${anytls_ver} | ${anytls_stat}"
        hr

        # 动态构建菜单数组
        local menu_actions=()
        local idx=1

        if snell_installed; then
            echo "  ${idx}. Snell 管理"
            menu_actions[$idx]="snell_menu"
            ((idx++))
        fi

        if ss_installed; then
            echo "  ${idx}. SS2022 管理"
            menu_actions[$idx]="ss_menu"
            ((idx++))
        fi

        if anytls_installed; then
            echo "  ${idx}. AnyTLS 管理"
            menu_actions[$idx]="anytls_menu"
            ((idx++))
        fi

        # 常驻选项
        echo "  ${idx}. 协议管理 (安装/卸载)"
        menu_actions[$idx]="protocol_manage_menu"
        ((idx++))

        echo "  ${idx}. 导出节点配置"
        menu_actions[$idx]="export_surge_configs"
        
        echo "  0. 退出"
        menu_actions[0]="exit_script"
        hr

        # 捕获用户输入
        read -p "请选择操作: " choice
        echo ""

        # 动态执行选择的函数
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ -n "${menu_actions[$choice]}" ]; then
            local action="${menu_actions[$choice]}"
            if [ "$action" = "exit_script" ]; then
                echo -e "${GREEN}再见${RESET}"
                exit 0
            else
                $action
            fi
        else
            echo -e "${RED}无效选项${RESET}"
            sleep 1
        fi
    done
}
