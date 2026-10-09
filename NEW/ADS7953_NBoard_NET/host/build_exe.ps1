$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$exclude = @('--exclude-module', 'numpy', '--exclude-module', 'pandas', '--exclude-module', 'PIL', '--exclude-module', 'lxml', '--exclude-module', 'serial')
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_NBoard_NET ads7953_Nboard_NET_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_NBoard_AllChannels_NET ads7953_all_channels_NET_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_NBoard_Scope_NET ads7953_scope_NET_gui.py
pyinstaller --noconfirm --clean --onefile --windowed @exclude --name ADS7953_NBoard_FreeRun_NET ads7953_freerun_NET_gui.py
