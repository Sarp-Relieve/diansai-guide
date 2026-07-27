# 地猛星 MSPM0G3507 小车 CCS/Theia 工程基线

Board: **立创·地猛星 MSPM0G3507**  
Chip: MSPM0G3507（硅片与天猛星同系列，**接线不同**）

## 默认外设（官方接线图 + 配套例程）

- SSD1306 OLED → **I2C1** PB3=SDA, PB2=SCL
- **默认 IMU 汇电籽-601** → UART3 PA25/PA26（V=5V）
- 备选 MPU6050 → I2C0 PA0/PA1（非默认）
- TB6612FNG → **TIMG0** PWMA=PA12(**右**), PWMB=PA13(**左**)
- 方向脚 右 AIN1=PA9 AIN2=PA8，左 BIN1=PA7 BIN2=PB18，STBY=PB24
- 编码器 右 PA21/22，左 PB19/20（拓展板）
- 按键 KEY1/2=PB6/PB7，旋钮 PA16
- printf → UART0 **PA10/PA11**
- 板上 LED → PA14
- 按键例程 → PB6/PB7

## 引脚表

| Function | Pin | Peripheral / Mode |
| --- | --- | --- |
| OLED SDA | PB3 | I2C1_SDA |
| OLED SCL | PB2 | I2C1_SCL |
| 汇电籽-601 T/R | PA25/PA26 | UART3_RX/TX |
| 备选 MPU6050 | PA0/PA1 | I2C0 |
| TB6612 PWMA | PA12 | TIMG0_C0 |
| TB6612 PWMB | PA13 | TIMG0_C1 |
| TB6612 AIN1 | PA9 | GPIO |
| TB6612 AIN2 | PA8 | GPIO |
| TB6612 BIN1 | PA7 | GPIO |
| TB6612 BIN2 | PB18 | GPIO |
| TB6612 STBY | PB24 | GPIO |
| Encoder right | PA21 / PA22 | GPIO |
| Encoder left | PB19 / PB20 | GPIO |
| KEY1/KEY2 | PB6 / PB7 | GPIO |
| Pot | PA16 | ADC |
| Servo | PA27 | TIMG7_C1 |
| UART0 TX/RX | PA10 / PA11 | printf 115200 |
| LED | PA14 | GPIO |
| BEEP | PA15 | 低响 |
| KEY | PB6 / PB7 | GPIO |
| SWD | PA19 / PA20 | debug |

## 冲突与规则

- **禁止**沿用旧天猛星表（PB15/PB16 电机、PA10/PA11 OLED、PA10/PA11 MPU）。
- PA5/PA6 = 40MHz HFXT，禁止 GPIO。
- PA18 = BSL，编码器优先 PA21/PA22。
- 拓展板默认 **A=右 B=左**；详见 `expansion_board.md`。
- 小车与云台各用一片地猛星，见 `pins.md`。

## 建议工程结构

```
car_project/
├── main.c
├── motor.h / motor.c
├── encoder.h / encoder.c
├── oled.h / oled.c
├── mpu_port.* / imu601.*   # 按需
├── pid_ctrl.h / pid_ctrl.c
├── empty.syscfg
└── .vscode/c_cpp_properties.json
```

## SysConfig 清单

1. HFXT 40MHz
2. I2C1 OLED PB3/PB2
3. UART3 汇电籽-601 PA26/PA25 115200（默认 IMU）
3b. 备选才加 I2C0 MPU PA0/PA1
4. TIMG0 PWM PA12/PA13
5. GPIO 方向 + STBY
6. UART0 PA10/PA11
7. 默认已占用 UART3 给 601；泰山派通信另选口

```c
SYSCFG_DL_init();
DL_Timer_startCounter(PWMA_INST);
DL_GPIO_setPins(DC_MOTOR_STBY_PORT, DC_MOTOR_STBY_PIN);
```

算法见 `pid.md`，全表见 `pins.md`，烧录见 `tools.md`。


权威 SysConfig 见 `ref_24h4.md`。


GanWei 灰度：主控 DAT **悬浮输入（无上下拉）**，见 `gray_serial.md`。
