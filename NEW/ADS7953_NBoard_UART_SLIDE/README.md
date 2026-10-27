# ADS7953 N板UART + 滑轨联动工程

Quartus工程入口：`ADS7953_NBoard_UART_SLIDE.qpf`。

本工程以当前`NEW/ADS7953_NBoard_UART`为基线，保留1～20板共享SPI采集、动态板数结束帧、SPI错误标志、全通道显示和Excel导出，并增加2 kHz脉冲式滑轨控制。

## FPGA配置

- FPGA：EP4CE30F23C8，系统时钟50 MHz。
- ADC SCLK：1 MHz，与基线工程当前设置一致。
- 板数宏：`rtl/ads7953_board_count.vh`中的`ADS7953_BOARD_COUNT`，合法范围1～20，当前值20。
- 滑轨PWM：2 kHz、50%占空比，80个脉冲对应1 mm。
- `pwm_out`：PIN_A20。
- `dir`：PIN_A19；高电平为正向，低电平为反向。

修改板数宏后必须重新执行Quartus完整编译并下载新SOF。有效ADC/UART引脚继承自`NEW/ADS7953_NBoard_UART`的当前QSF叠加结果，没有从备份文件恢复旧设置。

## 上位机

正式程序：`host/dist/ADS7953_NBoard_AllChannels_UART_SLIDE.exe`；Scope程序：`host/dist/ADS7953_NBoard_Scope_UART.exe`。

两个上位机均从EXE同目录的`board_mapping.csv`自动读取“采集卡物理插口→实际逻辑子板”映射。配置使用1～20编号，必须是20个插口和20块子板的一一对应关系；缺失、重复或越界时禁止连接采集。映射应用于IV显示、错误标红、Scope曲线、普通/联动Excel和后续灰度成像，说明见`docs/板卡映射配置说明.md`。

macOS Apple Silicon M5版共用同一套Python源码，提供两个arm64 `.app`规格文件和`host/build_macos.sh`。需要发送到Mac的文件已单独整理在`macOS_M5_Package/`，复制该文件夹即可，不需要携带Windows EXE、FPGA工程或用户数据。Mac版首次启动会在`~/Library/Application Support/ADS7953_NBoard_UART_SLIDE/board_mapping.csv`生成映射文件，默认Excel目录为`~/Documents`。最终`.app`必须在Mac上构建，步骤见`docs/macOS版本使用与打包说明.md`。

串口参数固定为115200、8-N-1。界面保留原来的单次采集、连续采集、动态板数、IV0～IV319显示、异常板标红和纵向Excel导出，并增加：

1. 滑轨单独调试：选择正/反方向，输入0.5～300 mm后执行一次移动。
2. ADC与滑轨联动：设置每步0.5～2 mm、采集间隔500～5000 ms和次数N。
3. 滑轨运动期间状态灯为红色；收到FPGA硬件完成帧后变为绿色。
4. 联动顺序为“采集一次、正向移动一步”，重复N次；之后反向移动N步总距离复位。
5. 总复位脉冲超过65535时，上位机自动分段发送。
6. N次数据先保存在内存，滑轨复位完成后弹出“另存为”；每次联动新建一个独立Excel，由用户命名，不再追加到旧文件。每列标题包含实际采集时间、Seq和采集位置。
7. 灰度成像：选择已有或刚生成的纵向Excel，将320×N数据生成灰度预览；纵向为IV0～IV319，横向为N次采集。黑色电压默认0 V、白色电压默认5 V，均可修改，中间值线性映射，并可按需导出PNG。

灰度Excel采用顺序读取并在后台线程计算，处理期间GUI保持响应。生成后先显示预览，不会自动创建PNG；只有点击预览窗口中的“导出PNG”才选择性保存。`host/build_exe.ps1`只生成最终全通道滑轨版和保留的Scope版。

重新打包两个正式上位机并把外部映射文件复制到`host/dist`：

```powershell
cd host
powershell -ExecutionPolicy Bypass -File .\build_exe.ps1
```

## 安全与超时

- FPGA只在滑轨空闲时接受完整且校验正确的移动命令。
- 运动开始时锁存方向和脉冲数，运动期间后续命令不会改变本次输出。
- 上位机等待FPGA实际完成帧，不以软件延时冒充运动完成。
- 滑轨或采集应答超时后联动停止，界面提示人工确认当前位置；不会在位置未知时盲目继续运动。
- ADC每块板最多尝试32个SPI字，缺板不会导致SCLK永久运行。

协议见`docs/通信协议.md`，操作步骤见`docs/滑轨联动使用说明.md`，板卡接线映射见`docs/板卡映射配置说明.md`，Mac构建见`docs/macOS版本使用与打包说明.md`，所有Verilog文件的逐项实现见`docs/所有Verilog文件功能实现说明.md`。

## 验证状态

- Python单元测试：18项通过。
- GUI源码启动检查：通过。
- 正式EXE启动检查：通过。
- Quartus 13.1全流程编译：20板配置0 error，已生成SOF。
- ModelSim：本次未运行；按工程规则，每次运行前需重新取得用户许可。
- 实物滑轨：尚未由本次软件流程验证。

`sim/run_slide.do`用于滑轨脉冲数、方向锁存和忙时互锁仿真；`sim/run.do`及`sim/run_20.do`保留ADC链路回归。脚本已经准备，但本次没有执行。
