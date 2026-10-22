# Windows Security Configuration Check Script
$ReportFile = "./windows_security_report.txt"

Write-Host "========================================"
Write-Host "  Windows Security Check Script"
Write-Host "========================================"
Write-Host ""

# 1. Firewall status
Write-Host "=== 1. Firewall Status ==="
$FirewallProfiles = Get-NetFirewallProfile -All
foreach ($profile in $FirewallProfiles) {
    Write-Host "Profile: $($profile.Name)"
    Write-Host "  Enabled: $($profile.Enabled)"
    Write-Host "  Default Inbound: $($profile.DefaultInboundAction)"
    Write-Host "  Default Outbound: $($profile.DefaultOutboundAction)"
    Write-Host ""
}

$AllowRules = Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True
Write-Host "Allowed inbound rules count: $($AllowRules.Count)"
Write-Host ""

# 2. RDP config
Write-Host "=== 2. Remote Desktop (RDP) ==="
$RDP = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
if ($RDP -eq 0) {
    Write-Host "RDP: Enabled"
} else {
    Write-Host "RDP: Disabled"
}

$NLA = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp").UserAuthentication
if ($NLA -eq 1) {
    Write-Host "NLA: Enabled"
} else {
    Write-Host "NLA: Disabled"
}

$RDPPort = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp").PortNumber
Write-Host "RDP Port: $RDPPort (default 3389)"
Write-Host ""

# 3. Password policy
Write-Host "=== 3. Password Policy ==="
$Accounts = net accounts
$Accounts | ForEach-Object { Write-Host $_ }
Write-Host ""

# 4. Windows Update
Write-Host "=== 4. Windows Update ==="
$AU = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -ErrorAction SilentlyContinue
if ($AU) {
    Write-Host "AUOptions: $($AU.AUOptions)"
} else {
    Write-Host "Using system default settings"
}
Write-Host ""

# 5. Security log
Write-Host "=== 5. Security Event Log ==="
$SecurityLog = Get-WinEvent -ListLog Security
Write-Host "Max size: $([math]::Round($SecurityLog.MaximumSizeInBytes/1MB, 2)) MB"
Write-Host "Record count: $($SecurityLog.RecordCount)"
Write-Host ""

$Yesterday = (Get-Date).AddDays(-1)
try {
    $FailedLogins = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=$Yesterday} -ErrorAction Stop
    Write-Host "Failed logins (24h, Event 4625): $($FailedLogins.Count)"
} catch {
    Write-Host "Failed logins (24h, Event 4625): 0"
}
Write-Host ""

# Comparison table
Write-Host "========================================"
Write-Host "  Windows vs Linux Security Comparison"
Write-Host "========================================"
Write-Host ""
Write-Host "| Item        | Windows                   | Linux                     |"
Write-Host "|-------------|---------------------------|---------------------------|"
Write-Host "| Firewall    | Windows Defender Firewall | UFW                       |"
Write-Host "| Remote      | RDP (3389)                | SSH (22)                  |"
Write-Host "| Password    | secpol.msc                | /etc/login.defs           |"
Write-Host "| Auto Update | Windows Update            | unattended-upgrades       |"
Write-Host "| Logging     | Event Viewer              | syslog/auth.log           |"
Write-Host ""

Write-Host "Done!"
