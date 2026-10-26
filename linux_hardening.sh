#!/bin/bash
# ============================================================
# Linux服务器安全加固脚本
# 功能：UFW防火墙配置、SSH安全加固、密码策略、自动安全更新、日志审计
# 作者：课程论文
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 备份目录
BACKUP_DIR="/tmp/security_backup_$(date +%Y%m%d_%H%M%S)"

# ============================================================
# 函数：打印带颜色的消息
# ============================================================
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================
# 函数：检查是否为root用户
# ============================================================
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "请使用root用户或sudo运行此脚本"
        exit 1
    fi
}

# ============================================================
# 函数：备份原始配置
# ============================================================
backup_config() {
    print_info "开始备份原始配置到 $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"
    
    # 备份sshd_config
    if [ -f /etc/ssh/sshd_config ]; then
        cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak"
        print_info "已备份 /etc/ssh/sshd_config"
    fi
    
    # 备份UFW规则
    ufw status > "$BACKUP_DIR/ufw_rules.bak" 2>/dev/null
    print_info "已备份UFW规则"
    
    # 备份密码策略
    cp /etc/login.defs "$BACKUP_DIR/login.defs.bak" 2>/dev/null
    print_info "已备份 /etc/login.defs"
    
    # 备份自动更新配置
    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        cp /etc/apt/apt.conf.d/20auto-upgrades "$BACKUP_DIR/20auto-upgrades.bak"
        print_info "已备份自动更新配置"
    fi
    
    print_info "配置备份完成，备份目录：$BACKUP_DIR"
}

# ============================================================
# 函数：配置UFW防火墙
# ============================================================
configure_ufw() {
    print_info "=== 开始配置UFW防火墙 ==="
    
    # 安装UFW（如果未安装）
    if ! command -v ufw &> /dev/null; then
        print_info "正在安装UFW..."
        apt-get update -qq && apt-get install -y ufw -qq
    fi
    
    # 默认策略：拒绝入站，允许出站
    ufw default deny incoming
    ufw default allow outgoing
    print_info "已设置默认策略：拒绝入站，允许出站"
    
    # 允许SSH（22端口）
    ufw allow 22/tcp
    print_info "已允许SSH（22端口）"
    
    # 允许HTTP（80端口）
    ufw allow 80/tcp
    print_info "已允许HTTP（80端口）"
    
    # 允许HTTPS（443端口）
    ufw allow 443/tcp
    print_info "已允许HTTPS（443端口）"
    
    # 启用UFW
    echo "y" | ufw enable
    print_info "UFW防火墙已启用"
    
    # 显示状态
    print_info "当前UFW状态："
    ufw status verbose
}

# ============================================================
# 函数：SSH安全加固
# ============================================================
harden_ssh() {
    print_info "=== 开始SSH安全加固 ==="
    
    SSHD_CONFIG="/etc/ssh/sshd_config"
    
    # 检查SSH服务是否安装
    if [ ! -f "$SSHD_CONFIG" ]; then
        print_warn "未找到sshd_config，正在安装openssh-server..."
        apt-get update -qq && apt-get install -y openssh-server -qq
    fi
    
    # 如果还是没有配置文件，跳过SSH加固
    if [ ! -f "$SSHD_CONFIG" ]; then
        print_error "SSH服务安装失败，跳过SSH加固步骤"
        return
    fi
    
    # 禁用root远程登录
    if grep -q "^PermitRootLogin" "$SSHD_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSHD_CONFIG"
    fi
    print_info "已禁用root远程登录"
    
    # 禁用密码登录（改为密钥认证）
    if grep -q "^PasswordAuthentication" "$SSHD_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    else
        echo "PasswordAuthentication no" >> "$SSHD_CONFIG"
    fi
    print_info "已禁用密码登录，仅允许密钥认证"
    
    # 设置登录超时时间（300秒无活动断开）
    if grep -q "^ClientAliveInterval" "$SSHD_CONFIG"; then
        sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
    else
        echo "ClientAliveInterval 300" >> "$SSHD_CONFIG"
    fi
    print_info "已设置登录超时：300秒无活动断开"
    
    # 限制最大认证尝试次数
    if grep -q "^MaxAuthTries" "$SSHD_CONFIG"; then
        sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"
    else
        echo "MaxAuthTries 3" >> "$SSHD_CONFIG"
    fi
    print_info "已设置最大认证尝试次数：3次"
    
    # 重启SSH服务（Ubuntu 20.04服务名是ssh不是sshd）
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    print_info "SSH服务已重启，配置生效"
    
    # 验证配置
    print_info "当前SSH关键配置："
    grep -E "^(PermitRootLogin|PasswordAuthentication|ClientAliveInterval|MaxAuthTries)" "$SSHD_CONFIG"
}

# ============================================================
# 函数：配置密码策略
# ============================================================
configure_password_policy() {
    print_info "=== 开始配置密码策略 ==="
    
    LOGIN_DEFS="/etc/login.defs"
    
    # 密码最小长度：12位
    if grep -q "^PASS_MIN_LEN" "$LOGIN_DEFS"; then
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    12/' "$LOGIN_DEFS"
    else
        echo "PASS_MIN_LEN    12" >> "$LOGIN_DEFS"
    fi
    print_info "已设置密码最小长度：12位"
    
    # 密码最大有效期：90天
    if grep -q "^PASS_MAX_DAYS" "$LOGIN_DEFS"; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$LOGIN_DEFS"
    else
        echo "PASS_MAX_DAYS   90" >> "$LOGIN_DEFS"
    fi
    print_info "已设置密码最大有效期：90天"
    
    # 密码过期前7天提醒
    if grep -q "^PASS_WARN_AGE" "$LOGIN_DEFS"; then
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' "$LOGIN_DEFS"
    else
        echo "PASS_WARN_AGE   7" >> "$LOGIN_DEFS"
    fi
    print_info "已设置密码过期前7天提醒"
    
    # 显示当前密码策略
    print_info "当前密码策略："
    grep -E "^(PASS_MIN_LEN|PASS_MAX_DAYS|PASS_WARN_AGE)" "$LOGIN_DEFS"
}

# ============================================================
# 函数：配置自动安全更新
# ============================================================
configure_auto_updates() {
    print_info "=== 开始配置自动安全更新 ==="
    
    # 安装unattended-upgrades
    if ! dpkg -l | grep -q unattended-upgrades; then
        print_info "正在安装unattended-upgrades..."
        apt-get update -qq && apt-get install -y unattended-upgrades -qq
    fi
    
    # 配置自动安全更新
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    print_info "已启用每日自动安全更新"
    
    # 验证配置
    print_info "当前自动更新配置："
    cat /etc/apt/apt.conf.d/20auto-upgrades
}

# ============================================================
# 函数：日志审计检查
# ============================================================
check_logging() {
    print_info "=== 开始日志审计检查 ==="
    
    # 检查auth.log是否存在
    if [ -f /var/log/auth.log ]; then
        print_info "认证日志 /var/log/auth.log 存在"
        
        # 统计失败登录次数
        failed_logins=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
        print_info "最近失败登录次数：$failed_logins 次"
        
        # 统计sudo使用次数
        sudo_usage=$(grep -c "sudo:" /var/log/auth.log 2>/dev/null || echo "0")
        print_info "最近sudo使用次数：$sudo_usage 次"
    else
        print_warn "未找到 /var/log/auth.log（可能使用systemd-journald）"
        journalctl -u sshd --since "24 hours ago" | grep -c "Failed password" | xargs -I{} echo "最近24小时SSH失败登录：{} 次"
    fi
    
    # 检查日志轮转配置
    if [ -f /etc/logrotate.d/rsyslog ]; then
        print_info "日志轮转配置存在：/etc/logrotate.d/rsyslog"
    fi
    
    print_info "日志审计检查完成"
}

# ============================================================
# 函数：生成加固报告
# ============================================================
generate_report() {
    print_info "=== 生成安全加固报告 ==="
    
    REPORT_FILE="/tmp/security_hardening_report.txt"
    
    echo "========================================" > "$REPORT_FILE"
    echo "Linux服务器安全加固报告" >> "$REPORT_FILE"
    echo "生成时间：$(date)" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "【防火墙状态】" >> "$REPORT_FILE"
    ufw status >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    
    echo "【SSH安全配置】" >> "$REPORT_FILE"
    grep -E "^(PermitRootLogin|PasswordAuthentication|ClientAliveInterval|MaxAuthTries)" /etc/ssh/sshd_config >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "【密码策略】" >> "$REPORT_FILE"
    grep -E "^(PASS_MIN_LEN|PASS_MAX_DAYS|PASS_WARN_AGE)" /etc/login.defs >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "【自动更新配置】" >> "$REPORT_FILE"
    cat /etc/apt/apt.conf.d/20auto-upgrades >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    echo "报告已生成：$REPORT_FILE"
    print_info "报告文件路径：$REPORT_FILE"
}

# ============================================================
# 函数：回滚到原始配置
# ============================================================
rollback() {
    print_warn "=== 开始回滚配置 ==="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "未找到备份目录，无法回滚"
        exit 1
    fi
    
    # 恢复sshd_config
    if [ -f "$BACKUP_DIR/sshd_config.bak" ]; then
        cp "$BACKUP_DIR/sshd_config.bak" /etc/ssh/sshd_config
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
        print_info "已恢复SSH配置"
    fi
    
    # 恢复UFW（禁用后重新配置）
    ufw --force reset
    print_info "UFW规则已重置"
    
    # 恢复密码策略
    if [ -f "$BACKUP_DIR/login.defs.bak" ]; then
        cp "$BACKUP_DIR/login.defs.bak" /etc/login.defs
        print_info "已恢复密码策略"
    fi
    
    # 恢复自动更新配置
    if [ -f "$BACKUP_DIR/20auto-upgrades.bak" ]; then
        cp "$BACKUP_DIR/20auto-upgrades.bak" /etc/apt/apt.conf.d/20auto-upgrades
        print_info "已恢复自动更新配置"
    fi
    
    print_info "回滚完成"
}

# ============================================================
# 主函数
# ============================================================
main() {
    echo "========================================"
    echo "  Linux服务器安全加固脚本"
    echo "========================================"
    echo ""
    
    check_root
    
    # 检查是否为回滚模式
    if [ "$1" = "--rollback" ]; then
        rollback
        exit 0
    fi
    
    # 1. 备份配置
    backup_config
    echo ""
    
    # 2. 配置UFW防火墙
    configure_ufw
    echo ""
    
    # 3. SSH安全加固
    harden_ssh
    echo ""
    
    # 4. 配置密码策略
    configure_password_policy
    echo ""
    
    # 5. 配置自动安全更新
    configure_auto_updates
    echo ""
    
    # 6. 日志审计检查
    check_logging
    echo ""
    
    # 7. 生成报告
    generate_report
    echo ""
    
    echo "========================================"
    echo "  安全加固完成！"
    echo "  备份目录：$BACKUP_DIR"
    echo "  报告文件：/tmp/security_hardening_report.txt"
    echo "  如需回滚：$0 --rollback"
    echo "========================================"
}

# 执行主函数
main "$@"
