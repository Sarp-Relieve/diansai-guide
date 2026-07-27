# GPIO 输出/输入/中断

> **SDK 铁律: GPIO 方向/上下拉/中断全在 SysConfig 配置，代码只做运行时操作**

## SysConfig：LED + 蜂鸣器 BEEP（24H_4 默认，必须写）

小车默认声光提示口，**不要再把 PA15 写成外接 LED**。

```
ADD → GPIO → Name: LED_BEEP
  Pin0 Name=LED  Pin=PA14  Direction=Output  Initial=LOW   /* 高电平亮 */
  Pin1 Name=BEEP Pin=PA15  Direction=Output  Initial=SET   /* 低电平响，初值高=静音 */
```

| 信号 | 脚 | 极性 | API |
|------|-----|------|-----|
| **LED** | **PA14** | 高亮 | `led_on`=set，`led_off`=clear |
| **BEEP** | **PA15** | **低电平响** | `beep_on`=clear，`beep_off`=set |

```c
void led_on(void)   { DL_GPIO_setPins(LED_BEEP_PORT, LED_BEEP_LED_PIN); }
void led_off(void)  { DL_GPIO_clearPins(LED_BEEP_PORT, LED_BEEP_LED_PIN); }
void beep_on(void)  { DL_GPIO_clearPins(LED_BEEP_PORT, LED_BEEP_BEEP_PIN); } /* 低响 */
void beep_off(void) { DL_GPIO_setPins(LED_BEEP_PORT, LED_BEEP_BEEP_PIN); }
```

过点/停车提示：`led_on(); beep_on();` 后用计数延时再 `led_off(); beep_off();`（见 24H_4）。

## SysConfig 配置 GPIO 输入 (按键 KEY1/KEY2)

```
ADD → GPIO → Name: KEY
  KEY1 Pin=PB6 Direction=Input InternalResistor=PULL_DOWN Interrupt=Rising
  KEY2 Pin=PB7 Direction=Input InternalResistor=PULL_DOWN Interrupt=Rising
```

## 运行时代码

```c
// LED/BEEP — 见上；按键按下=高（Pull-down）
uint8_t key1 = (DL_GPIO_readPins(KEY_PORT, KEY_KEY1_PIN) != 0);
uint8_t key2 = (DL_GPIO_readPins(KEY_PORT, KEY_KEY2_PIN) != 0);
```

## GPIO 中断配置

```c
// SysConfig: PB6 → Input + Pull-down + Interrupt (Rising)
// NVIC 和中断函数自动生成, 只需使能
NVIC_EnableIRQ(KEY_INT_IRQN);

void GROUP1_IRQHandler(void) {
    uint32_t st = DL_GPIO_getEnabledInterruptStatus(GPIOB, DL_GPIO_PIN_6);
    if (st & DL_GPIO_PIN_6) {
        DL_GPIO_clearInterruptStatus(GPIOB, DL_GPIO_PIN_6);
        // 处理按键, 只置标志位, 不做耗时操作!
        g_key_flag = 1;
    }
}
```

## HC-SR04 超声波测距

```c
// 超声波脚由用户指定；PA8/PA9 在地猛星小车上是 TB6612 AIN1/AIN2，勿默认占用
// 原理: TRIG发10μs高脉冲 → ECHO回响高电平 → 计时高电平时长 → 距离=时间×0.017cm/μs

void hcsr04_init(void) {
    DL_GPIO_initDigitalOutput(GPIO_TRIG_IOMUX);   // PA8
    DL_GPIO_initDigitalInput(GPIO_ECHO_IOMUX);    // PA9
    DL_GPIO_clearPins(GPIOA, DL_GPIO_PIN_8);
}

float hcsr04_get_distance_cm(void) {
    // 发送 10μs 触发脉冲
    DL_GPIO_setPins(GPIOA, DL_GPIO_PIN_8);
    delay_us(10);
    DL_GPIO_clearPins(GPIOA, DL_GPIO_PIN_8);

    // 等待 ECHO 上升沿 (超时 30ms)
    uint32_t timeout = 30000;
    while (DL_GPIO_readPins(GPIOA, DL_GPIO_PIN_9) == 0) {
        if (--timeout == 0) return -1.0f;
    }

    // 计时高电平脉宽 (DWT 或定时器微秒计数)
    uint32_t start_us = micros();

    timeout = 30000;
    while (DL_GPIO_readPins(GPIOA, DL_GPIO_PIN_9) != 0) {
        if (--timeout == 0) return -1.0f;
    }

    uint32_t elapsed_us = micros() - start_us;
    return elapsed_us * 0.017f;  // 声速 340m/s → 0.017cm/μs (往返/2)
}

// 实现 micros() 用 SysTick 或 DWT:
uint32_t micros(void) {
    return g_ms_ticks * 1000 + (SystemCoreClock / 1000 - SysTick->VAL) / (SystemCoreClock / 1000000);
}
```

## 按键长按/短按/双击识别

```c
typedef struct {
    uint8_t  state;       // 0=空闲, 1=按下, 2=长按, 3=释放等待
    uint32_t press_ms;    // 按下时刻
    uint32_t release_ms;  // 释放时刻
    uint8_t  click_count;
    uint8_t  event;       // 0=无, 1=短按, 2=长按, 3=双击
} ButtonState;

#define LONG_PRESS_MS   800
#define DOUBLE_CLICK_MS 400

ButtonState btn = {0};

void button_tick(void) {
    uint8_t pressed = (DL_GPIO_readPins(GPIOA, DL_GPIO_PIN_25) == 0);
    uint32_t now = g_ms_ticks;

    switch (btn.state) {
    case 0: // 空闲
        if (pressed) { btn.state = 1; btn.press_ms = now; }
        break;
    case 1: // 按下
        if (!pressed) {
            btn.state = 3; btn.release_ms = now;
        } else if (now - btn.press_ms > LONG_PRESS_MS) {
            btn.state = 2; btn.event = 2; // 长按
        }
        break;
    case 2: // 长按
        if (!pressed) btn.state = 0;
        break;
    case 3: // 释放等待
        if (pressed) {
            btn.click_count++;
            if (btn.click_count >= 2) { btn.event = 3; btn.state = 0; } // 双击
            else { btn.state = 1; btn.press_ms = now; }
        } else if (now - btn.release_ms > DOUBLE_CLICK_MS) {
            btn.event = 1; btn.state = 0; // 短按
        }
        break;
    }
}
```


## 10 键板 + 旋钮（地猛星小车）

详见 `expansion_board.md`。

- SW9 → PB6，SW10 → PB7：Input + **Pull-down**，按下=高
- 旋钮滑臂 → PA16 ADC（例程 `xuanniu`）
- SW1~SW8 杜邦脚必须问用户


## GanWei 串行 DAT：悬浮输入（无上下拉）

主控读 GanWei 辅助板时，**DAT 必须是悬浮输入**，禁止内部上拉/下拉（官方串行例程：`DL_GPIO_initDigitalInput`，无 `RESISTOR`）。

```
Serial.DAT  Pin=PBxx  Direction=Input  Internal Resistor = NONE / 无 / 不勾选上下拉
Serial.CLK  Pin=PByy  Direction=Output Initial=LOW
```

```c
/* 正确：悬浮输入 */
DL_GPIO_initDigitalInput(Serial_DAT_IOMUX);
/* 或 */
DL_GPIO_initDigitalInputFeatures(Serial_DAT_IOMUX,
    DL_GPIO_INVERSION_DISABLE, DL_GPIO_RESISTOR_NONE,
    DL_GPIO_HYSTERESIS_DISABLE, DL_GPIO_WAKEUP_DISABLE);

/* 错误：不要 PULL_UP / PULL_DOWN —— 会与辅助板推挽 DAT 顶牛或读数全 1/0 */
```

完整时序与例程见 `gray_serial.md`。
