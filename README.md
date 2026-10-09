# ADS7953 工作目录

本目录只保留一个完整 FPGA 工程和一个独立硬件设计，根目录下原有的重复工程已经删除。

## 保留内容

| 路径 | 说明 |
|---|---|
| `ADS7953_0-5V/` | 唯一保留的 ADS7953 0～5 V 完整工程，包含 Quartus、RTL、仿真、上位机、数据手册及下载文件 |
| `hardware/ADS7953_20Board_SharedSPI/` | 20 块 ADS7953 板卡共享 SPI 的独立硬件设计 |

## 常用入口

- Quartus 工程：`ADS7953_0-5V/ads7953_16ch.qpf`
- RTL 源码：`ADS7953_0-5V/rtl/`
- ModelSim 脚本：`ADS7953_0-5V/sim/run.do`
- 上位机：`ADS7953_0-5V/host/ads7953_serial_gui.py`
- FPGA 下载文件：`ADS7953_0-5V/output_files/ads7953_16ch.sof`
- EPCS64 烧录文件：`ADS7953_0-5V/output_file.jic`
- [ADS7953 芯片详细使用手册](ADS7953_0-5V/docs/ADS7953芯片使用手册.md)
- [20 板共享 SPI 方案](hardware/ADS7953_20Board_SharedSPI/README.md)

Quartus 的 `db/`、`incremental_db/`、`.qws`，ModelSim 的 `work/`、`vsim.wlf`，以及编译报告均属于可再生成内容，已清理并通过根目录 `.gitignore` 排除。

