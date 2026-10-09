# ADS7953单板UDP教学工程

打开 `ADS7953_1Board_NET.qpf`。本工程固定1块ADS7953，ADC SPI为10 MHz，网口固定千兆GMII。

## 阅读顺序

1. `rtl/ads7953_16ch_reader.v`：ADS7953读取。
2. `rtl/ads7953_udp_gmii.v`：解析UDP触发并发送以太网帧。
3. `rtl/ads7953_1board_net_top.v`：单板读取器、PLL和UDP端点连接。
4. `docs/通信帧格式.md`：上位机与FPGA通信格式。

默认FPGA地址为`192.168.1.50:5000`，上位机广播触发并从UDP 5001接收。

无板或SPI断线保护：单次触发最多发送32个SPI帧；仍未完成CH0～CH15时自动停止SCLK、返回空闲并清零本轮数据，避免状态机永久忙。

已编译的三种上位机位于`host/dist/`：主界面、全通道界面和示波器界面；均保留自动查找FPGA IP功能。需要重新生成时双击`host/一键生成上位机.cmd`。

`ADS7953_1Board_FreeRun_NET.exe`为单板固定周期触发版：默认每100 ms发送一次UDP触发`T`、持续时间0表示一直发送，发送线程不等待FPGA反馈；自动找IP、接收、显示和导出功能保留。

`sim/`用于ModelSim；按需求，运行仿真前必须先取得用户许可。
