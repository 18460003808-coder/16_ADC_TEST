# ADS7953 × 20 共用SPI总线工程

本目录包含两套可独立打开、编译和运行的工程：

- [fpga_2board/README.md](fpga_2board/README.md)：两块板卡验证版
- [fpga_20board/README.md](fpga_20board/README.md)：20块板卡正式版，含FPGA、仿真、上位机和已编译文件

总体硬件资料：

- [docs/hardware_connection.svg](docs/hardware_connection.svg)：20板连接框图
- [docs/连接与器件建议.md](docs/连接与器件建议.md)：总线、缓冲器、上拉/下拉和上板步骤
- [SCH_Schematic1_2026-09-07.pdf](SCH_Schematic1_2026-09-07.pdf)：级联底板原理图

20板正式版保持与两板验证版相同的串口协议。一次触发依次采集板0～板19，每板16路，共320路。
