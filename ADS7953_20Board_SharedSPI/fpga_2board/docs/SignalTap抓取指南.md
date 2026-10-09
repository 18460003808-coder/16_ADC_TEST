# 两板工程SignalTap II抓取指南

## 推荐配置

1. 用Quartus打开 `ads7953_2board.qpf`。
2. 打开已经配置好的 `stp2.stp`，不要再新建STP文件。
3. Acquisition Clock已经设为顶层 `clk`，即50 MHz连续系统时钟。
4. Sample Depth已经设为 `64K`，一次可记录约1.31 ms。
5. 已加入以下信号：

```text
uart_rxd
uart_txd
adc_cs_n[0]
adc_cs_n[1]
adc_sclk
adc_sdi
adc_sdo
```

6. 在Setup页确认 `uart_rxd` 的Trigger显示为Low（或Falling Edge），其余信号为Don't Care。Quartus 13.1若仍显示Don't Care，右键该单元格重新选择一次并保存；触发条件是运行时设置，不需要重新编译SOF。
7. 下载 `output_files/ads7953_2board.sof`；该文件已经包含SignalTap实例。
8. 在SignalTap中选择USB-Blaster和目标器件，点击 `Run Analysis` 等待触发。
9. 打开两板上位机，把连续触发间隔设为 `500 ms`，点击“开始连续采集”。

## 正常波形

- CS0先出现一组SPI帧，完成后CS1再出现一组SPI帧；不得同时为低。
- 每个CS低电平窗口包含16个SCLK。
- SCLK空闲为低，逻辑分析仪按SPI Mode 0、MSB First、16 bit解码。
- 每块板的SDI第一帧应为 `0x93C0`，第二帧应为 `0x3C40`，后续帧为 `0x0000`。
- 有效SDO字的高4位应按通道号 `0,1,...,15` 递增，低12位为转换结果。

## 根据波形定位

| 现象 | 优先检查 |
|---|---|
| UART RX没有低脉冲 | 串口号、TX/RX方向、PIN_P16、波特率115200 |
| UART RX有数据但CS0始终高 | 下载的SOF、复位PIN_E4、50 MHz时钟PIN_G1 |
| CS0反复扫描但始终不到CS1 | 板0 SDO、供电、共地、通道号返回是否正常 |
| CS0完成且CS1持续扫描 | 板1 SDO或板1片选接线 |
| 两板SPI都完成但无界面结果 | UART TX PIN_P20、帧头及校验 |
| SDO始终为0 | ADS7953数字供电、SDO接线、CS是否真正到达芯片 |

如果64K深度因器件RAM不足无法编译，先去掉 `uart_txd` 和 `uart_rxd`，仅保留5根SPI/CS信号；仍不足时改为32K并只观察单块板。
