#!/bin/bash

# Ubuntu自动开关机系统安装脚本
# 使用方法: sudo bash install-auto-power.sh

echo "正在安装Ubuntu自动开关机系统..."

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用sudo权限运行此脚本"
    echo "正确用法: sudo bash install-auto-power.sh"
    exit 1
fi

# 检查rtcwake命令
if ! command -v rtcwake >/dev/null 2>&1; then
    echo "错误: 系统未安装rtcwake命令"
    echo "请先安装: sudo apt-get install util-linux"
    exit 1
fi

# 创建目录
echo "创建系统目录..."
mkdir -p /etc/auto-power

# 创建配置文件
echo "创建配置文件..."
cat > /etc/auto-power/config.conf << 'EOF'
# 自动开关机配置文件
# 格式: ENABLED=true/false, SHUTDOWN_TIME=HH:MM, WAKEUP_TIME=HH:MM

# 是否启用自动开关机 (true/false)
ENABLED=true

# 关机时间 (24小时制，格式: HH:MM)
SHUTDOWN_TIME=01:30

# 开机时间 (24小时制，格式: HH:MM)
WAKEUP_TIME=09:30

# 日志文件路径
LOG_FILE=/var/log/auto-power.log

# 是否在关机前发送通知 (true/false)
SEND_NOTIFICATION=true

# 关机前等待时间(分钟)
SHUTDOWN_DELAY=5
EOF

# 创建主管理脚本
echo "创建主管理脚本..."
cat > /usr/local/bin/auto-power-manager << 'EOF'
#!/bin/bash

CONFIG_FILE="/etc/auto-power/config.conf"
LOG_FILE="/var/log/auto-power.log"
CRON_FILE="/tmp/auto-power-cron"

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "错误: 配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
}

# 日志记录
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查RTC唤醒支持
check_rtc_support() {
    if ! command -v rtcwake >/dev/null 2>&1; then
        log_message "错误: rtcwake命令不可用"
        return 1
    fi
    
    # 检查RTC设备
    if [ ! -e /dev/rtc0 ]; then
        log_message "错误: /dev/rtc0 设备不存在"
        return 1
    fi
    
    # 测试rtcwake是否工作正常（需要sudo权限）
    if [ "$EUID" -eq 0 ]; then
        if ! /usr/sbin/rtcwake --dry-run --mode no --time "$(date -d "+1 minute" +%s)" >/dev/null 2>&1; then
            log_message "警告: rtcwake功能异常，可能需要在BIOS中启用RTC唤醒"
            return 1
        fi
        log_message "RTC唤醒功能正常"
    else
        log_message "警告: 需要sudo权限来完全测试rtcwake功能"
    fi
    
    return 0
}

# 设置RTC唤醒时间并关机
set_wakeup_and_shutdown() {
    local wakeup_time="$1"
    local delay_minutes="$2"
    
    # 计算明天的唤醒时间
    local tomorrow_wakeup=$(date -d "tomorrow $wakeup_time" '+%Y-%m-%d %H:%M:%S')
    
    log_message "设置RTC唤醒时间: $tomorrow_wakeup"
    
    # 发送通知
    if [ "$SEND_NOTIFICATION" = "true" ]; then
        wall "系统将在 $delay_minutes 分钟后关机，明天 $wakeup_time 自动开机"
    fi
    
    # 等待指定时间
    sleep ${delay_minutes}m
    
    # 使用rtcwake设置唤醒时间并关机
    log_message "使用rtcwake执行关机和唤醒设置"
    /usr/sbin/rtcwake --mode off --time "$(date -d "$tomorrow_wakeup" +%s)" 2>&1 | tee -a "$LOG_FILE"
}

# 测试rtcwake功能
test_rtcwake() {
    echo "测试rtcwake功能..."
    
    # 检查是否有sudo权限
    if [ "$EUID" -ne 0 ]; then
        echo "注意: rtcwake命令需要sudo权限"
        echo "请使用: sudo auto-power-manager test-rtc"
        return 1
    fi
    
    # 检查RTC设备
    echo "1. 检查RTC设备:"
    if [ -e /dev/rtc0 ]; then
        echo "✓ /dev/rtc0 设备存在"
        ls -l /dev/rtc0
    else
        echo "✗ /dev/rtc0 设备不存在"
        return 1
    fi
    
    echo ""
    echo "2. 测试dry-run模式:"
    if /usr/sbin/rtcwake --dry-run --mode no --time "$(date -d "+1 minute" +%s)" 2>&1; then
        echo "✓ rtcwake dry-run 测试成功"
    else
        echo "✗ rtcwake dry-run 测试失败"
        return 1
    fi
    
    echo ""
    echo "3. RTC时间信息:"
    /usr/sbin/rtcwake --dry-run --mode no --time "$(date -d "+1 minute" +%s)" 2>&1 | grep "wakeup using" || echo "无法获取RTC时间信息"
    
    echo ""
    echo "4. 测试5分钟后的唤醒时间计算:"
    local test_time=$(date -d "+5 minutes" +%s)
    echo "5分钟后的时间戳: $test_time"
    echo "对应时间: $(date -d "@$test_time" '+%Y-%m-%d %H:%M:%S')"
    
    echo ""
    echo "5. 验证RTC唤醒支持:"
    if [ -f /sys/class/rtc/rtc0/wakealarm ]; then
        echo "✓ 系统支持RTC唤醒"
        echo "当前wakealarm: $(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null || echo '无')"
    else
        echo "✗ 系统不支持RTC唤醒"
    fi
}

# 安全关机
safe_shutdown() {
    local custom_delay="$1"
    load_config

    if [ "$ENABLED" = "true" ]; then
        log_message "开始执行自动关机流程"

        # 使用自定义延迟时间，如果没有提供则使用配置文件中的默认值
        local delay_to_use="${custom_delay:-$SHUTDOWN_DELAY}"
        log_message "关机延迟时间: $delay_to_use 分钟"

        # 使用rtcwake设置唤醒时间并关机
        set_wakeup_and_shutdown "$WAKEUP_TIME" "$delay_to_use"
    else
        log_message "自动关机已禁用，跳过关机流程"
    fi
}

# 更新cron任务
update_cron() {
    load_config
    
    # 清除现有的auto-power cron任务
    crontab -l 2>/dev/null | grep -v "auto-power" > "$CRON_FILE"
    
    if [ "$ENABLED" = "true" ]; then
        # 解析关机时间
        local shutdown_hour=$(echo "$SHUTDOWN_TIME" | cut -d: -f1)
        local shutdown_minute=$(echo "$SHUTDOWN_TIME" | cut -d: -f2)
        
        # 添加新的cron任务
        echo "$shutdown_minute $shutdown_hour * * * /usr/local/bin/auto-power-manager shutdown" >> "$CRON_FILE"
        
        log_message "启用自动关机: 每天 $SHUTDOWN_TIME 关机，$WAKEUP_TIME 开机"
    else
        log_message "禁用自动关机任务"
    fi
    
    # 安装新的cron任务
    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"
}

# 显示状态
show_status() {
    load_config
    
    echo "=== 自动开关机状态 ==="
    echo "状态: $([ "$ENABLED" = "true" ] && echo "启用" || echo "禁用")"
    echo "关机时间: $SHUTDOWN_TIME"
    echo "开机时间: $WAKEUP_TIME"
    echo "日志文件: $LOG_FILE"
    echo ""
    
    # 显示当前cron任务
    echo "=== 当前定时任务 ==="
    crontab -l 2>/dev/null | grep "auto-power" || echo "无自动开关机任务"
    echo ""
    
    # 显示RTC唤醒信息
    echo "=== RTC唤醒信息 ==="
    if command -v rtcwake >/dev/null 2>&1; then
        echo "rtcwake命令可用"
        # 尝试获取下次唤醒时间（如果设置了的话）
        if [ -f /sys/class/rtc/rtc0/wakealarm ]; then
            local wakealarm=$(cat /sys/class/rtc/rtc0/wakealarm 2>/dev/null)
            if [ "$wakealarm" != "0" ] && [ -n "$wakealarm" ]; then
                echo "下次唤醒时间: $(date -d "@$wakealarm" '+%Y-%m-%d %H:%M:%S')"
            else
                echo "未设置RTC唤醒时间"
            fi
        else
            echo "无法读取RTC唤醒信息"
        fi
    else
        echo "rtcwake命令不可用"
    fi
    
    # 显示最近的日志
    echo ""
    echo "=== 最近日志 (最后10条) ==="
    if [ -f "$LOG_FILE" ]; then
        tail -n 10 "$LOG_FILE"
    else
        echo "暂无日志记录"
    fi
}

# 启用自动开关机
enable_auto_power() {
    sed -i 's/ENABLED=false/ENABLED=true/' "$CONFIG_FILE"
    update_cron
    log_message "自动开关机已启用"
    echo "自动开关机已启用"
}

# 禁用自动开关机
disable_auto_power() {
    sed -i 's/ENABLED=true/ENABLED=false/' "$CONFIG_FILE"
    update_cron
    log_message "自动开关机已禁用"
    echo "自动开关机已禁用，机器将保持持续运行"
}

# 设置时间
set_time() {
    local type="$1"
    local time="$2"
    
    if [[ ! "$time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
        echo "错误: 时间格式无效，请使用 HH:MM 格式"
        exit 1
    fi
    
    case "$type" in
        "shutdown")
            sed -i "s/SHUTDOWN_TIME=.*/SHUTDOWN_TIME=$time/" "$CONFIG_FILE"
            echo "关机时间已设置为: $time"
            ;;
        "wakeup")
            sed -i "s/WAKEUP_TIME=.*/WAKEUP_TIME=$time/" "$CONFIG_FILE"
            echo "开机时间已设置为: $time"
            ;;
        *)
            echo "错误: 类型无效，请使用 shutdown 或 wakeup"
            exit 1
            ;;
    esac
    
    update_cron
    log_message "时间设置已更新: $type = $time"
}

# 显示帮助
show_help() {
    cat << 'HELP'
Ubuntu自动开关机管理工具

用法: auto-power-manager <命令> [参数]

命令:
    status                  显示当前状态
    enable                  启用自动开关机
    disable                 禁用自动开关机
    set-shutdown <时间>     设置关机时间 (HH:MM)
    set-wakeup <时间>       设置开机时间 (HH:MM)
    shutdown [延迟分钟]     执行关机流程 (可选指定延迟时间)
    update-cron             更新cron任务
    test-rtc                测试rtcwake功能
    install                 安装/初始化系统
    help                    显示此帮助信息

示例:
    auto-power-manager status
    auto-power-manager enable
    auto-power-manager disable
    auto-power-manager set-shutdown 01:30
    auto-power-manager set-wakeup 09:30
    auto-power-manager shutdown 2        # 2分钟后关机
    auto-power-manager shutdown          # 使用默认延迟时间

配置文件: /etc/auto-power/config.conf
日志文件: /var/log/auto-power.log
HELP
}

# 安装系统
install_system() {
    echo "正在安装自动开关机系统..."
    
    # 创建目录
    mkdir -p /etc/auto-power
    
    # 创建配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "配置文件已存在，跳过创建"
    fi
    
    # 创建日志文件
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # 设置脚本权限
    chmod +x /usr/local/bin/auto-power-manager
    
    # 检查RTC支持
    check_rtc_support
    
    # 更新cron任务
    update_cron
    
    echo "安装完成！"
    echo "使用 'auto-power-manager help' 查看帮助"
}

# 主程序
main() {
    case "$1" in
        "status")
            show_status
            ;;
        "enable")
            enable_auto_power
            ;;
        "disable")
            disable_auto_power
            ;;
        "set-shutdown")
            set_time "shutdown" "$2"
            ;;
        "set-wakeup")
            set_time "wakeup" "$2"
            ;;
        "shutdown")
            safe_shutdown "$2"
            ;;
        "update-cron")
            update_cron
            echo "Cron任务已更新"
            ;;
        "test-rtc")
            test_rtcwake
            ;;
        "install")
            install_system
            ;;
        "help"|"")
            show_help
            ;;
        *)
            echo "错误: 未知命令 '$1'"
            echo "使用 'auto-power-manager help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
EOF

# 设置权限
echo "设置脚本权限..."
chmod +x /usr/local/bin/auto-power-manager

# 创建日志文件
echo "创建日志文件..."
touch /var/log/auto-power.log
chmod 644 /var/log/auto-power.log

# 测试rtcwake功能
echo ""
echo "测试rtcwake功能..."
if /usr/sbin/rtcwake --dry-run --time +5 >/dev/null 2>&1; then
    echo "✓ rtcwake功能正常"
else
    echo "⚠ rtcwake功能异常，可能需要在BIOS中启用RTC唤醒"
fi

# 初始化系统
echo ""
echo "初始化系统..."
/usr/local/bin/auto-power-manager install

echo ""
echo "=============================================="
echo "安装完成！"
echo "=============================================="
echo ""
echo "常用命令："
echo "  查看状态: auto-power-manager status"
echo "  测试rtcwake: sudo auto-power-manager test-rtc"
echo "  启用功能: sudo auto-power-manager enable"
echo "  禁用功能: sudo auto-power-manager disable"
echo "  设置关机时间: sudo auto-power-manager set-shutdown 01:30"
echo "  设置开机时间: sudo auto-power-manager set-wakeup 09:30"
echo ""
echo "注意: 大部分命令需要sudo权限"
echo ""
echo "配置文件: /etc/auto-power/config.conf"
echo "日志文件: /var/log/auto-power.log"
echo ""
echo "请先运行 'sudo auto-power-manager test-rtc' 测试功能"
echo "然后运行 'auto-power-manager status' 查看状态"
echo ""
echo "重要提醒: rtcwake需要sudo权限才能访问/dev/rtc0设备"
