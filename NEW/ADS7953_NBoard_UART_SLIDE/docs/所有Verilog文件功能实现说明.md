# ADS7953_NBoard_UART_SLIDE所有Verilog文件功能实现说明

本文对应工程`NEW/ADS7953_NBoard_UART_SLIDE`，依据当前源码逐个说明全部`.v`文件的功能和实现。当前有效配置为：系统时钟50 MHz、ADC SCLK 1 MHz、UART 115200 8-N-1、滑轨脉冲2 kHz、`ADS7953_BOARD_COUNT=20`。

`.v.bak`是用户保留的备份，不参与当前QSF编译，不属于本文的现行模块。

## 1. 文件与模块总览

| 文件 | 模块 | 是否综合 | 主要作用 |
|---|---|---:|---|
| `rtl/ads7953_Nboard_hw_top.v` | `ads7953_Nboard_hw_top` | 是 | Quartus物理顶层，连接FPGA外部引脚 |
| `rtl/ads7953_Nboard_top.v` | `ads7953_Nboard_top` | 是 | 系统连接层，实例化UART、滑轨和多板ADC控制 |
| `rtl/ads7953_Nboard_uart_bridge.v` | `ads7953_Nboard_uart_bridge` | 是 | 解析上位机命令，触发采集/滑轨，组装并发送UART帧 |
| `rtl/uart_8n1.v` | `uart_rx_8n1`、`uart_tx_8n1` | 是 | UART字节接收与发送 |
| `rtl/ads7953_Nboard_controller.v` | `ads7953_Nboard_controller` | 是 | 依次轮询N块板，译码独立CS，保存各板数据和状态 |
| `rtl/ads7953_16ch_reader.v` | `ads7953_16ch_reader` | 是 | 完成一块ADS7953的SPI配置、16通道读取、顺序检查与超时退出 |
| `slide.v` | `slide` | 是 | 根据方向和脉冲数产生2 kHz滑轨驱动脉冲 |
| `sim/tb_ads7953_Nboard.v` | `ads7953_model`、`tb_ads7953_Nboard` | 否 | 多板ADC、CS隔离、UART数据帧和结束帧仿真环境 |
| `sim/tb_slide.v` | `tb_slide` | 否 | 滑轨脉冲数、方向锁存和忙时拒绝重触发仿真 |

Quartus当前编译层级：

```text
ads7953_Nboard_hw_top
└─ ads7953_Nboard_top
   ├─ ads7953_Nboard_uart_bridge
   │  ├─ uart_rx_8n1
   │  └─ uart_tx_8n1
   ├─ slide
   └─ ads7953_Nboard_controller
      └─ ads7953_16ch_reader
```

## 2. `rtl/ads7953_Nboard_hw_top.v`

### 2.1 定位

这是QSF中指定的`TOP_LEVEL_ENTITY`，只负责把内部核心模块端口引到FPGA外部，不实现ADC、UART或滑轨状态机。

### 2.2 外部接口

输入：

- `clk`：50 MHz系统时钟。
- `rst_n`：低有效复位。
- `uart_rxd`：来自上位机串口的接收线。
- `adc_sdo`：多块ADS7953共享的SPI返回线。

输出：

- `uart_txd`：发往上位机的串口发送线。
- `adc_cs_n[19:0]`：20路独立、低有效片选。
- `adc_sclk`：所有ADC共享的SPI时钟。
- `adc_sdi`：所有ADC共享的MOSI/SDI。
- `pwm_out`：滑轨脉冲输出，QSF约束到PIN_A20。
- `dir`：滑轨方向输出，QSF约束到PIN_A19。

### 2.3 实现方式

文件只实例化一个`ads7953_Nboard_top u_core`。核心模块还提供`ready`、`busy`、`packet_busy`和`sample_*`调试信号，但物理顶层没有给这些信号分配外部引脚，而是接入`unused_*`内部网络。

因此修改这个文件通常只涉及物理顶层端口；功能逻辑应在下层模块中修改。

## 3. `rtl/ads7953_Nboard_top.v`

### 3.1 定位

这是系统连接层，负责把UART Bridge、滑轨模块和多板ADC控制器连接起来，不直接实现协议状态机。

### 3.2 参数

```text
CLK_HZ       = 50_000_000
UART_BAUD    = 115_200
ADC_SCLK_HZ  = 1_000_000
BOARD_COUNT  = `ADS7953_BOARD_COUNT
```

`BOARD_COUNT`来自`rtl/ads7953_board_count.vh`。当前宏为20，修改宏后必须完整重新编译，现有SOF不会自动改变。

### 3.3 三个子模块

1. `u_uart_bridge`
   - 接收UART命令。
   - 输出`start_scans`启动ADC轮询。
   - 输出`slide_start/slide_dir/slide_pulse_num`启动滑轨。
   - 接收`board_codes/board_valid/scans_done`并发送ADC结果。
   - 接收`slide_busy/slide_done`并发送滑轨完成帧。

2. `u_slide`
   - 固定配置为2 kHz。
   - 把滑轨启动请求转换成`pwm_out`和`dir`。

3. `u_controller`
   - 固定板间隔参数为100 ns。
   - 按`BOARD_COUNT`轮询ADC板。
   - 输出总数据缓存和每板有效标志。

### 3.4 互锁关系

UART Bridge同时连接ADC控制器的`ready`和滑轨的`busy`：

- 滑轨正在运动时不接受新的ADC触发`T`。
- ADC控制器不空闲或ADC数据正在组包时不接受滑轨移动命令。
- 互锁由Bridge实现，`top`只提供连线。

## 4. `rtl/uart_8n1.v`

一个文件中包含两个独立模块。

### 4.1 `uart_rx_8n1`

#### 功能

把异步UART串行输入转换成8位并行字节，格式固定为1个起始位、8个数据位、无校验、1个停止位。

#### 波特率计数

```text
CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD
```

使用加上`BAUD/2`后的整数除法进行四舍五入。50 MHz、115200 baud时，每位约434个系统时钟。

#### 输入同步

`rx`先经过`rx_meta`、`rx_sync`两级触发器再进入状态机，用于降低异步输入造成亚稳态传播的风险。

#### 状态机

```text
ST_IDLE -> ST_START -> ST_DATA -> ST_STOP -> ST_IDLE
```

- `ST_IDLE`：等待`rx_sync`变低，识别可能的起始位。
- `ST_START`：等待半个UART位后再次确认线路仍为低，过滤短毛刺和假起始位。
- `ST_DATA`：每隔一个UART位周期采样一次，按LSB First写入`shift[0]`到`shift[7]`。
- `ST_STOP`：检查停止位是否为高；有效时把`shift`送到`data`并让`data_valid`拉高一个系统时钟周期。

停止位错误时不会输出`data_valid`，该字节被丢弃。

### 4.2 `uart_tx_8n1`

#### 功能

收到一个系统时钟周期的`start`后，把`data`转换成UART串行波形。

#### 帧构造

```verilog
shift <= {1'b1, data, 1'b0};
```

10位移位寄存器包含：起始位0、8位数据、停止位1。发送时最低位先出。

#### 握手

- 空闲时`tx=1`、`busy=0`。
- 只有`busy=0`时才接受`start`。
- 发送期间`busy=1`，每经过`CLKS_PER_BIT`个时钟移出下一位。
- 完成停止位后恢复`tx=1`、`busy=0`。

上层Bridge必须等待`tx_busy=0`后才能给出下一个`tx_start`。

## 5. `rtl/ads7953_Nboard_uart_bridge.v`

### 5.1 定位

这是上位机协议与FPGA内部控制之间的桥梁，包含四项核心功能：

1. 接收ASCII `T`并触发一次N板ADC采集。
2. 解析7字节滑轨移动命令。
3. 把ADC缓存组装成N个40字节数据帧和一个8字节结束帧。
4. 滑轨完成后发送9字节完成帧。

### 5.2 ADC触发逻辑

`start_scans`是组合逻辑，只有以下条件同时满足时才拉高：

```text
rx_valid=1且rx_data=0x54
rx_state=RX_IDLE
adc_ready=1
slide_busy=0
slide_status_pending=0
packet_active=0
tx_busy=0
tx_start=0
```

因此忙时收到的`T`会被忽略，不缓存、不排队。只有被接受的`T`才会启动SCLK。

### 5.3 滑轨接收状态机

状态依次为：

```text
RX_IDLE
 -> RX_HEADER_2
 -> RX_OPCODE
 -> RX_DIR
 -> RX_PULSE_LO
 -> RX_PULSE_HI
 -> RX_CHECKSUM
```

对应命令：

```text
55 AA 4D Dir PulseLo PulseHi XOR
```

- 第一个字节必须为`55`。
- 第二个字节必须为`AA`。
- 命令字必须为`4D`。
- `Dir`只允许`00`或`01`。
- 脉冲数按小端序接收。
- XOR覆盖`4D`、方向和两个脉冲数字节。

校验通过后，还要满足`adc_ready && !slide_busy && !packet_active && !slide_status_pending`才输出一个周期的`slide_start`。方向和脉冲数同时锁存到`slide_dir`及`slide_pulse_num`。无效命令直接回到`RX_IDLE`，FPGA不返回拒绝帧。

### 5.4 `code_byte`函数

该函数从3840位总缓存中取出某块板、某个通道的字节：

```text
每板16通道 × 12位 = 192位
20板 × 192位 = 3840位
```

ADC协议每通道用两个字节发送：低字节先发，高字节只使用bit3～0。

当`payload_index==1`，即正在生成CH0高字节，并且`valid_bits[board_id]==0`时，函数返回：

```text
bit7    = 1，整块板本轮SPI扫描失败
bit6～4 = 000
bit3～0 = CH0原码高4位
```

所以错误标志虽然放在CH0高字节中，表示的却是整块板CH0～CH15扫描失败，而不是只检测CH0。

### 5.5 `packet_byte`函数

根据`byte_index`动态生成数据帧或结束帧的当前字节。

数据帧40字节：

```text
A5 5A 01 Board 20 SeqLo SeqHi
CH0Lo CH0Hi ... CH15Lo CH15Hi XOR
```

其中字段`20`是十六进制`0x20`，表示后续ADC负载长度为32字节，不是20块板。

结束帧8字节：

```text
A5 5A 01 FF BoardCount SeqLo SeqHi XOR
```

### 5.6 ADC发送状态

`scans_done`到来时，Bridge执行以下操作：

- 把`board_codes`锁存到`codes_snapshot`。
- 把`board_valid`锁存到`valid_snapshot`。
- 把当前`sequence_counter`锁存为本轮序号。
- 序号计数器加1。
- 从板0、字节0开始发送。

`packet_active`期间，每当UART空闲就产生一个周期的`tx_start`。`byte_index`走完39后切到下一块板；最后一块板结束后令`sending_end=1`并发送8字节结束帧。

XOR不包含帧头`A5 5A`：数据帧异或偏移2～38，结束帧异或偏移2～6。

### 5.7 滑轨完成帧

`slide_done`出现时置`slide_status_pending=1`，随后发送：

```text
A5 5A 01 FE 01 Dir PulseLo PulseHi XOR
```

`slide_status_byte`函数按索引生成9个字节。方向和脉冲数来自启动滑轨时锁存的寄存器，因此上位机可以核对完成帧是否与命令一致。

发送调度中，`packet_active`分支位于`slide_status_pending`之前，所以ADC数据包具有发送优先级；滑轨完成状态会保持等待，直到ADC包发送结束和UART空闲。

### 5.8 `packet_busy`

```text
packet_busy = packet_active | slide_status_pending | tx_busy | tx_start
```

它表示Bridge仍在组织或发送某类返回数据，供上层或仿真判断通信是否完全空闲。

## 6. `rtl/ads7953_Nboard_controller.v`

### 6.1 定位

Controller把一个单板Reader复用于N块ADS7953：依次选择板0到板N-1，保存每块板的16通道结果，最后输出`all_done`。

### 6.2 CS译码

Reader只输出一个低有效`reader_cs_n`。Controller按`selected_board`译码成20路：

```verilog
adc_cs_n = reader_cs_n ? 20'hFFFFF :
           ~(20'h00001 << selected_board);
```

- Reader未选中时，20路CS全高。
- Reader选中时，只有当前板对应位为低。
- 任意时刻最多一块板被选中。

SCLK和SDI直接从Reader输出到所有板；共享SDO直接送回Reader。硬件必须保证未选中板的SDO为高阻。

### 6.3 板间隔计算

默认`BOARD_GAP_NS=100`。50 MHz时计算得到`BOARD_GAP_CLKS=5`，即两块板之间等待约100 ns后再触发下一块。

### 6.4 状态机

```text
ST_WAIT_POWERUP -> ST_IDLE -> ST_WAIT_BOARD
                                  |
                         非末板 -> ST_BOARD_GAP -> ST_WAIT_BOARD
                         末板   -> ST_FINISH -> ST_IDLE
```

- `ST_WAIT_POWERUP`：等待单板Reader完成自身上电等待。
- `ST_IDLE`：`ready=1`。收到`start`后清空总缓存和有效位，从板0开始。
- `ST_WAIT_BOARD`：等待`reader_scan_done`。
- `ST_BOARD_GAP`：切换`selected_board`后等待板间隔，再给出一个周期的`reader_trig`。
- `ST_FINISH`：让`all_done`拉高一个系统时钟周期，清除`busy`后返回空闲。

### 6.5 数据保存

当前板结束时，无论成功还是失败都会保存：

```verilog
board_codes[selected_board*192 +: 192] <= reader_codes;
board_valid[selected_board]             <= reader_scan_ok;
```

布局为：

```text
board_codes[191:0]     = 板0 CH0～CH15
board_codes[383:192]   = 板1 CH0～CH15
...
board_codes[3839:3648] = 板19 CH0～CH15
```

`sample_board`直接等于当前`selected_board`；Reader每取得一个有效通道时，`sample_valid/sample_channel/sample_code`可供仿真或内部观察。

## 7. `rtl/ads7953_16ch_reader.v`

### 7.1 定位

这是ADC SPI实现的核心。每次触发只处理当前被Controller选中的一块ADS7953，完成配置、读取、通道顺序验证和有界超时。

### 7.2 时钟与等待参数

当前上层传入`SCLK_HZ=1_000_000`：

```text
SCLK_PERIOD_CLKS = 50
SCLK_HIGH_CLKS   = 25
SCLK_LOW_CLKS    = 25
```

所以SCLK周期1 us，高低各500 ns。

`CS_HIGH_CLKS`按至少100 ns计算，50 MHz时为5个时钟。`POWERUP_CLKS`按2 us计算，50 MHz时为100个时钟。

### 7.3 触发同步

`trig`经过`trig_meta`、`trig_sync`、`trig_sync_d`同步，然后用：

```text
trig_rise = trig_sync & ~trig_sync_d
```

生成单周期上升沿。Reader只在`ST_IDLE`响应这个边沿。

### 7.4 SPI命令

```text
CMD_AUTO2_PROGRAM = 93C0
CMD_AUTO2_ENTER   = 3C40
CMD_CONTINUE      = 0000
```

- `93C0`：设置Auto-2扫描最后通道为CH15。
- `3C40`：进入Auto-2、从CH0重新开始、选择0～2×VREF量程。
- `0000`：保持当前模式并继续转换。

### 7.5 主状态机

```text
ST_POWERUP -> ST_IDLE -> ST_START -> ST_SHIFT -> ST_GAP
                          ^                       |
                          +------继续下一字------+ 
```

- `ST_POWERUP`：复位后等待2 us，再置`ready=1`。
- `ST_IDLE`：等待触发；触发后清零缓存、通道状态和帧计数，首发`93C0`。
- `ST_START`：CS拉低、SCLK拉低，先输出发送字bit15，准备16位传输。
- `ST_SHIFT`：按分频计数翻转SCLK。SCLK上升沿采样SDO，下降沿准备下一位SDI。
- `ST_GAP`：CS保持高电平至少100 ns；若未结束则进入下一字，否则输出`scan_done`并回到空闲。

### 7.6 为什么丢弃前三个返回字

ADS7953存在命令和转换结果流水线。Reader使用`discard_count`处理前三个返回字：

| SPI字序号 | MOSI发送 | MISO处理 |
|---:|---|---|
| 1 | `93C0` | 丢弃 |
| 2 | `3C40` | 丢弃 |
| 3 | `0000` | 丢弃 |
| 4以后 | `0000` | 开始寻找CH0～CH15 |

正常情况下第4个返回字为CH0，第19个为CH15。

### 7.7 16通道顺序检查

返回字格式：

```text
bit15～12 = 通道号
bit11～0  = 12位ADC码
```

Reader用`collecting`和`expected_channel`检查完整序列：

1. 尚未开始收集时，只接受通道号0作为起点。
2. 开始收集后，只有通道号等于`expected_channel`才写入缓存。
3. 期待其他通道时如果再次收到CH0，认为出现了新一轮扫描：清空旧的部分数据并从新CH0重新同步。
4. 其他错序通道不写入缓存，继续发送`0000`寻找重新同步机会。
5. 按顺序收到CH15后，置`scan_ok=1`和`stop_after_gap=1`。

每个成功通道按以下方式保存：

```verilog
adc_codes[channel*12 +: 12] <= rx_shift[11:0];
```

同时输出一个周期的`sample_valid`以及对应的`sample_channel/sample_code/sample_mv`。

### 7.8 毫伏换算

`code_to_mv`按5 V满量程计算并四舍五入：

```text
sample_mv = round(code × 5000 / 4096)
```

Controller当前没有使用`sample_mv`，它主要作为Reader级调试输出。

### 7.9 32字超时

`MAX_FRAME_COUNT=32`限制一次单板扫描最多产生32个SPI字。若到上限仍未得到完整连续CH0～CH15：

- `stop_after_gap=1`，完成当前CS高间隔后停止SCLK。
- `adc_codes`清零。
- `scan_ok`保持0。
- `scan_done`仍然输出一个周期。

Controller因此可以继续扫描下一板，不会因缺板、SDO浮空或通道错序永久卡住。

如果第32个字恰好是按顺序到达的CH15，则成功条件优先成立，数据不会被超时逻辑清零。

### 7.10 错误标志如何传到上位机

```text
Reader：scan_ok=0
  -> Controller：board_valid[当前板]=0
  -> UART Bridge：该板CH0高字节bit7=1
  -> 上位机：该板16通道标红
```

检测对象是完整CH0～CH15序列，只是借用CH0高字节的空闲bit7传输板级状态。

## 8. `slide.v`

### 8.1 定位

根据一次启动脉冲、方向和16位脉冲数，产生固定频率、固定占空比的滑轨脉冲。

### 8.2 参数与当前数值

```text
SYS_CLK  = 50_000_000
PWM_FREQ = 2_000
```

因此：

```text
PWM_PERIOD_CNT = 25000个系统时钟
PWM_HALF_CNT   = 12500个系统时钟
周期           = 500 us
高电平         = 250 us
低电平         = 250 us
```

### 8.3 启动与锁存

只有`trig && !busy`时接受命令：

- 把`pulse_num`锁存到`pulse_target`。
- 把`move_dir`锁存到`dir`。
- 清零周期和脉冲计数。
- 置`busy=1`。

运动期间再次出现`trig`不会改变本次方向和脉冲数。

### 8.4 脉冲产生

`cycle_count < PWM_HALF_CNT`时`pwm_out=1`，否则为0。每完成一个完整PWM周期，`pulse_count`加1。

当`pulse_count`达到`pulse_target`：

- `pwm_out=0`。
- `busy=0`。
- `done=1`一个系统时钟周期。

Bridge捕获`done`后才发送滑轨完成帧。因此上位机绿灯代表FPGA已经完成指定脉冲，而不是仅仅完成命令发送。

当前换算为80脉冲/mm。例如0.5 mm为40脉冲，300 mm为24000脉冲。

## 9. `sim/tb_slide.v`

### 9.1 目的

单独验证`slide`模块：

- 指定脉冲数是否准确。
- 方向是否在运动期间保持锁存。
- `busy=1`期间的新触发是否被忽略。
- 完成后`busy`和`pwm_out`是否回到空闲状态。

### 9.2 加速参数

仿真把参数改为：

```text
SYS_CLK=100
PWM_FREQ=10
```

两者比值为10，所以每个PWM周期只需10个仿真时钟，缩短运行时间。这里验证的是计数逻辑，不代表真实硬件频率。

### 9.3 测试流程

1. 复位释放后启动正向3脉冲。
2. 运动尚未结束时，把外部方向改成反向、脉冲数改为9并再次触发。
3. 等待`done`。
4. 检查实际只有3个PWM上升沿。
5. 检查`dir`仍为正向，证明忙时触发没有覆盖锁存值。
6. 检查完成后`busy=0`、`pwm_out=0`。

该testbench不验证UART滑轨命令和9字节完成帧；这些属于Bridge层功能。

## 10. `sim/tb_ads7953_Nboard.v`

这个文件包含行为模型`ads7953_model`和系统testbench `tb_ads7953_Nboard`。

### 10.1 `ads7953_model`

模型模拟一块ADS7953的基本流水线行为：

- CS下降沿开始一个16位SPI字并输出当前响应的bit15。
- SCLK上升沿采集MOSI。
- SCLK下降沿更新下一位SDO。
- CS上升沿解析完整MOSI字并准备下一字的响应。

收到高4位为`1001`的程序寄存器命令时，模型调整本轮基准值；收到`3C40`后进入Auto-2并准备从CH0开始。随后按CH0、CH1……顺序返回：

```text
{4位通道号, 12位模型数据}
```

每块模型用不同`FIRST_BASE`，使testbench能够判断数据是否来自正确板卡。

### 10.2 系统实例化

`tb_ads7953_Nboard`实例化完整`ads7953_Nboard_top`，但为了缩短仿真时间使用：

```text
UART_BAUD   = 5_000_000
ADC_SCLK_HZ = 10_000_000
```

同时生成20个`ads7953_model`。所有模型共享SCLK和SDI，每个模型使用自己的CS。共享SDO由以下逻辑合并：

```verilog
adc_sdo = |(model_sdo & ~adc_cs_n);
```

即只有CS为低的模型参与返回数据。

### 10.3 UART发送和接收任务

- `uart_send_byte`：按LSB First产生起始位、8位数据和停止位，用于向DUT发送`0x54`。
- `uart_receive_byte`：从`uart_txd`检测起始位，在每位中心采样，并检查停止位。
- `receive_board_packet`：接收40字节数据帧，检查帧头、版本、板号、`0x20`负载长度、序号、16路数据和XOR。
- `receive_end_packet`：接收8字节结束帧，检查实际板数、序号和XOR。

### 10.4 主测试流程

`trigger_and_check`执行：

1. 等待`ready && !packet_busy`。
2. 发送ASCII `T`。
3. 等待ADC控制器进入`busy`。
4. 按板号接收并检查每个40字节数据帧。
5. 检查8字节结束帧。
6. 检查每个已配置板恰好出现16次`sample_valid`。

主过程连续执行两轮，期望采集序号分别为0和1，以验证序号递增以及重复触发。

### 10.5 CS隔离监控

每个系统时钟统计20路CS中低电平的数量。若同时有两路以上CS为低，立即累计错误，验证Controller的一热低有效译码。

### 10.6 当前覆盖边界

该testbench验证：

- 当前宏板数的顺序轮询。
- 每次只有一个CS有效。
- SPI命令进入Auto-2并返回有序16通道。
- N个40字节数据帧内容和XOR。
- 8字节结束帧、板数和序号递增。

它没有覆盖：

- 缺板、SDO浮空、通道错序和32字超时路径。
- CH0高字节bit7错误标志路径。
- UART忙时重复`T`。
- 7字节滑轨命令解析与9字节完成帧。
- FPGA物理引脚、电气质量及真实ADS7953时序裕量。

## 11. 一次完整采集的数据流

```text
上位机发送T
 -> uart_rx_8n1输出rx_data=54、rx_valid=1
 -> UART Bridge确认ADC/UART/滑轨空闲
 -> start_scans=1
 -> NBoard Controller清空总缓存并选择板0
 -> 16ch Reader发送93C0、3C40、0000...
 -> Reader按顺序收集CH0～CH15
 -> scan_done/scan_ok送回Controller
 -> Controller保存192位数据和1位有效状态
 -> 切换到下一块板，重复到板N-1
 -> Controller输出scans_done
 -> UART Bridge锁存总缓存和有效位
 -> 逐板生成40字节帧
 -> 失败板在CH0高字节bit7写1
 -> 最后生成8字节结束帧
 -> uart_tx_8n1逐位发送给上位机
```

## 12. 一次滑轨移动的数据流

```text
上位机发送55 AA 4D Dir PulseLo PulseHi XOR
 -> uart_rx_8n1逐字节接收
 -> UART Bridge状态机校验帧头、方向和XOR
 -> 确认ADC组包与滑轨均空闲
 -> slide_start=1并锁存方向、脉冲数
 -> slide输出2 kHz pwm_out，dir保持不变
 -> 指定脉冲全部完成，slide_done=1
 -> UART Bridge生成9字节完成帧
 -> uart_tx_8n1发送给上位机
 -> 上位机核对方向、脉冲数和XOR后更新状态灯
```

## 13. 阅读和修改源码时的边界

- 修改板数：改`rtl/ads7953_board_count.vh`并完整重新编译。
- 修改ADC SPI时序：重点检查`ads7953_16ch_reader.v`，同时复核ADS7953数据手册的最小时序。
- 修改多板轮询或CS：修改`ads7953_Nboard_controller.v`。
- 修改通信帧或错误标志：必须同时修改UART Bridge、上位机解析器、导出逻辑、测试和协议文档。
- 修改滑轨频率或硬件行为：修改`slide.v`及其顶层参数，并重新验证脉冲数和完成帧时机。
- 修改外部端口：同时核对`ads7953_Nboard_hw_top.v`和QSF约束。
- ModelSim/Questa仿真每次运行前仍需取得用户明确许可；本文生成过程没有运行仿真。
