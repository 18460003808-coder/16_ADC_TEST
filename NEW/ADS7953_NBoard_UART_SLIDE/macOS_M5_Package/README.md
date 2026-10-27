# ADS7953 macOS M5上位机发送包

此文件夹可整体复制到Apple Silicon M5 Mac，用于生成以下两个应用：

- `ADS7953_NBoard_AllChannels_UART_SLIDE.app`
- `ADS7953_NBoard_Scope_UART.app`

两款应用保留Windows版的UART采集、动态板数、外部板卡映射、错误标红和Excel导出；AllChannels还包含滑轨联动及灰度图预览/PNG导出，Scope保留多通道实时波形显示。

## 1. Mac准备

安装Apple Silicon arm64版Python 3，并确认包含Tkinter。打开“终端”执行：

```bash
uname -m
python3 --version
python3 -c "import tkinter; print('Tkinter OK')"
```

`uname -m`应输出`arm64`。

## 2. 构建

在终端进入本文件夹。例如把文件夹放在桌面后执行：

```bash
cd ~/Desktop/macOS_M5_Package
bash build_macos.sh
```

首次构建需要联网下载Python依赖。脚本会建立独立的`.venv_macos`虚拟环境，并生成：

```text
dist_macos/ADS7953_NBoard_AllChannels_UART_SLIDE.app
dist_macos/ADS7953_NBoard_Scope_UART.app
dist_macos/board_mapping_template.csv
```

## 3. 首次打开

应用未配置Apple Developer签名和公证。首次运行若被macOS拦截，请在Finder中按住Control点击应用，选择“打开”，再在确认框中选择“打开”。

## 4. 板卡映射

两款应用共用以下实际配置文件：

```text
~/Library/Application Support/ADS7953_NBoard_UART_SLIDE/board_mapping.csv
```

首次启动会自动创建1～20板恒等映射。要校准物理插口和实际子板，请修改上述文件并完全退出、重新打开应用。本发送包中的`board_mapping.csv`及输出的`board_mapping_template.csv`只是模板，应用运行时不直接读取发送包中的模板。

## 5. 串口和输出文件

- 串口参数仍为115200、8-N-1。
- Mac串口通常显示为`/dev/cu.*`，建议选择该名称，不选择同名`/dev/tty.*`。
- 普通采集Excel默认保存在`~/Documents`，也可在界面中另选路径。
- FPGA RTL、UART通信帧、引脚和SOF均不需要因Mac上位机而修改。

## 6. 验证边界

源码已在Windows完成语法检查、18项单元测试和两款GUI回归，但Windows不能生成或运行macOS `.app`。在正式使用前，仍需在M5 Mac上验证应用启动、USB转串口驱动、实际串口收发、Excel/PNG以及滑轨联动。
