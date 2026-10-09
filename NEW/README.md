# ADS7953重新构造工程

本目录包含从单板教学版逐步扩展到1～20板的四个基础Quartus 13.1工程，以及一个N板UART滑轨联动派生工程。

| 工程 | 用途 | 板数 | 上位机通信 |
|---|---|---:|---|
| `ADS7953_1Board_UART` | 单板教学、理解SPI和帧封装 | 固定1 | 115200、8-N-1 |
| `ADS7953_1Board_NET` | 单板千兆网口验证 | 固定1 | UDP |
| `ADS7953_NBoard_UART` | 多板共用SPI、独立CS | 宏配置1～20 | 115200、8-N-1 |
| `ADS7953_NBoard_NET` | 多板共用SPI、千兆网口 | 宏配置1～20 | UDP |
| `ADS7953_NBoard_UART_SLIDE` | N板采集与PWM滑轨联动 | 宏配置1～20 | 115200、8-N-1 |

四个工程使用统一应用层数据帧，详见 [通信帧格式.md](通信帧格式.md)。每次修改记录在 [CHANGELOG.md](CHANGELOG.md)。

## 设计基线

- FPGA：Cyclone IV E `EP4CE30F23C8`，系统时钟50 MHz。
- ADS7953：Auto-2模式，依次读取CH0～CH15。
- SPI：单板UART、N板UART及SLIDE工程当前为1 MHz；单板NET和N板NET为准确10 MHz。
- 量程：`0～2×VREF`，本板VREF为2.5 V，对应0～5 V。
- 多板结构：SCLK、SDI、SDO共用，每块板独立CS，按板号顺序采集。
- 防死锁：每块板最多发送32个16位SPI帧；未获得完整CH0～CH15序列时自动停止SCLK并清零该板本轮数据。多板工程随后继续下一块板。

ADS7953允许最高20 MHz SCLK；SCLK高、低电平最短均为20 ns。本工程10 MHz的高电平40 ns、低电平60 ns满足要求。[来源: hardware/chip reference/ads7953.pdf, 7.3 Recommended Operating Conditions, p.10；7.9 Timing Requirements, p.17]

## ModelSim说明

仿真脚本随工程提供。根据需求，运行前已取得用户明确许可；单板UART、单板NET、N板UART的1板/20板、N板NET的2板/20板共六项均已PASS，详见[验证报告.md](验证报告.md)。后续若再次运行，仍应先取得用户许可。

## 直接使用

1. 用Quartus 13.1打开对应目录中的`.qpf`。
2. N板工程在`rtl/ads7953_board_count.vh`中把`ADS7953_BOARD_COUNT`改成实际板数，允许1～20，然后执行完整编译。
3. 下载`output_files/工程名.sof`到FPGA。
4. 在对应工程的`host/dist/`中运行需要的上位机。

`ADS7953_NBoard_UART`的五款上位机均识别CH0高字节bit7板级32字超时标志。主界面、FreeRun和Diagnostic把错误板16路标红；AllChannels标红对应全局IV行；Scope显示红色通道名和红色错误采样点；Excel同步记录状态。40字节帧长度及12位ADC解析保持不变。

每个工程提供三种上位机：

- 主界面：动态识别本轮实际收到的板数，并显示每板16通道。
- `AllChannels`：全部通道放在一页，板0对应IV0～IV15，板1对应IV16～IV31，依此类推；Excel也使用全局IV编号。
- `Scope`：勾选任意多个IV通道实时观察；NET版本支持横轴点数和纵轴上下限设置。

四个工程均提供`FreeRun`固定周期触发版：默认一直发送`T`且不等待FPGA返回，接收与显示线程独立运行。它适合连续抓SPI或验证长期采集；发送间隔应大于一次完整采集和传输所需时间，过密触发会在FPGA忙时被忽略。

如果需要重新打包，双击各工程`host/一键生成上位机.cmd`。

## 已完成验证

- 四个默认1板配置均通过Quartus 13.1完整编译，0 error。
- 两个N板工程均额外以20板宏通过完整编译和时序分析，再恢复默认1板重新编译。
- UART上位机每套4项、NET上位机每套6项单元测试全部通过。
- 四个工程各有主界面、全通道、示波器和FreeRun，共16个约13 MB的EXE均通过实际启动冒烟测试。
- 详细结果见[验证报告.md](验证报告.md)。
