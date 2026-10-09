# ADS7953单板UART教学工程

打开 `ADS7953_1Board_UART.qpf`。本工程固定1块ADS7953，50 MHz系统时钟，10 MHz SPI，串口115200/8-N-1。

## 阅读顺序

1. `rtl/ads7953_16ch_reader.v`：ADS7953 Auto-2初始化和16通道读取。
2. `rtl/ads7953_Nboard_uart_bridge.v`：接收`T`并封装统一数据帧；参数固定为1板。
3. `rtl/ads7953_1board_uart_top.v`：把读取器和串口桥连接起来。
4. `docs/通信帧格式.md`：上位机如何触发和解析。

引脚：CS=`B21`、SDO=`G17`、SDI=`H19`、SCLK=`J17`、UART RX/TX=`P16/P20`。

无板或SPI断线保护：单次触发最多发送32个SPI帧；仍未完成CH0～CH15时自动停止SCLK、返回空闲并清零本轮数据，避免状态机永久忙。

已编译的三种上位机位于`host/dist/`：主界面、全通道界面和示波器界面。需要重新生成时双击`host/一键生成上位机.cmd`。

`ADS7953_1Board_FreeRun_UART.exe`为单板固定周期触发版：默认每100 ms发送一次`T`、持续时间0表示一直发送，发送线程不等待FPGA反馈；接收、显示和导出功能保留。

`sim/`用于ModelSim；按需求，运行仿真前必须先取得用户许可。
