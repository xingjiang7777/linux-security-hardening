# Windows安全加固脚本
Write-Host "=== 加固前基线检查 ==="

Write-Host "`n[防火墙状态]"
netsh advfirewall show allprofiles state

Write-Host "`n[RDP状态]"
reg query "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections

Write-Host "`n[密码策略]"
net accounts

Write-Host "`n=== 开始加固 ==="

Write-Host "`n[1] 启用防火墙"
netsh advfirewall set allprofiles state on

Write-Host "`n[2] 默认入站阻止，出站允许"
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

Write-Host "`n[3] 启用RDP的NLA"
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f

Write-Host "`n[4] 密码策略：最小12位，90天过期"
net accounts /minpwlen:12 /maxpwage:90

Write-Host "`n=== 加固后验证 ==="

Write-Host "`n[加固后防火墙]"
netsh advfirewall show allprofiles state

Write-Host "`n[加固后密码策略]"
net accounts

Write-Host "`n完成"