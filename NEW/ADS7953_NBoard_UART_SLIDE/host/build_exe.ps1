$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$specs = @(
    'ADS7953_NBoard_AllChannels_UART.spec',
    'ADS7953_NBoard_Scope_UART.spec'
)
foreach ($spec in $specs) {
    pyinstaller --noconfirm --clean $spec
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed: $spec"
    }
}
