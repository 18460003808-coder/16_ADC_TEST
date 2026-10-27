#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "错误：此脚本只能在macOS上运行。"
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "错误：此版本面向Apple Silicon arm64（M1及以后）。"
    exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR=".venv_macos"

"$PYTHON_BIN" -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install -r requirements-macos.txt

python -m PyInstaller --noconfirm --clean \
    --distpath dist_macos --workpath build_macos \
    ADS7953_NBoard_AllChannels_UART_macOS.spec
python -m PyInstaller --noconfirm --clean \
    --distpath dist_macos --workpath build_macos \
    ADS7953_NBoard_Scope_UART_macOS.spec

cp -f board_mapping.csv dist_macos/board_mapping_template.csv

echo
echo "构建完成："
echo "  dist_macos/ADS7953_NBoard_AllChannels_UART_SLIDE.app"
echo "  dist_macos/ADS7953_NBoard_Scope_UART.app"
echo
echo "首次运行会在以下位置生成实际映射文件："
echo "  ~/Library/Application Support/ADS7953_NBoard_UART_SLIDE/board_mapping.csv"
