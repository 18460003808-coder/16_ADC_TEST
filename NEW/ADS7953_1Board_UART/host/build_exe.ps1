$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$exclude = @('--exclude-module', 'numpy', '--exclude-module', 'pandas', '--exclude-module', 'PIL', '--exclude-module', 'lxml')
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_1Board_UART ads7953_Nboard_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_1Board_AllChannels_UART ads7953_all_channels_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_1Board_Scope_UART ads7953_scope_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_1Board_FreeRun_UART ads7953_freerun_gui.py
