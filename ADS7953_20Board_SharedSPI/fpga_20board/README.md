# ADS7953 20板共用SPI工程

本工程控制20块ADS7953板卡。所有板共用 `SCLK`、`SDI` 和三态 `SDO`，每板使用独立低有效 `CS#`。一次串口触发后，FPGA按板号0～19依次完成16通道Auto-2扫描，再向上位机发送20个数据帧，共320路。

ADS7953的Auto-2模式会从CH0递增扫描到编程的末通道；本工程对每块板先发送 `0x93C0` 将末通道设为CH15，再发送 `0x3C40` 进入Range 2并从CH0重新开始。[来源: ads7953.pdf, 8.4.6 Operating in Auto-2 Mode, pp.38-41, Table 5/Table 6]

## 交付内容

```text
fpga_20board/
├─ ads7953_20board.qpf/qsf       Quartus 13.1工程
├─ constraints/                 20路CS及共用SPI引脚约束
├─ rtl/                         FPGA RTL
├─ sim/                         20个ADC模型的自检仿真
├─ host/                        Python源码和Windows上位机
├─ output_files/                已编译SOF
└─ docs/串口协议.md             20板帧协议
```

## FPGA与J11接线

| 板号 | J11 | FPGA管脚 | 板号 | J11 | FPGA管脚 |
|---:|---:|---|---:|---:|---|
| CS0 | 2 | PIN_B21 | CS10 | 22 | PIN_H20 |
| CS1 | 4 | PIN_C20 | CS11 | 24 | PIN_H22 |
| CS2 | 6 | PIN_C22 | CS12 | 26 | PIN_J18 |
| CS3 | 8 | PIN_D21 | CS13 | 28 | PIN_J22 |
| CS4 | 10 | PIN_E21 | CS14 | 30 | PIN_K18 |
| CS5 | 12 | PIN_F17 | CS15 | 32 | PIN_K21 |
| CS6 | 14 | PIN_F20 | CS16 | 34 | PIN_L21 |
| CS7 | 16 | PIN_F22 | CS17 | 36 | PIN_M19 |
| CS8 | 18 | PIN_G18 | CS18 | 38 | PIN_M21 |
| CS9 | 20 | PIN_H18 | CS19 | 39 | PIN_M22 |

| 共用信号 | J11 | FPGA管脚 |
|---|---:|---|
| SDO | 19 | PIN_G17 |
| SDI | 23 | PIN_H19 |
| SCLK | 25 | PIN_J17 |
| GND | 5 | GND |

系统时钟为PIN_G1（50 MHz），低有效复位为PIN_E4，UART RX/TX分别为PIN_P16/PIN_P20。

20块ADC板、级联底板和FPGA必须共地，数字接口为3.3 V。每根CS建议在底板端上拉到3.3 V；SCLK和SDI按硬件图通过74LVC244分为4组、每组驱动5块板。

## 总线安全和时序

- 任意时刻片选状态只能是“全部高”或“恰好一路低”。
- 切换板卡时先停止SCLK并释放当前CS，再保持全部CS高至少100 ns。
- 默认SCLK为1 MHz，优先用于整机联调；示波器确认最远板卡SCLK/SDI及FPGA端SDO后再提高频率。
- ADS7953每次转换使用16个SCLK，器件允许的SCLK上限为20 MHz。[来源: ads7953.pdf, 7.9 Timing Requirements, p.17]
- 3 V数字接口下，CS拉高后SDO进入高阻的最大延迟为21 ns，总线进入下一转换前要求至少40 ns静默时间；100 ns切换间隔覆盖这两个要求。[来源: ads7953.pdf, 7.9 Timing Requirements, p.17, td4/tq]

## 编译与下载

用Quartus 13.1打开 `ads7953_20board.qpf`，执行完整编译并下载：

```text
output_files/ads7953_20board.sof
```

顶层实体是 `ads7953_20board_hw_top`，目标器件为 `EP4CE40F23C8`。

## 上位机

可直接运行：

```text
host/dist/ADS7953_20Board.exe
```

也可从源码启动：

```powershell
cd host
python -m pip install -r requirements.txt
python ads7953_20board_gui.py
```

选择实际板卡数量（1～20）后连接串口。统一上位机兼容两板旧固件和支持动态板数的新20板固件；单次采集只等待所选板卡，也可设置触发间隔和采集持续时间进行连续采集。界面通过板号下拉框查看任意一块已选板卡的16路数据，Excel每次追加N行。协议详见 [docs/串口协议.md](docs/串口协议.md)。

## ModelSim验证

```powershell
vsim -c -do "do sim/run.do; quit -f"
```

仿真包含20个独立ADS7953模型，并验证默认20板、配置2板和配置7板采集。检查项目包括：

- 20路CS从不同时出现两路低电平；
- 每块板恰好得到16个通道；
- 每次只返回板号0～N-1共N帧；
- 同组序号一致、下一组序号递增；
- 320路数值和每帧XOR校验正确。

## 上板建议

先按2板、5板、10板、20板逐步增加负载。20板全部接入时重点测量最远插槽SCLK/SDI边沿、FPGA端SDO电平和板卡切换后的高阻间隔。RTL仿真能够证明片选逻辑互斥，但不能替代20节点共用总线的信号完整性测试。
