@echo off
chcp 65001 >nul
echo 正在请求管理员权限配置 ADS7953 网口...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_pc_network.ps1"
if errorlevel 1 (
    echo 配置没有完成，请确认已在 UAC 窗口中点击“是”。
) else (
    type "%~dp0configure_pc_network_result.txt"
)
pause
