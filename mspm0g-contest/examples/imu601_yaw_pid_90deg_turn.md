# 汇电籽-601 Yaw PID 原地转向示例

Board: **立创·地猛星 MSPM0G3507**  
IMU: **汇电籽-601**（默认，协议见 `imu601.md`）

## 硬件

| 功能 | 连接 |
|------|------|
| 汇电籽-601 V | **5V** |
| 汇电籽-601 G | GND |
| 汇电籽-601 T (TX) | **PA25** UART3_RX |
| 汇电籽-601 R (RX) | **PA26** UART3_TX |
| OLED | I2C1 PB3/PB2 |
| printf | UART0 PA10/PA11 |
| 电机 | TIMG0 PA12/PA13 + AIN1=PA9 AIN2=PA8 BIN1=PA7 BIN2=PB18 + STBY PB24 |

## 协议（不要用旧 ATKP）

- 帧头 **`AA 55`**，设备 ID **`0x60`**，115200 8N1
- 校验：`(ID+CMD+LEN+DATA)&0xFF`
- 仅姿态：`CMD=0x01 LEN=06`，DATA=`[Yaw,Pitch,Roll]` 小端，÷100
- Yaw = **uint16 → 0~360°**
- 初始化建议：`0x12` 软复位 → `0x0B 01` 仅姿态 → `0x0A 01` 启动上报
- 校零：`0x10` 或软件减 yaw0

## SysConfig

- UART3：TX=PA26，RX=PA25，115200，RX 中断
- I2C1 OLED；TIMG0 电机；GPIO 方向/STBY

## 控制要点

```c
err = wrap180(target_yaw - current_yaw);  /* 先统一到 ±180 误差 */
out = Kp*err + Ki*i - Kd*gyroZ;           /* gyroZ 需全数据模式 */
left = +pwm; right = -pwm;                /* 原地转；反了就反号 */
/* 停稳: |err|<3° 且角速度小，连续 N 拍 */
```

- A/B 与左右轮问用户
- 先抬轮；静止校准后再转
- ISR 只收字节，主循环解析

完整协议与指令表：`imu601.md`。
