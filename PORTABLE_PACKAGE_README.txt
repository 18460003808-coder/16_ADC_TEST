ADS7953 Codex便携工程包
生成日期：2026-09-27

在另一台设备上的使用方法：

1. 把ZIP完整解压到一个可写目录，不要只在压缩包预览器中打开。
2. 用Codex打开解压后的工程根目录。
3. 首先让Codex读取AGENTS.md和CODEX_HANDOFF.md。
4. 再根据任务读取NEW/每种工程完整通信流程.txt和对应工程README/docs。
5. 编译前确认所选工程、ADS7953_BOARD_COUNT宏、活动RTL中的SCLK值和管脚约束。

包内保留：

- FPGA RTL、QPF/QSF、时序及管脚约束；
- 仿真源文件和运行脚本；
- 上位机Python源码、测试、spec和已生成EXE；
- Quartus output_files中的SOF等交付文件；
- ADS7953及FPGA硬件PDF资料；
- 工程说明、通信协议、验证记录和Codex交接上下文；
- 早期2板、20板、N板UART和N板NET工程，以及N板UART归档fpga_Nboard.zip。

为减小体积，包内不包含：

- NPWM_DAC（明确不属于本任务范围）；
- Quartus db和incremental_db缓存；
- PyInstaller build缓存；
- Python __pycache__和pytest缓存；
- ModelSim work、transcript和vsim.wlf；
- Quartus个人工作区.qws；
- 与现场目录重复的旧fpga_Nboard_NET.zip。

这些排除项均可由源码重新生成，不影响打开工程、重新编译、重新仿真或重新打包上位机。

重要限制：每次运行ModelSim前仍需取得用户当次明确许可。
