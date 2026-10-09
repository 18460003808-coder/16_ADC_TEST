# ADS7953 N板共用SPI工程

本工程支持1～20块ADS7953板卡，FPGA编译时决定板卡数量，上位机根据FPGA返回的结束帧自动识别实际数量。使用的板卡必须连续安装在板0～板N-1。

## 设置FPGA板卡数量

编辑 `rtl/ads7953_board_count.vh`：

```verilog
`define ADS7953_BOARD_COUNT 2
```

数值允许为1～20。修改后必须重新完整编译并下载新的SOF；上位机无需修改或选择数量。

## 编译与下载

用Quartus 13.1打开 `ads7953_Nboard.qpf`，执行完整编译，下载：

```text
output_files/ads7953_Nboard.sof
```

目标器件为EP4CE40F23C8。共用SPI管脚为：

| 信号 | FPGA管脚 |
|---|---|
| SDO | PIN_G17 |
| SDI | PIN_H19 |
| SCLK | PIN_J17 |

CS0～CS19的定义见 `constraints/ads7953_Nboard_pins.qsf`。

## 上位机

提供三种上位机：

```text
host/dist/ADS7953_NBoard.exe       分板查看版
host/dist/ADS7953_AllChannels.exe  全通道同页版
host/dist/ADS7953_Scope.exe        实时波形版
```

点击采集后，上位机等待FPGA返回N个数据帧和一个结束帧，然后自动识别板卡数量。连续触发、触发间隔、采集时长和Excel导出功能均保留。

全通道同页版使用连续接口编号：板0为IV0～IV15，板1为IV16～IV31，以此类推。Excel每次采集保存为一行，各接口也是相同的连续编号。

实时波形版支持多选接口，按0～5V量程显示最近200次采集的滚动曲线；Excel使用长表格式记录当前选中的接口，因此运行期间可以更改通道选择。

## 仿真

默认宏（当前为2板）：

```powershell
vsim -c -do "do sim/run.do; quit -f"
```

7板覆盖测试：

```powershell
vsim -c -do "do sim/run_7.do; quit -f"
```

两项测试都会检查CS互斥、每板16通道、数据帧、校验和结束帧。

## 目录

```text
fpga_Nboard/
├─ rtl/            FPGA源码和板数宏
├─ constraints/    管脚与时序约束
├─ sim/            2板和7板仿真
├─ host/           自动识别板数的上位机
├─ docs/           串口协议
└─ output_files/   编译生成的SOF
```
