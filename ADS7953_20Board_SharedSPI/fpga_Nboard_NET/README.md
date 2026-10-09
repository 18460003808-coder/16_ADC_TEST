# ADS7953 N板千兆网口工程

本工程把 `fpga_Nboard` 的USB串口通信替换为UDP网口通信，ADS7953采集、板卡数量宏、自动识别板数、连续采集、采集时间、全通道显示、实时波形和Excel导出功能保持不变。

板载PHY为RTL8211EG，默认配置为GMII；千兆模式使用8位数据和125MHz时钟，接收时钟由PHY提供，发送时钟由FPGA提供。[来源: EP4CE30VER6.1D硬件用户手册.pdf, 12.千兆网络, p.22]

## 使用前提

- 电脑网卡和开发板必须协商到 `1.0 Gbps`。本工程未实现10/100Mbps MII切换。
- 建议电脑有线网卡设置为静态IPv4：`192.168.1.10`，掩码 `255.255.255.0`。
- Windows防火墙需允许上位机接收UDP端口 `5001`。
- 直连电脑或接入千兆交换机均可；FPGA接收广播触发，不依赖ARP。

电脑首次配置可双击 `scripts/配置电脑网口_双击运行.cmd`，在UAC窗口中点击“是”。脚本保留已有IPv4地址，增加 `192.168.1.10/24`，并放行入站UDP端口 `5001`。

## FPGA工程

Quartus 13.1工程：

```text
ads7953_Nboard_NET.qpf
```

目标器件为 `EP4CE30F23C8`。默认FPGA网络参数：

```text
MAC       02:00:00:00:79:53
IPv4      192.168.1.50
UDP端口   5000
```

板卡数量在 `rtl/ads7953_board_count.vh` 中设置：

```verilog
`define ADS7953_BOARD_COUNT 2
```

允许1～20，板卡连续安装为板0～板N-1。修改后重新完整编译并下载：

```text
output_files/ads7953_Nboard_NET.sof
```

目录中另附已验证的最大配置文件 `output_files/ads7953_Nboard_NET_20Board.sof`。

RTL8211EG的GMII数据、时钟、复位和MDIO/MDC引脚来自手册管脚表。[来源: EP4CE30VER6.1D硬件用户手册.pdf, 12.千兆网络, p.23]

## 上位机

打开上位机后：

1. “本机IP”建议填电脑有线网卡地址 `192.168.1.10`；也可保持 `0.0.0.0`。
2. “目标广播IP”保持 `192.168.1.255`。
3. 点击“打开网口”，然后单次采集或连续采集。

三款上位机启动后都会自动枚举 `192.168.1.x` 本机地址并广播查找FPGA。收到合法数据帧后，会自动填写本机IP、显示实际FPGA IP和板卡数量，并打开网口；也可点击“自动查找FPGA”重新扫描。手动IP输入和“打开网口”仍作为备用。

提供三个独立版本：

```text
host/dist/ADS7953_NBoard_NET.exe       分板查看
host/dist/ADS7953_AllChannels_NET.exe  全通道同页显示
host/dist/ADS7953_Scope_NET.exe        多通道实时波形
```

示波器版本的通道通过复选框勾选；“显示刻度”区域可设置横轴显示点数、横轴刻度间隔，以及纵轴最小值、最大值和刻度间隔。

网口负载沿用原有数据帧和结束帧，详细格式见 `docs/网口协议.md`。

## 仿真

```powershell
vsim -c -do "do sim/run_udp.do; quit -f"
```

仿真检查UDP触发解析、回复地址、N板应用数据、结束帧、IPv4校验和和Ethernet FCS。
`sim/run_udp_20.do` 用于验证20板最大配置。

## 已验证与限制

- 默认2板和最大20板均已在 `EP4CE30F23C8` 上完成布局布线；两种配置的时序余量均为正。
- 板卡手册没有给出FPGA与PHY之间的板级走线延时，因此SDC约束了50/125MHz及GMII接收时钟，但没有虚构外部I/O延时；最终仍需在实板上验证GMII收发裕量。
- 接收端面向本上位机生成的普通Ethernet II/IPv4/UDP广播包，不解析VLAN、IPv4选项或IP分片。
