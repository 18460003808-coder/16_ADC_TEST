# ADS7953 两板共用 SPI 验证工程

这是 20 板方案的第一阶段验证版本。两块 ADS7953 板共用 `SCLK`、`SDI`、三态 `SDO`，分别使用独立 `CS#`。FPGA 每次只拉低一个片选，完整读取该板 16 路后释放总线，再切换到下一块板。

## 目录

```text
fpga_2board/
├─ ads7953_2board.qpf/qsf       Quartus 工程
├─ constraints/                引脚和时序约束
├─ rtl/                        FPGA RTL
├─ sim/                        两板自检仿真
├─ host/                       Python 上位机
└─ docs/串口协议.md            串口帧定义
```

## 接线

FPGA 型号为 `EP4CE40F23C8`，下面的引脚已写入 Quartus 工程：

| 信号 | FPGA 引脚 | 连接方式 |
|---|---|---|
| `adc_cs_n[0]` | `PIN_B21` | 板 0 `CS#` |
| `adc_cs_n[1]` | `PIN_C20` | 板 1 `CS#` |
| `adc_sdo` | `PIN_H17` | 两板 `SDO` 并联 |
| `adc_sdi` | `PIN_H21` | 两板 `SDI` 并联 |
| `adc_sclk` | `PIN_J17` | 两板 `SCLK` 并联 |
| `clk` | `PIN_G1` | 50 MHz 时钟 |
| `rst_n` | `PIN_E4` | 低有效复位 |
| `uart_rxd` | `PIN_P16` | FPGA 接收 |
| `uart_txd` | `PIN_P20` | FPGA 发送 |

两块 ADC 板和 FPGA 必须共地，ADS7953 的 `+VBD` 应为 3.3 V。两块板的 SDO 只有在各自 CS 为低时才驱动总线；若板上还有缓冲器，应确认它也随片选进入高阻态。初次联调使用 1 MHz SCLK，板间留出至少 100 ns 的全 CS 高电平时间。

## FPGA 编译与下载

1. 用 Quartus 打开 `ads7953_2board.qpf`。
2. 执行完整编译并下载生成的 `.sof`。
3. 复位后等待 ADS7953 上电初始化完成。

逻辑收到串口字符 `T` 后执行：板 0 Auto-2 全通道扫描 → 释放全部 CS → 板 1 Auto-2 全通道扫描 → UART 返回两帧数据。每块板都会发送 `0x93C0`、`0x3C40`，随后用 `0x0000` 读取 16 路。

## 上位机

在 `host` 目录执行：

```powershell
python -m pip install -r requirements.txt
python ads7953_2board_gui.py
```

选择串口并连接，点击“采集两板”。界面显示两板各 16 路的原始码和 0～5 V 换算值，同时每次采集向 Excel 追加两行。默认文件为当前目录下的 `ADS7953_2Board_data.xlsx`。

需要反复抓取SignalTap波形时，在“连续触发间隔”中输入毫秒数（建议先用 `500`），点击“开始连续采集”。再次点击即可停止。连续模式默认不写Excel，避免长时间抓波形时文件持续增大；确实需要记录时再勾选“连续采集时写Excel”。SignalTap设置见 [docs/SignalTap抓取指南.md](docs/SignalTap抓取指南.md)。

已打包好的 Windows 程序位于 `host/dist/ADS7953_2Board.exe`，可直接双击运行；也可以按下面方式从源码重新打包。

如需打包 Windows 可执行文件：

```powershell
pyinstaller --noconfirm --clean ADS7953_2Board.spec
```

串口细节见 [docs/串口协议.md](docs/串口协议.md)。

## 仿真验收

已提供两个独立 ADC 行为模型，检查：

- 任意时刻不得同时拉低两个 CS；
- 两块板各返回 16 个通道；
- UART 返回板号 0、1，序号一致；
- 32 路数据内容和 XOR 校验均正确；
- 连续触发时序号递增且不会串板。

在 ModelSim/Questa 命令行执行：

```powershell
vsim -c -do "do sim/run.do; quit -f"
```

看到 `TEST PASS` 即通过。

## 20 板扩展边界

两板实物验证通过后再扩为 20 板：控制器把 2 位 CS 扩为 20 位并按板号循环，上位机等待同一序号的 20 个帧。共用 SDO 的信号完整性、扇出和总线高阻切换必须以两板示波器波形为依据；若直接并联 20 板不能满足边沿或电平要求，需要加分组缓冲/多路复用器，不能只靠修改 RTL。
