# 24H_4 实机引脚与 SysConfig 基准（权威）

> 来源：桌面工程 `24H_4/empty.syscfg` + `Debug/ti_msp_dl_config.h` + `user_driver/*`  
> skill 默认小车引脚/实例名以本表 + 当前 `24H_4` 为准。  
> 灰度：**敢为串行 8 路**（见 §5 / `gray_serial.md`），旧五路并口 HUIDU 已废弃。

题目：2024 年电赛 H 题自动行驶小车（A→B→弧线…），见用户题面。

---

## 1. SysConfig 外设实例一览

| SysConfig Name | 外设 | 关键脚 |
|----------------|------|--------|
| **HFXT** | 40MHz 晶振 | PA5/PA6 |
| **OLED** | I2C1 | SDA=**PB3**, SCL=**PB2**（工程里 BusSpeed=100kHz） |
| **PWMAB** | TIMG0 PWM | C0=**PA12**, C1=**PA13**, timerCount=**4000**, 上电 startTimer |
| **SERVO** | TIMG7 PWM | C1=**PA27**, div=8, prescale=100, timerCount=2000, duty≈7.5% |
| **MOTOR_PID** | TIMA0 周期中断 | 负载 7999（速度/航向控制节拍） |
| **NTB** | TIMG12 | 时间戳 |
| **DEBUG** | UART0 | TX=**PA10**, RX=**PA11**, 115200 |
| **IMU601** | UART3 | TX=**PA26**, RX=**PA25**, 115200 |
| **xuanniu** | ADC1 | **PA16**, 内部 2.5V VREF |
| **LED_BEEP** | GPIOA | LED=**PA14**, BEEP=**PA15**（BEEP 初值 SET，低电平响） |
| **KEY** | GPIOB | KEY1=**PB6**, KEY2=**PB7**, Pull-down, 上升沿中断 |
| **DC_MOTOR** | GPIO | 见下表 |
| **Serial** | GPIO | DAT=PB8 悬浮输入, CLK=PB9 输出（敢为） |

---

## 2. 电机 TB6612（必须按 empty.syscfg 宏名）

| SysConfig 名 | 地猛星脚 | 说明 |
|--------------|----------|------|
| **PWMA** (PWMAB C0) | **PA12** | motor_id=**1** |
| **PWMB** (PWMAB C1) | **PA13** | motor_id=**2** |
| **AIN1** | **PA9** | ⚠️ 以 syscfg 为准（不是 PA8） |
| **AIN2** | **PA8** | |
| **BIN1** | **PA7** | ⚠️ 以 syscfg 为准 |
| **BIN2** | **PB18** | |
| **STBY** | **PB24** | 高电平使能 |
| 编码器 AA/AB（电机1） | **PA21 / PA22** | 上升沿计数 `counter_1_A` |
| 编码器 BA/BB（电机2） | **PB19 / PB20** | 上升沿计数 `counter_2_A` |

```
// 24H_4 motor.h 物理注释（与拓展板座子）
STBY=PB24
PWMA=PA12, AIN 侧 PA8/PA9（软件宏 AIN1=PA9, AIN2=PA8）
PWMB=PA13, BIN 侧 PA7/PB18（软件宏 BIN1=PA7, BIN2=PB18）
电机1 编码器 PA21/PA22
电机2 编码器 PB19/PB20
轮径 MOTOR_WHEEL_D = 48 mm
编码器线数 MOTOR_BIANMAQI = 260
PWM 周期 4000；duty 限幅约 0~1300
```

方向 API（24H_4）：
- `direction=0` 刹车：IN1=IN2=1  
- `direction=1` 正转：IN1=1, IN2=0  
- `direction=2` 反转：IN1=0, IN2=1  

航向修正（`adjust_head`）：  
`duty1 = base - pwm_diff_half`, `duty2 = base + pwm_diff_half`（motor1/2 差速）。

---

## 3. 汇电籽-601

| 模块 | MCU |
|------|-----|
| T (TX) | **PA25** UART3_RX |
| R (RX) | **PA26** UART3_TX |
| V | 5V |
| G | GND |

协议：`AA 55`，ID `0x60`，仅姿态帧解析（与 `imu601.md` 一致）。  
初始化：软复位 `0x12` 后开 RX 中断（24H_4 默认不发 0x14 校准帧）。

---

## 4. 人机接口

| 功能 | 脚 | 极性/备注 |
|------|-----|-----------|
| LED | **PA14** | 高亮 `led_on=set` |
| 蜂鸣器 BEEP | **PA15** | **低电平响** `beep_on=clear`，初值高 |
| KEY1 | **PB6** | 按下=高，Pull-down；main 里切 task |
| KEY2 | **PB7** | 按下=高；启动当前 task |
| 旋钮 ADC | **PA16** | `xuanniu`，可选 |
| OLED | PB3/PB2 I2C1 | 地址 0x3C |
| 调试串口 | **PA10=TX, PA11=RX** | UART0 名 **DEBUG**（板载丝印 UART0） |
| 舵机 | **PA27** TIMG7_C1 | |

⚠️ **不要**再把小车默认 printf 写成 PA28/PA31。24H_4 用的是 **PA10/PA11**。

---

## 5. 灰度：敢为串行 8 路（当前 24H_4 已切换）

| 名 | 脚 | 配置 |
|----|-----|------|
| Serial DAT | **PB8** | Input, **RESISTOR_NONE 悬浮** |
| Serial CLK | **PB9** | Output, 初值低 |

- 旧五路并口 PA17/PB8/PB9/PA24/PA2 **已废弃**
- 8 路全用巡线，见 `user_driver/huidu.c` / `gray_serial.md`

---

## 6. 控制结构摘要（算法可复用）

- `task` 0~4：KEY1 切换；KEY2 锁存 `yaw_start` 并 `is_start=1`
- task1：纯航向直行到灰度触发停车 + 声光  
- task2/3/4：航向段 + 巡线段状态机，过点声光，多圈计数  
- 声光：`led_on/beep_on` 后 `led_beep_off_counter` 延时关  
- PID 节拍在 `MOTOR_PID`（TIMA0）中断

---

## 7. 与 skill 其它文档的关系

| 文档 | 关系 |
|------|------|
| `pins.md` / `expansion_board.md` | 物理座子与 24H_4 对齐；**DIR 软件宏名以本表 syscfg 为准** |
| `imu601.md` | 协议正确；接线脚与本表一致 |
| `gray_serial.md` | 敢为串行 8 路（与当前 24H_4 一致） |
| 生成新工程 | SysConfig 实例名尽量用 PWMAB / DEBUG / IMU601 / **LED_BEEP** / KEY1/KEY2；GanWei 时另加 Serial（**DAT 悬浮输入**） |
