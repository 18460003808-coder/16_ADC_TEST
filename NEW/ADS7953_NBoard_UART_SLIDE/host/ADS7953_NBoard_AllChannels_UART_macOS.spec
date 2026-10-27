# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ['ads7953_all_channels_gui.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['numpy', 'pandas', 'lxml'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='ADS7953_NBoard_AllChannels_UART_SLIDE',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='ADS7953_NBoard_AllChannels_UART_SLIDE.app',
    icon=None,
    bundle_identifier='cn.ads7953.nboard.allchannels.slide',
)
