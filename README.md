# Linux Security Hardening

Windows与Linux服务器安全加固脚本设计与对比研究 - 课程论文配套脚本

## 脚本说明

### linux_hardening.sh
Linux端安全加固Bash脚本，功能包括：

1. **配置备份**：加固前自动备份sshd_config、UFW规则、login.defs、自动更新配置
2. **UFW防火墙配置**：默认拒绝入站、允许出站，开放22/80/443端口
3. **SSH安全加固**：禁用root登录、禁用密码认证、设置登录超时300秒、限制最大认证3次
4. **密码策略配置**：最小密码长度12位、最大有效期90天、过期前7天提醒
5. **自动安全更新**：启用unattended-upgrades每日自动更新安全补丁
6. **日志审计**：检查auth.log失败登录次数、sudo使用次数、日志轮转配置
7. **报告生成**：自动生成安全加固配置报告到/tmp/security_hardening_report.txt
8. **回滚功能**：支持--rollback参数一键恢复到加固前配置

**使用方法：**
```bash
sudo bash linux_hardening.sh
# 回滚配置
sudo bash linux_hardening.sh --rollback
```

### windows_security_check.ps1
Windows端安全配置检查PowerShell脚本，功能包括：

1. 防火墙状态查询（各配置文件状态、入站规则数量）
2. RDP远程桌面配置检查（是否启用、NLA、端口号）
3. 密码策略查询（net accounts）
4. Windows Update配置检查
5. 安全事件日志统计（失败登录次数）
6. Windows与Linux安全配置对比表输出

**使用方法：**
```powershell
# 以管理员身份运行PowerShell
.\windows_security_check.ps1
```

## 测试环境

- Linux: Ubuntu 22.04 LTS (VirtualBox虚拟机)
- Windows: Windows 11 本地主机

## 论文说明

本仓库为《Windows与Linux服务器安全加固脚本设计与对比研究》课程论文的配套代码仓库，脚本已在实际环境中运行验证。
