# ADS7953 N板UDP工程

打开 `ADS7953_NBoard_NET.qpf`。SCLK/SDI/SDO由所有板共用，每块板使用独立CS；网络侧使用RTL8211EG千兆GMII。

板数在 `rtl/ads7953_board_count.vh` 中设置：

```verilog
`define ADS7953_BOARD_COUNT 1
```

允许范围1～20；修改后重新完整编译。默认FPGA地址为`192.168.1.50:5000`，最大20板UDP负载808字节。

每块板最多尝试32个SPI帧。缺板、SDO悬空或通道序列错误时，该板自动停止并清零本轮数据，控制器继续下一块板，不会拖死整轮采集。

`host/dist/`内有主界面、全通道界面和示波器界面三种EXE。它们自动查找FPGA IP，并根据结束帧动态采用实际板数。需要重新生成时双击`host/一键生成上位机.cmd`。

`ADS7953_NBoard_FreeRun_NET.exe`是独立的固定周期触发版：默认每100 ms发送一次UDP触发`T`、持续时间0表示一直发送，发送线程不等待FPGA反馈；自动找IP、接收、显示和导出功能保留。FPGA忙时收到的额外触发会被忽略，不会排队。

`sim/run_udp.do`验证2板UDP，`sim/run_udp_20.do`验证20板最大负载。按需求，运行ModelSim前必须先取得用户许可。
