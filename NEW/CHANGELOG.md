# 修改日志

## 2026-10-08：补充SLIDE工程全部Verilog实现说明

- 新增`ADS7953_NBoard_UART_SLIDE/docs/所有Verilog文件功能实现说明.md`，逐个说明7个综合`.v`文件和2个仿真`.v`文件。
- 文档覆盖模块接口、状态机、SPI顺序重同步、32字超时、板级错误标志、UART组帧、滑轨脉冲以及testbench覆盖边界。
- 本次仅增加文档和README入口，没有修改RTL、约束、上位机、SOF或EXE，也没有运行ModelSim。

## 2026-10-08：SLIDE最终版整理与文档同步

- `ADS7953_NBoard_UART_SLIDE`仅保留正式AllChannels滑轨版和Scope版上位机；此前的`_FIXED`、`_PREVIEW`只是构建过程文件，不再作为现行程序。
- 最终AllChannels文件统一为`host/dist/ADS7953_NBoard_AllChannels_UART_SLIDE.exe`；用户的Excel和PNG数据文件全部保留。
- 删除与`docs/通信协议.md`重复且含UDP内容的`docs/通信帧格式.md`，并按实际SLIDE RTL重写模块调用与控制框图。
- README、初始工程说明、UART协议、滑轨联动说明均已同步到当前0.5～300 mm单独调试、0.5～2 mm联动、新Excel命名保存和灰度预览/选择性导出流程。
- 本次仅整理文件名与文档，没有修改FPGA RTL、上位机源码、通信协议字段或SOF。

## 2026-10-08：灰度图改为先预览、选择性导出

- “生成灰度图”完成后直接显示预览，不再强制先选择PNG文件名。
- 预览窗口新增“导出PNG”和“关闭预览”；关闭预览不会生成图片文件，取消导出时预览继续保留。
- 保留后台顺序读取、可调黑白电压和N×320原始PNG尺寸。
- 因旧上位机仍可能运行，另行生成`ADS7953_NBoard_AllChannels_UART_SLIDE_PREVIEW.exe`。


## 2026-10-08：修复灰度成像界面未响应

- 根因是`read_only=True`工作簿配合数万次`sheet.cell()`随机访问，并且整个过程运行在Tk主线程。
- 改为`iter_rows(values_only=True)`一次顺序扫描，Excel读取和灰度计算移到守护线程，主线程仅处理保存对话框和预览。
- 实测`host/dist/1.xlsx`的320×100数据从超过30秒仍未完成降至0.139秒。
- 18项Python测试和GUI源码启动检查通过。因用户正在运行旧EXE，本次未强制关闭，另行生成`ADS7953_NBoard_AllChannels_UART_SLIDE_FIXED.exe`。


## 2026-10-08：SLIDE上位机增加320×N灰度成像

- AllChannels界面增加灰度成像区，可选择已有纵向Excel；刚生成的普通采集或联动Excel会自动成为数据源。
- A列IV0～IV319映射为图像320行，B列以后N次采集映射为N列，输出原始尺寸N×320的8位灰度PNG并显示放大预览。
- 黑色阈值默认0 V、白色阈值默认5 V，均可修改；中间数据线性映射，越界截断，空白单元格按最小值显示为黑。
- 新增Pillow运行依赖并重新生成正式EXE；FPGA RTL、通信协议和SOF未改动。


## 2026-10-08：SLIDE联动每次新建并命名Excel

- 联动采集不再追加到“选择Excel”所指向的旧文件；普通单次采集和连续采集行为不变。
- 滑轨反向复位完成后弹出“另存为”，每次联动由用户命名并新建独立工作簿。
- Excel保持A列IV0～IV319、每轮一列、错误板标红；列标题改用真实采集时刻并保留Seq和位置。
- 取消命名或保存失败时数据继续保存在内存，按钮变为“保存联动数据”，可再次保存且不能开始下一轮。
- 重新生成`ADS7953_NBoard_AllChannels_UART_SLIDE.exe`；FPGA RTL、协议和SOF未改动。


## 2026-10-08：SLIDE单独调试距离扩展到300 mm

- 仅将`ADS7953_NBoard_UART_SLIDE`上位机的“滑轨单独调试”范围由0.5～30 mm改为0.5～300 mm。
- ADC与滑轨联动的每步范围仍为0.5～2 mm，没有修改FPGA RTL、通信帧或SOF。
- 300 mm换算为24000个PWM，预计运动约12秒，仍在16位脉冲数字段范围内。
- 重新生成`ADS7953_NBoard_AllChannels_UART_SLIDE.exe`。


## 2026-10-08：SLIDE单独调试距离扩展到30 mm

- 仅将`ADS7953_NBoard_UART_SLIDE`上位机的“滑轨单独调试”范围由0.5～2 mm改为0.5～30 mm。
- ADC与滑轨联动的每步范围仍为0.5～2 mm，没有修改FPGA RTL、通信帧或SOF。
- 30 mm换算为2400个PWM，在现有16位脉冲数字段范围内。
- 重新生成并启动检查`ADS7953_NBoard_AllChannels_UART_SLIDE.exe`。


## 2026-10-08：新增N板UART滑轨联动工程

- 建立`ADS7953_NBoard_UART_SLIDE`完整工程，基于当前N板UART有效引脚、20板宏和1 MHz ADC SCLK。
- 新增2 kHz滑轨模块：方向和脉冲数启动锁存、忙时拒绝重触发、完成脉冲；`pwm_out=PIN_A20`、`dir=PIN_A19`。
- 增加7字节滑轨移动命令和9字节硬件完成帧；ADC采集与滑轨运动在FPGA侧互斥。
- AllChannels上位机增加滑轨单独调试和“采集N次/正向N步/反向N步复位”联动，运动状态灯由实际完成帧控制。
- 联动完成并复位后自动追加Excel；列标题增加位置，总复位脉冲超过65535时自动分段。
- 生成SLIDE版SOF和`ADS7953_NBoard_AllChannels_UART_SLIDE.exe`，补齐协议、操作说明及未运行的ModelSim脚本。


## 2026-10-06：AllChannels纵向通道导出

- `ADS7953_NBoard_AllChannels_UART`导出改为A列固定IV0～IV319，每次采集新增一个时间列。
- 列标题包含毫秒时间戳和采集Seq；错误板对应16个数据单元格标红，未配置板通道留空。
- 已有旧版横向工作簿不会被改写，程序在其中新增“纵向通道数据”工作表。
- 重新生成AllChannels正式EXE；其余四款上位机和FPGA未改动。

## 2026-10-06：N板UART读取诊断上位机

- 仅在`NEW/ADS7953_NBoard_UART`增加板级SPI扫描成功状态；达到32字仍未完成CH0～CH15时置为错误。
- 使用CH0高字节Byte8的bit7携带错误标志，40字节帧长度和12位ADC解析保持不变，现有上位机兼容。
- 新增`ADS7953_NBoard_Diagnostic_UART`上位机：错误板16路标红，状态栏报告板号，Excel增加读取状态并标红错误行。
- 未运行ModelSim；按项目要求，任何新仿真仍需单独取得用户许可。

## 2026-10-06：N板UART全部上位机错误显示

- 主界面、AllChannels、Scope和FreeRun全部接入Byte8 bit7读取错误标志，Diagnostic保持相同行为。
- 主界面/FreeRun/Diagnostic按板标红16路；AllChannels按错误板标红全局IV行；Scope用红色通道名和红色采样点标记异常。
- 五款上位机的Excel导出均增加读取状态或异常板号，错误数据使用红色格式；已有旧格式工作簿会自动插入状态列。
- 修正`build_exe.ps1`，直接使用已维护的五个`.spec`文件，避免尝试覆盖只读spec导致打包失败。

## 2026-10-06：记录Quartus GUI引脚基准

- 用户指定`ADS7953_NBoard_UART`工程当前有效引脚为以后所有ADS7953工程的统一基准。
- 确认GUI修改保存在主QSF中，并位于`source constraints/pins.qsf`之后，覆盖CS1～CS19。
- 新增`引脚约束基准.md`，记录解析后的有效映射和两份QSF的SHA-256。
- 本次没有改动任何引脚约束、没有同步其他工程，也没有重新编译。

## 2026-09-27：首次重新构造

- 根据`需求.txt`确定“1板教学工程 + 宏配置1～20板N板工程”的结构。
- 同时建立UART与千兆UDP两种传输版本，共四个独立工程目录。
- 统一UART/UDP应用层协议：40字节数据帧、8字节结束帧、版本号、采集序号和XOR校验。
- 单板工程使用一个标量CS，直接连接一个ADS7953读取器，便于教学。
- N板工程使用共享SCLK/SDI/SDO和20路独立CS；`ADS7953_BOARD_COUNT`宏默认1，可配置1～20。
- 四个工程统一目标器件为`EP4CE30F23C8`。
- 将ADC SCLK重构为准确10 MHz：50 MHz时钟下高电平2拍、低电平3拍。
- 创建Quartus `.qpf/.qsf`、引脚约束、时序约束、协议文档和工程总README。
- ModelSim脚本仅准备，不运行；运行前必须再次获得用户许可。

## 2026-09-27：补齐验证与上位机打包入口

- 补齐单板NET工程的10 MHz SPI读取器测试平台。
- 四个工程均增加`host/build_exe.ps1`，每个工程可分别生成主界面、全通道界面和示波器界面三种上位机。
- 保持N板上位机按结束帧中的实际板数动态显示，不要求用户手工写死板数。

## 2026-09-27：编译、20板和EXE验证

- 四个工程通过Quartus 13.1完整编译，均为0 error并生成`.sof`。
- 两个N板工程临时设置20板并通过完整编译与时序分析，随后恢复默认1板并重新编译。
- 四套上位机单元测试全部通过；生成主界面、全通道、示波器共12个EXE。
- 排除无关打包依赖，EXE体积约13 MB；12个EXE均完成启动冒烟测试。
- 增加一键打包入口、20板UART ModelSim脚本和`验证报告.md`。
- 将N板UART测试平台的SPI参数同步为本工程实际使用的10 MHz。

## 2026-09-27：ModelSim逐项验证

- 经用户明确许可，运行`ADS7953_1Board_UART/sim/run.do`。
- 结果PASS，仿真时间34851 ns；单板16通道扫描和10 MHz SCLK高/低时间检查通过。
- 经用户“全部仿真允许”的明确许可，运行其余五项ModelSim脚本。
- 单板NET、N板UART默认1板与20板、N板NET 2板与20板测试均PASS；最大配置验证覆盖20路CS隔离、UART完整帧及808字节UDP应用负载/FCS。
- 仿真结束后清理可自动重建的ModelSim `work/transcript/wlf`和PyInstaller `build`缓存，保留源代码、脚本、Quartus输出、spec与最终EXE。

## 2026-09-27：新增不等待反馈的连续触发上位机

- 确认现有连续发送线程与接收线程相互独立，发送动作不依赖FPGA返回帧。
- N板UART与N板NET各新增一个`FreeRun`入口，默认间隔100 ms、持续时间0（不限时）。
- 明确显示“固定周期发送T、不等待FPGA反馈”，保留动态板数、数据显示和导出功能。
- FPGA端保持原设计：仅空闲时接受触发，忙时触发忽略且不排队，因此无需修改RTL。
- UART 5项、NET 7项单元测试全部通过；两个FreeRun EXE均完成打包和启动冒烟测试，体积约13 MB。

## 2026-09-27：单板工程增加FreeRun

- 按用户要求，单板UART与单板NET工程各增加一个不等待FPGA反馈的FreeRun入口。
- 默认触发间隔100 ms、持续时间0（不限时），保留接收、显示、动态帧解析和Excel导出。
- 四个工程的一键打包脚本现在都会生成对应FreeRun EXE。
- 单板UART 5项、单板NET 7项测试全部通过；两个新增EXE完成打包和启动冒烟测试，并清理打包缓存。

## 2026-09-27：无板和SPI异常防死锁

- 修复一次触发后因SDO悬空、始终无法收到CH0～CH15而永久输出SCLK的问题。
- 四个读取器增加32帧硬上限；超限后停止SCLK、释放CS、清零本轮数据并返回完成。
- N板控制器可继续后续板卡，缺板不会锁死全部采集。
- 单板UART/NET测试平台增加“断开ADC、SDO固定0”的回归场景。
- 四个Quartus工程重新完整编译，均为0 error；新的ModelSim测试等待用户许可。
- 检查发现N板UART顶层当前为1 MHz且`.bak`为10 MHz；保留用户工作区当前值，未擅自覆盖。
