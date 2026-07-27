# 引脚映射 + 硬件接线速查

> **板卡**: 立创·地猛星 MSPM0G3507（嘉立创 / LCKFB DMX）  
> **资料来源**: 官方接线图、原理图、引脚图 + 2026 电赛控制题配套例程实机工程  
> **重要**: 小车与云台必须分别使用一片地猛星，不可共用同一块板

---

## MCU 速查 — MSPM0G3507

### 核心参数
| 项目 | 参数 |
|------|------|
| 内核 | ARM Cortex-M0+ |
| 主频 | 最高 80MHz（地猛星默认外接 40MHz HFXT，可经 PLL 升频） |
| Flash | 128KB |
| SRAM | 32KB |
| ADC | 2×12-bit, 最高 4MSPS |
| 通用定时器 | TIMG0 / TIMG6 / TIMG7 / TIMG8 / TIMG12 等（以 SysConfig 白名单为准） |
| 高级定时器 | TIMA0 / TIMA1 |
| UART | UART0/1/2/3（以 SysConfig 实际可选为准） |
| I2C | I2C0 / I2C1 |
| SPI | SPI0 / SPI1 |
| 供电 | 1.62V ~ 3.6V（板载 3.3V） |
| 封装 | LQFP64 |

### 地猛星板载固定资源

| 资源 | 引脚 | 说明 |
|------|------|------|
| SWDIO | PA19 | 调试数据，🔒 保留 |
| SWCLK | PA20 | 调试时钟，🔒 保留 |
| NRST | NRST | 复位 |
| BSL | PA18 | BSL 功能脚；云台表标注**禁止接线**；小车旧编码器曾占用（有 bug） |
| HFXT | PA5 / PA6 | 40MHz 晶振，已焊接，**勿当普通 GPIO** |
| LFX | PA3 / PA4 | 32.768kHz 晶振位，默认作时钟，慎用 |
| ROSC | PA2 | 板载 ROSC 电阻网络；小车灰度表占用 PA2 作最右灰度，使用前确认未与时钟冲突 |
| 板载/用户 LED | PA14 | 24H_4 `LED_BEEP.LED`，高亮 |
| 蜂鸣器 BEEP | PA15 | 24H_4 `LED_BEEP.BEEP`，**低电平响** |
| 开漏上拉 | PA0 / PA1 | 原理图带外部上拉，适合 I2C0；作 UART 时注意开漏特性 |
| 板载 UART0 丝印 TX/RX | PA10 / PA11 | **24H_4 DEBUG 默认占用**（TX=PA10, RX=PA11） |
| VREF+ / VREF- | PA23 / PA21 | ADC 基准相关，作 GPIO 前先确认 |

**禁用 / 慎用铁律：**

| 引脚 | 原因 | 处理 |
|------|------|------|
| **PA19, PA20** | SWD | 绝对保留 |
| **PA5, PA6** | HFXT 40MHz | 绝对勿当 GPIO |
| **PA3, PA4** | LFX | 默认时钟，勿随便占用 |
| **PA18** | BSL | 云台禁止接线；小车优先用新编码器脚 PA21/PA22 |
| **PA0, PA1** | 开漏 + 上拉 | 接线图 MPU6050 备用位；**默认 IMU 汇电籽-601 不占**；勿推挽大电流 |

---

## 一、小车接线总表（官方接线图 + 例程验证）

> 左侧/右侧功能列为 UP 主汇总简化名，实际每脚可配多种复用。  
> **生成代码前仍须向用户确认实际跳线**；下表是地猛星小车默认教程接法。

### 1.1 电机 TB6612FNG

| 外设功能 | 芯片/模块 | 地猛星引脚 | 片上复用 | 备注 |
|----------|----------|-----------|----------|------|
| **TB6612 PWMA** | TB6612FNG | **PA12** | TIMG0_C0 | motor_id=1，PWMAB C0，period=4000 |
| **TB6612 PWMB** | TB6612FNG | **PA13** | TIMG0_C1 | motor_id=2 |
| **AIN1（syscfg 宏）** | TB6612FNG | **PA9** | GPIO | 24H_4 empty.syscfg |
| **AIN2（syscfg 宏）** | TB6612FNG | **PA8** | GPIO | 24H_4 empty.syscfg |
| **BIN1（syscfg 宏）** | TB6612FNG | **PA7** | GPIO | 24H_4 empty.syscfg |
| **BIN2（syscfg 宏）** | TB6612FNG | **PB18** | GPIO | 24H_4 empty.syscfg |
| **TB6612 STBY** | TB6612FNG | **PB24** | GPIO | 高电平使能 |
| TB6612 VM | — | 电池 7.4V | — | 电机电源 |
| TB6612 VCC | — | 3.3V | — | 逻辑电源 |
| TB6612 GND | — | GND | — | 必须共地 |

**例程注释（官方 car 工程）:**
```
// 24H_4 empty.syscfg + motor 驱动
STBY=PB24
PWMA=PA12 (id1)  PWMB=PA13 (id2)  period=4000
AIN1=PA9  AIN2=PA8
BIN1=PA7  BIN2=PB18
ENC1 AA/AB = PA21/PA22
ENC2 BA/BB = PB19/PB20
轮径 48mm，编码器 260 线
```

权威：`ref_24h4.md`。拓展板座子物理走线见 `expansion_board.md`。  
生成控制代码时 **motor_id 与 24H_4 一致**：1→A/PA12，2→B/PA13。

### 1.2 编码器

| 外设功能 | 地猛星引脚 | 备注 |
|----------|-----------|------|
| **右轮编码器 A/B** | **PA21 / PA22** | 拓展板 ENCA_R / ENCB_R |
| **左轮编码器 A/B** | **PB19 / PB20** | 拓展板 ENCA_L / ENCB_L |
| 旧方案 PA17/PA18 | 勿优先 | BSL/bug；灰度最左可能占 PA17 |
| 早期单电机例程 AA/AB | PA17/PA18 | 迁移到拓展板右轮脚 |

### 1.3 传感器 / 显示 / 通信

| 外设功能 | 芯片/模块 | 地猛星引脚 | 片上复用 | 备注 |
|----------|----------|-----------|----------|------|
| **OLED SDA** | SSD1306 0.96" | **PB3** | I2C1_SDA | 地址 0x3C，例程 `OLED`=I2C1 |
| **OLED SCL** | SSD1306 | **PB2** | I2C1_SCL | 400kHz |
| **汇电籽-601 T→MCU** | 汇电籽-601 | **PA25** | UART3_RX | 24H_4 IMU601 |
| **汇电籽-601 R←MCU** | 汇电籽-601 | **PA26** | UART3_TX | V=5V |
| **调试串口 TX** | USB-UART / printf | **PA10** | UART0_TX | 24H_4 名 **DEBUG** |
| **调试串口 RX** | USB-UART / printf | **PA11** | UART0_RX | 115200 |
| 备选 MPU6050 SDA/SCL | MPU6050 | PA0 / PA1 | I2C0 | 仅用户明确要求时；非默认 |
| **舵机 PWM** | 航模舵机 | **PA27** | TIMG7_C1 | 小车接线图“舵机” |
| **LED** | 声光 | **PA14** | GPIO | 高电平亮；SysConfig 组 `LED_BEEP` |
| **BEEP 蜂鸣器** | 声光 | **PA15** | GPIO | **低电平响**，初值高/静音；`beep_on=clear` |
| **KEY1 / KEY2** | 按键板 | **PB6 / PB7** | GPIO | Pull-down，按下=高；24H_4 |
| **旋钮** | 10 键板电位器 | **PA16** | ADC1 | 例程 xuanniu |
| **GanWei DAT** | 串行灰度 | 用户指定（常 PB8） | GPIO **Input 悬浮** | **无内部上下拉**；见 `gray_serial.md` |
| **GanWei CLK** | 串行灰度 | 用户指定（常 PB9） | GPIO Output | 主控输出时钟 |
| ADC 旋钮/实验 | ADC | **PA16** 等 | ADC | 例程 `xuanniu` 用 PA16 |
| VREF | — | **PA23** | VREF+ | |

### 1.4 灰度模块（小车接线图 GPIO 位）

| 位置（接线图标注） | 地猛星引脚 | 备注 |
|-------------------|-----------|------|
| 灰度最右边 | PA2 | 与 ROSC 同脚，确认硬件后再用 |
| 灰度模块右 | PA24 | |
| 灰度模块中 | PB9 | |
| 灰度模块左 | PB8 | |
| 灰度最左边 | PA17 | 与旧编码器 1A 冲突，二选一 |

若使用 **GanWei 串行灰度辅助板**，不要写死上述 5 路；改为 2 线串行，引脚由用户指定（常见可借用 PB8/PB9，但会与表中灰度中/左冲突）。详见 `gray_serial.md`。

### 1.5 小车信号冲突检查

| 总线/资源 | 设备 | 状态 |
|-----------|------|------|
| UART3 | **汇电籽-601** PA26/PA25 | ✅ 默认 IMU |
| I2C1 | OLED (PB3/PB2) | ✅ 独占 |
| I2C0 | 备选 MPU6050 PA0/PA1 | 非默认 |
| TIMG0 | PWMA/PWMB (PA12/PA13) | ✅ |
| TIMG7_C1 | 舵机 PA27 | ✅ |
| UART0 DEBUG | printf **PA10/PA11** | ✅ 24H_4 |
| PA17/PA18 | 旧编码器 / BSL / 灰度最左 | ⚠️ 冲突区，优先改用 PA21/PA22 |
| PA2 | ROSC / 灰度最右 | ⚠️ 慎用 |

---

## 二、云台接线总表（官方接线图 + yuntai 例程）

> 云台与小车**必须各用一片地猛星**。

### 2.1 开环步进电机

| 功能 | 步进电机 1 | 步进电机 2 |
|------|-----------|-----------|
| PWM | **PA28** (TIMA1_C0) | **PA12** (TIMG0_C0) |
| DIR | **PA31** | **PA13** |
| SLP | **PB24** | **PA15** |
| DCY | **PB20** | **PA14** |
| RST | **PA7** | **PA16** |

### 2.2 闭环步进（UART）

| 功能 | 引脚 | 复用 |
|------|------|------|
| 闭环步进 1 RX（MCU→电机） | PB6 | UART1_TX / 也可作按键 1 |
| 闭环步进 1 TX（电机→MCU） | PB7 | UART1_RX / 也可作按键 2 |
| 闭环步进 2 RX | PA21 | UART2_TX |
| 闭环步进 2 TX | PA22 | UART2_RX |

### 2.3 云台 SPI OLED / 激光 / 按键 / 舵机

| 功能 | 引脚 | 说明 |
|------|------|------|
| OLED_CS | PA2 | SPI0_CS0 |
| OLED_CLK | PB18 | SPI0_SCK |
| OLED_MOSI | PA9 | SPI0_PICO |
| OLED_RES | PA8 | GPIO |
| OLED_DC | PB2 | GPIO |
| SPI POCI | PB19 | 可不接 |
| 激光模块 S | PA17 | GPIO |
| 航模舵机 2 PWM | PA27 | TIMG7_C1 |
| 按键 10 | PB3 | |
| 按键 1 / 2 | PB6 / PB7 | 与闭环 UART1 复用，二选一 |
| 按键 3 / 4 | PA26 / PA25 | UART3 位，作 GPIO 按键 |
| BSL | PA18 | **禁止接线** |

### 2.4 云台调试串口

云台例程同样常见：
- printf DEBUG: UART0 **PA10=TX, PA11=RX**（24H_4）
- 或使用板载丝印 PA11/PA10

---

## 三、地猛星排针丝印速查（核心）

左右排针丝印与芯片脚对应（摘自官方接线图）：

| 丝印 | 芯片脚 | 丝印 | 芯片脚 |
|------|--------|------|--------|
| A00 | PA0 | A27 | PA27 |
| A01 | PA1 | A26 | PA26 |
| A28 | PA28 | A25 | PA25 |
| A31 | PA31 | A24 | PA24 |
| RST | NRST | A23 | PA23 |
| A02 | PA2 | A22 | PA22 |
| B24 | PB24 | A21 | PA21 |
| B20 | PB20 | B09 | PB9 |
| B19 | PB19 | B08 | PB8 |
| B18 | PB18 | A18 | PA18 |
| A07 | PA7 | A17 | PA17 |
| B02 | PB2 | A16 | PA16 |
| B03 | PB3 | A15 | PA15 |
| A08 | PA8 | A14 | PA14 |
| A09 | PA9 | A13 | PA13 |
| B06 | PB6 | A12 | PA12 |
| B07 | PB7 | +5V / 3V3 / GND | 电源 |

顶部：SWCLK、SWDIO、3V3、GND。

---

## 四、MG310 电机参数（小车）

| 参数 | 值 |
|------|-----|
| 型号 | MG310 直流减速电机 |
| 额定电压 | **7.4V** (7~13V) |
| 空载转速 | 500±13% RPM |
| 减速比 | **1:20.409** |
| 编码器(霍尔) | 13 PPR → 输出轴约 **260~265 脉冲/圈**（例程 `MOTOR_BIANMAQI 260`） |
| 车轮 | **24H_4：直径 48mm**（`MOTOR_WHEEL_D`）；以实车为准 |

---

## 五、电源方案

| 供电对象 | 电压 | 来源 |
|----------|------|------|
| **M0G 地猛星** | 3.3V | 板载 LDO / Type-C / 排针 3V3 |
| **TB6612 电机** | 7.4V | 2S 锂电池 → VM |
| **编码器** | 3.3V | 与 M0G 同地 |
| **舵机** | 5V | 独立 5V，与逻辑共地 |
| **泰山派 RK3566** | 5V Type-C | 独立供电，与 M0G **共地** |
| **激光笔** | 按模块 | MOS/三极管由 GPIO 开关 |

```
电池 7.4V ──┬── 板载/外置 3.3V ── MCU / OLED / 逻辑
             └── TB6612 VM
所有 GND 单点共地；电机端就近 100uF + 0.1uF
```

---

## 六、与旧“天猛星”skill 关键差异（迁移必看）

| 项目 | 旧天猛星 skill | **地猛星（本 skill）** |
|------|----------------|------------------------|
| OLED | I2C0 PA28/PA31 | **I2C1 PB3/PB2** |
| 默认 IMU | （旧 skill 混乱 ATKP/MPU） | **汇电籽-601 UART3 PA25/PA26，协议 AA55** |
| 电机 PWM | TIMG8 PB15/PB16 | **TIMG0 PA12/PA13** |
| 电机方向 | PA13/12 + PB0/PB1 | **PA8/PA9 + PB18/PA7** |
| STBY | 常接 3.3V | **PB24 GPIO** |
| 舵机（小车） | PB8/PB9 TIMA0 | **PA27 TIMG7_C1** |
| 调试 UART | （旧混乱） | **24H_4：PA10/PA11 UART0 DEBUG** |
| 板载 LED | PB22 等 | **PA14** |
| 时钟 | PA2~PA6 未焊接 | **PA5/PA6 已焊 40MHz；PA3/PA4 LFX** |

---

## 七、泰山派通信

视觉方案由泰山派 RK3566 负责，详见 `taishan_pai.md`。  
地猛星侧推荐空闲 UART（printf=PA10/11，**汇电籽-601=UART3 PA26/25** 时，泰山派通信另选 UART1/2 或问用户）。**引脚以用户实际接线为准。**

---

## 八、硬件连接速查（小车默认）

**TB6612：**
| TB6612 | 地猛星 | 说明 |
|--------|--------|------|
| PWMA | PA12 | motor id1 |
| PWMB | PA13 | motor id2 |
| AIN1 / AIN2 | **PA9 / PA8** | 24H_4 syscfg 宏 |
| BIN1 / BIN2 | **PA7 / PB18** | 24H_4 syscfg 宏 |
| STBY | PB24 | 使能 |
| VM | 7.4V | 电机电 |
| VCC | 3.3V | 逻辑电 |

**汇电籽-601（默认 IMU）：**
| 汇电籽-601 | 地猛星 | 说明 |
|-----------|--------|------|
| T (模块TX) | PA25 (UART3_RX) | 交叉 |
| R (模块RX) | PA26 (UART3_TX) | 交叉 |
| V | **5V** | 供电 4.5~5.5V |
| G | GND | 共地 |
| 协议 | 见 `imu601.md` | 帧头 AA 55，ID 0x60，115200 |

**OLED SSD1306：**
| OLED | 地猛星 |
|------|--------|
| SDA | PB3 (I2C1_SDA) |
| SCL | PB2 (I2C1_SCL) |
| VCC | 3.3V |
| GND | GND |
| 地址 | 0x3C |

**备选 MPU6050（非默认）：**
| MPU6050 | 地猛星 |
|---------|--------|
| SDA/SCL | PA0/PA1 (I2C0) |
| VCC | 3.3V |
| AD0 | GND → 0x68 |

**调试 printf（24H_4 DEBUG）：**
| 功能 | 地猛星 |
|------|--------|
| UART0_TX | **PA10** |
| UART0_RX | **PA11** |
| 波特率 | 115200 |

**SWD：**
| 功能 | 引脚 |
|------|------|
| SWDIO | PA19 |
| SWCLK | PA20 |
