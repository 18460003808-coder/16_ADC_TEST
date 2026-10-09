# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['ads7953_all_channels_gui.py'],
    pathex=[], binaries=[], datas=[], hiddenimports=[], hookspath=[],
    hooksconfig={}, runtime_hooks=[], excludes=['numpy', 'pandas', 'PIL', 'lxml'],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, a.binaries, a.datas, [],
    name='ADS7953_AllChannels', debug=False, bootloader_ignore_signals=False,
    strip=False, upx=True, console=False,
)
