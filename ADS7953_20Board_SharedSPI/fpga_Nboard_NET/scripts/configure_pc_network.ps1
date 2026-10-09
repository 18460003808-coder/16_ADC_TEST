param(
    [string]$InterfaceAlias = '以太网'
)

$ErrorActionPreference = 'Stop'
$resultPath = Join-Path $PSScriptRoot 'configure_pc_network_result.txt'
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
                 "-InterfaceAlias `"$InterfaceAlias`""
    try {
        $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs `
            -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
        exit $elevated.ExitCode
    } catch {
        Set-Content -LiteralPath $resultPath `
            -Value '配置失败：管理员授权被取消或当前会话无法显示UAC。' `
            -Encoding UTF8
        exit 1
    }
}

try {
    $adapter = Get-NetAdapter -Name $InterfaceAlias
    if ($adapter.Status -ne 'Up') {
        throw "网卡 $InterfaceAlias 当前未连接。"
    }

    $address = Get-NetIPAddress -InterfaceAlias $InterfaceAlias `
        -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -eq '192.168.1.10'
    if (-not $address) {
        New-NetIPAddress -InterfaceAlias $InterfaceAlias `
            -IPAddress '192.168.1.10' -PrefixLength 24 | Out-Null
    }

    $ruleName = 'ADS7953 FPGA UDP 5001'
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule) {
        Set-NetFirewallRule -DisplayName $ruleName -Enabled True -Action Allow | Out-Null
    } else {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound `
            -Action Allow -Protocol UDP -LocalPort 5001 -Profile Any `
            -RemoteAddress LocalSubnet | Out-Null
    }

    $message = "配置完成：$InterfaceAlias = 192.168.1.10/24，UDP 5001 已放行。"
    Set-Content -LiteralPath $resultPath -Value $message -Encoding UTF8
    Write-Output $message
    exit 0
} catch {
    $message = "配置失败：$($_.Exception.Message)"
    Set-Content -LiteralPath $resultPath -Value $message -Encoding UTF8
    Write-Error $message
    exit 1
}
