# ADS7953上位机macOS M5版本使用与打包说明

## 1. 支持范围

本工程已经为Apple Silicon M5（arm64）准备两款macOS应用：

- `ADS7953_NBoard_AllChannels_UART_SLIDE.app`
- `ADS7953_NBoard_Scope_UART.app`

功能与Windows正式版保持一致，包括UART采集、板卡映射、错误标红、Excel导出、Scope波形，以及AllChannels的滑轨联动和灰度成像。

FPGA RTL、UART通信帧和SOF不需要修改。macOS串口通常显示为`/dev/cu.usbserial-*`、`/dev/cu.SLAB_USBtoUART`或其他`/dev/cu.*`名称，上位机会通过PySerial自动枚举。

## 2. 为什么需要在Mac上打包

当前工程所在电脑是Windows，PyInstaller不能在Windows上生成可运行的macOS `.app`。源码、arm64规格文件和构建脚本已经准备好，但最终应用必须在M5 Mac上执行一次构建。

本工程未配置Apple Developer证书、Developer ID签名或公证，生成的是本机测试/内部使用版本，不是可直接发布到Mac App Store的版本。

## 3. Mac准备工作

1. 推荐只把工程根目录中的`macOS_M5_Package`文件夹整体复制到Mac；它已经包含两款上位机的全部构建必需文件，不需要复制Windows EXE、FPGA工程或用户Excel/PNG。
2. 安装Apple Silicon arm64版Python 3，并确认该Python包含Tkinter。
3. 打开“终端”，执行：

```bash
uname -m
python3 --version
python3 -c "import tkinter; print('Tkinter OK')"
```

`uname -m`应输出`arm64`。如果Tkinter导入失败，需要换用包含Tk支持的Python安装包。

## 4. 一键构建两个应用

在终端进入发送包目录，然后运行：

```bash
cd /你的路径/macOS_M5_Package
bash build_macos.sh
```

如果复制的是整个工程，也可以进入`ADS7953_NBoard_UART_SLIDE/host`执行同一条构建命令。

脚本会：

1. 创建独立虚拟环境`.venv_macos`。
2. 安装PySerial、OpenPyXL、Pillow和PyInstaller。
3. 按arm64架构分别打包AllChannels和Scope。
4. 把映射模板复制到输出目录。

生成结果：

```text
dist_macos/ADS7953_NBoard_AllChannels_UART_SLIDE.app
dist_macos/ADS7953_NBoard_Scope_UART.app
dist_macos/board_mapping_template.csv
```

首次构建需要联网下载Python依赖。以后可以继续执行同一脚本覆盖构建。

## 5. 首次运行

由于应用没有使用Apple Developer证书公证，首次打开时macOS可能阻止运行。建议：

1. 在Finder中找到`.app`。
2. 按住Control点击应用，选择“打开”。
3. 在系统确认框中再次选择“打开”。

不要把`.app`内部`Contents/MacOS`目录当作配置目录，也不要直接修改应用包内部文件。

## 6. Mac版板卡映射文件

Mac版首次启动时会自动生成：

```text
~/Library/Application Support/ADS7953_NBoard_UART_SLIDE/board_mapping.csv
```

Finder默认隐藏`Library`目录。可以在Finder中选择“前往→前往文件夹”，输入：

```text
~/Library/Application Support/ADS7953_NBoard_UART_SLIDE
```

配置格式仍为：

```csv
capture_slot,logical_board
1,1
2,2
3,3
...
20,20
```

修改后必须完全退出并重新启动应用。AllChannels和Scope共用同一个映射文件，因此两款程序的IV0～IV319顺序保持一致。

## 7. Excel和灰度图位置

Mac版默认把普通采集Excel放在：

```text
~/Documents
```

仍可通过上位机的“选择Excel”或“另存为”改到其他目录。滑轨联动Excel和灰度PNG也使用macOS原生文件选择窗口。

## 8. 串口连接

1. 用USB转串口连接FPGA。
2. 打开上位机并点击“刷新”。
3. 选择`/dev/cu.*`形式的端口，波特率仍为115200、8-N-1。
4. 如果列表没有串口，先在“系统信息→USB”确认设备是否识别，再根据USB转串口芯片型号检查是否需要macOS驱动。

优先选择`/dev/cu.*`，不要选择同名`/dev/tty.*`，前者更适合由Mac主动建立串口连接。

## 9. 当前验证边界

- Windows环境已完成Python语法检查、18项单元测试和两个GUI源码启动检查。
- macOS路径、首次生成映射文件和Documents输出目录已通过自动测试。
- 两份arm64 PyInstaller规格文件和构建脚本已经生成。
- 当前没有M5 Mac执行环境，因此尚未实际生成或启动`.app`，也没有进行Mac串口、Excel、滑轨或实物采集验证。
