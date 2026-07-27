> 注：桌面 `24H_4` **已改为敢为串行 8 路**（PB8=DAT 悬浮, PB9=CLK）。旧五路并口废弃。

# 敢为(GanWei) 灰度辅助板 — 串行通信模块

> **最少接线方案**: 仅需 2 根 IO (CLK+DAT) + GND 即可读取 **8 路**灰度数字量（**8 路全用**于巡线，不是只抽 5 路）
> 中文名：**敢为**；旧 24H_4 五路并口 HUIDU 已废弃
> 辅助板自带 MSPM0L1306 MCU，内部完成 ADC 采样 + 施密特滞回自动校准 + Flash 掉电保存

---

## 一、系统架构

```
┌─────────────────────────────┐      ┌──────────────────────┐
│   MSPM0G3507 主控板         │      │  灰度辅助板 (M0V1.3)   │
│                             │      │  MSPM0L1306           │
│   PB9 (CLK)  ────────────── │ ──── │  PA3 (CLK, 输入)      │
│   PB8 (DAT)  ────────────── │ ──── │  PA4 (DAT, 输出)      │
│   GND        ────────────── │ ──── │  GND                  │
│                             │      │                       │
│   串口 PA10(TX) → VOFA+/PC /* 24H_4 DEBUG */  │      │  8路光电传感器         │
│   115200bps 调试输出         │      │  + 按键一键校准         │
│                             │      │  + Flash 掉电保存       │
└─────────────────────────────┘      └──────────────────────┘
```

**工作原理**: 辅助板内部用 MSPM0L1306 轮询 8 路光电传感器（3 根地址线选通 → ADC 采样），经过施密特滞回比较器二值化后存为 1 byte（bit0=通道1...bit7=通道8, 1=白/0=黑）。主控发 8 个 CLK 脉冲，辅助板在每个 CLK 上升沿将下一个 bit 放到 DAT 线上，主控在 CLK 低电平时采样 DAT 并拼成完整 byte。

---

## 二、辅助板侧（MSPM0L1306）

### 烧录及校准

辅助板固件位于 `MSPM0L1306辅助板源码/NO_MCU_BOARD/`，CCS 工程。烧录后辅助板自动开始工作。

**首次使用必须校准**（校准值存 Flash，掉电不丢失）：
1. 长按辅助板按键 4 秒 → LED 快闪，进入校准模式
2. 松手 → LED 变慢闪，等待黑场校准
3. 将传感器对准黑色赛道/黑线 → 短按一次 → LED 快闪 1 秒确认
4. 将传感器对准白色背景 → 短按一次 → LED 快闪 1 秒确认
5. 校准完成，辅助板自动恢复工作

### 辅助板串行引脚定义

| 辅助板引脚 | 方向 | 功能 |
|-----------|------|------|
| PA3 | INPUT | CLK，接收主控的时钟脉冲 |
| PA4 | OUTPUT | DAT，逐位输出 8 路灰度二值化结果 |

### 辅助板固件关键源码位置

| 文件 | 内容 |
|------|------|
| `empty.c:215-222` | 串行 CLK 中断响应，逐位输出 |
| `No_Mcu_Ganv_Grayscale_Sensor_Config.h` | 传感器结构体、GPIO 宏 |
| `No_Mcu_Ganv_Grayscale_Sensor.c` | ADC 采样、二值化、施密特滞回 |
| `flash.c` | 校准值 Flash 存取 |

---

## 三、主控侧（MSPM0G3507）

### SysConfig 配置（主控侧，铁律）

在 CCS 中打开 `.syscfg`，添加 Serial 引脚组：

```
ADD → GPIO → Name: "Serial" → 添加 2 个 pin:
  Pin 0: Name="DAT", Pin="PB8"(或用户指定), Direction="Input"
         Internal Resistor = NONE / 无 / 不启用上下拉   ← 【悬浮输入，必须】
  Pin 1: Name="CLK", Pin="PB9"(或用户指定), Direction="Output", Initial=LOW
```

#### ⚠️ DAT 必须悬浮输入（无内部上下拉）

| 脚 | 方向 | 内部电阻 | 原因 |
|----|------|----------|------|
| **DAT（主控）** | **Input** | **NONE（悬浮）** | 辅助板 PA4 推挽驱动 DAT；主控若上拉/下拉会顶牛或采样错误 |
| **CLK（主控）** | Output | 无（输出） | 主控产生时钟 |
| 辅助板 PA3 CLK | Input | 例程默认无上下拉 | 收主控时钟 |
| 辅助板 PA4 DAT | Output | — | 逐 bit 输出 |

官方 `辅助板MSPM0G3507串行例程` 生成代码即为：

```c
DL_GPIO_initDigitalInput(Serial_DAT_IOMUX);   /* 无 RESISTOR → 悬浮 */
DL_GPIO_initDigitalOutput(Serial_CLK_IOMUX);
```

等价手动写法：

```c
DL_GPIO_initDigitalInputFeatures(Serial_DAT_IOMUX,
    DL_GPIO_INVERSION_DISABLE,
    DL_GPIO_RESISTOR_NONE,          /* 禁止 PULL_UP / PULL_DOWN */
    DL_GPIO_HYSTERESIS_DISABLE,
    DL_GPIO_WAKEUP_DISABLE);
```

**禁止**：给 DAT 配 `PULL_UP` / `PULL_DOWN`；禁止把 DAT 配成 Open-Drain 却不上拉。

SysConfig 生成后 `ti_msp_dl_config.h` 示例（脚可换，电阻策略不变）：

```c
#define Serial_PORT      (GPIOB)
#define Serial_DAT_PIN   (DL_GPIO_PIN_8)
#define Serial_DAT_IOMUX (IOMUX_PINCM25)
#define Serial_CLK_PIN   (DL_GPIO_PIN_9)
#define Serial_CLK_IOMUX (IOMUX_PINCM26)
```

### SysConfig 精简模板（仅外设部分）

如果从已有工程（如 24H_4）替换旧 HUIDU，只需：
1. 删除旧 HUIDU 的 GPIO 组（PA17/PB8/PB9/PA24/PA2）
2. 删除旧 ADC 循迹通道（如果之前用的是 ADC 直采模式）
3. 新增 Serial GPIO 组：**DAT=Input+无上下拉（悬浮）**，CLK=Output

**注意**：如果旧工程中 PB8/PB9 已被其它外设占用，先解除冲突或改选空闲脚。详见第五节。

### 主控读取代码

```c
#include "ti_msp_dl_config.h"

/*
 * 从 GanWei 灰度辅助板读取 8 路数字量（串行通信）
 * 返回: byte 中 bit0=通道1, bit1=通道2, ..., bit7=通道8
 *       1 = 白色区域, 0 = 黑色区域
 *
 * 时序: CLK 上升沿触发辅助板更新 DAT, CLK 下降沿后主控采样
 * 一次完整读取 8 路耗时约 80μs (8×10μs@32MHz)
 */
uint8_t gw_gray_serial_read(void)
{
    uint8_t ret = 0;

    DL_GPIO_clearPins(Serial_PORT, Serial_CLK_PIN);
    for (int i = 0; i < 8; ++i) {
        /* CLK 上升沿 → 辅助板输出下一个 bit 到 DAT */
        DL_GPIO_setPins(Serial_PORT, Serial_CLK_PIN);
        delay_us(5);  // 等待辅助板输出稳定（≥5μs）

        /* CLK 下降沿 → 主控读取 DAT 电平 */
        DL_GPIO_clearPins(Serial_PORT, Serial_CLK_PIN);
        delay_us(1);  // 等待 DAT 建立

        /* 读取 DAT 并拼入 bit i */
        ret |= (DL_GPIO_readPins(Serial_PORT, Serial_DAT_PIN) ? 1 : 0) << i;
    }
    return ret;
}
```

### 使用示例：主控主循环

```c
unsigned char grayscale_byte;
unsigned char rx_buff[256] = {0};

int main(void)
{
    SYSCFG_DL_init();
    Tick_delay(100);  // 等待辅助板起振

    while (1) {
        grayscale_byte = gw_gray_serial_read();

        // 8 路二值化结果: bit0~bit7 → 通道1~通道8
        uint8_t s0 = (grayscale_byte >> 0) & 0x01;  // 通道1
        uint8_t s1 = (grayscale_byte >> 1) & 0x01;  // 通道2
        uint8_t s2 = (grayscale_byte >> 2) & 0x01;  // 通道3
        uint8_t s3 = (grayscale_byte >> 3) & 0x01;  // 通道4
        uint8_t s4 = (grayscale_byte >> 4) & 0x01;  // 通道5
        uint8_t s5 = (grayscale_byte >> 5) & 0x01;  // 通道6
        uint8_t s6 = (grayscale_byte >> 6) & 0x01;  // 通道7
        uint8_t s7 = (grayscale_byte >> 7) & 0x01;  // 通道8

        // 循迹算法: 找到黑线的加权质心位置
        // (1=白, 0=黑, 所以用 !取反 后作为黑线权重)
        int weights[8] = {-35, -25, -15, -5, 5, 15, 25, 35};
        int sum_weight = 0, sum_pos = 0;
        for (int i = 0; i < 8; i++) {
            int is_black = !((grayscale_byte >> i) & 0x01);
            sum_pos   += is_black * weights[i];
            sum_weight += is_black;
        }
        // 黑线质心偏移: 负数=偏左, 正数=偏右, 0=居中
        float line_error = (sum_weight > 0) ? (float)sum_pos / sum_weight : 0;

        // 调试输出 (PA10/TX, 115200bps)
        sprintf((char *)rx_buff,
            "Gray %d-%d-%d-%d-%d-%d-%d-%d  Err:%d\r\n",
            s0, s1, s2, s3, s4, s5, s6, s7, (int)line_error);
        uart0_send_string((char *)rx_buff);
        memset(rx_buff, 0, 256);

        Tick_delay(10);  // 10ms 一次即可
    }
}
```

### 最小 CCS 工程文件清单

以下是由 `GanWei_MSPM0_AutoCalibration`（ADC+校准版）改造成串行版时需要保留/修改的文件：

| 文件 | 操作 |
|------|------|
| `empty.syscfg` | 删除 ADC12/DMA/Gray_Address/GRAY_IN 组，只保留 Serial(DAT/CLK)+UART+SysTick |
| `empty.c` | 删除传感器驱动代码，写入 `gw_gray_serial_read()` + 循迹算法 |
| `uart.c / uart.h` | 保留（串口调试输出） |
| `delay.c / delay.h` | 保留（SysTick 1ms + delay_us） |
| `No_Mcu_Ganv_Grayscale_Sensor_Config.h` | 仅保 `No_MCU_Sensor` 结构体定义（主控不用），可删但保留兼容旧 .o |
| `No_Mcu_Ganv_Grayscale_Sensor.c` | 不需要，可从编译排除 |
| `flash.c / flash.h` | 不需要，可从编译排除 |
| `led.c / led.h` | 不需要，可从编译排除 |
| `key.c / key.h` | 不需要，可从编译排除 |
| `adc.c / adc.h` | 不需要，可从编译排除 |

---

## 四、协议时序图

```
CLK (PB9→PA3):  ─┐   ┌───┐   ┌───┐   ┌───┐          ┌───┐
                  │   │   │   │   │   │   │          │   │
                 ─┘   ┘   └───┘   └───┘   └── ... ──┘   └──
                        ↑               ↑
DAT (PA4→PB8):  ────────X───────────────X── ... ───X───────
                    bit0输出          bit1输出        bit7输出

图例:  ─┐上升沿: 辅助板锁存当前通道数据并输出到 DAT
        ─┘下降沿: 主控在此时读取 DAT 电平，拼入返回 byte
```

- **频率上限**: 约 100kHz，实际用 5μs 半周期（100kHz）稳定可靠
- **一次读取**: 8 周期 ≈ 80μs，不影响主循环实时性
- **空闲状态**: CLK 保持低电平，DAT 保持上次最后输出的 bit

---

## 五、引脚冲突与解决方案

### 默认冲突

PB8 和 PB9 在 MSPM0G3507 上有多个复用功能：

| 引脚 | 冲突外设 | 说明 |
|------|---------|------|
| PB8 | **TIMA0_CH0** (舵机1) | 旧板/其它方案舵机脚；地猛星小车舵机默认 PA27，PB8/PB9 在接线图为灰度左/中 |
| PB9 | **TIMA0_CH1** (舵机2) | 旧板/其它方案舵机脚；地猛星小车舵机默认 PA27，PB8/PB9 在接线图为灰度左/中 |
| PB8 | SPI1_PICO | |
| PB9 | SPI1_SCK | |

### 解决方案

**询问用户实际硬件接线后选择**：

1. **如果不需要舵机** — PB8/PB9 直接用于 Serial DAT/CLK，无需改动
2. **如果舵机需要 TIMA0_CH0/CH1** — 将 Serial 移到其他空闲 GPIO：
   - CLK → 任意 GPIO Output
   - DAT → 任意 GPIO Input
   - 例如：CLK=PA22, DAT=PA24（前提是这些引脚空闲）
3. **保留 PB8/PB9 为 Serial，舵机改用其他 TIMA0 通道**：
   - TIMA0 还有 C2(PA10)、C3(PA12) 等通道
   - 也可以改用 TIMG12 的 PWM 模式驱动舵机

### 在 SysConfig 中迁移引脚

SysConfig 的可视化引脚分配器会自动检测冲突。如果 PB8/PB9 已被占用，按以下步骤迁移：

```
1. 删除原 GPIO 组中占用的 pin
2. 新建 Serial GPIO 组，选择空闲引脚
3. 更新代码中的 Serial_CLK_PIN / Serial_DAT_PIN 宏引用
```

---

## 六、与其它灰度方案的对比

| | 串行通信 (本文) | 8路 GPIO 直读 | ADC 直采 | 5路并口 (旧 HUIDU) |
|---|---|---|---|---|
| **线数** | 2 根 | 8 根 | 4 根 (3地址+1ADC) | 5 根 |
| **通道数** | 8 路 | 8 路 | 8 路 | 5 路 |
| **精度** | 0/1 二值 | 0/1 二值 | 12-bit ADC 值 | 0/1 二值 |
| **滞回防抖** | 有 (施密特) | 可软件实现 | 可软件实现 | 无 |
| **阈值调节** | 按键一键校准 | 软件阈值 | 按键一键校准 | 拧电位器 |
| **掉电保存** | Flash 自动 | 需自己实现 | Flash 自动 | 无 |
| **CPU 负载** | 极低 (80μs/次) | 极低 (GPIO读) | 中等 (DMA+ADC) | 极低 (GPIO读) |
| **适用场景** | 循迹比赛，引脚紧张 | 快速巡线 | 精细位置插值 | 简单巡线 |
| **辅助板固件** | 需要 | 不需要 | 不需要 | 不需要 |

---

## 七、完整集成示例

### 从旧 HUIDU 迁移到 GanWei 串行的步骤

以 24H_4 的五路 HUIDU 工程为例：

**1. SysConfig 改动** (`empty.syscfg`)：
- 删除 GPIO4 "HUIDU" 组（L2/L1/M/R1/R2 五个引脚）
- 删除 ADC12 "xuanniu" 组（如果之前用于循迹 ADC）
- 新增 GPIO "Serial" 组（DAT=PB8 IN, CLK=PB9 OUT）
- 引用冲突检查：确保 PB8/PB9 未同时配置为其他功能

**2. 代码改动** (`main.c` 或 `huidu.c`)：
- 删除旧 `huidu_get_value()` 中 5 个 GPIO 读取
- 用 `gw_gray_serial_read()` 替换
- 调整循迹算法以适应 8 路（增加 3 个中间通道的权重）
- 5 路权重参考：`{-35,-25,-15,-5,5,15,25,35}` → 5 路映射：`{-25,-15,0,15,25}` — 两种算法结构相同，只是通道数不同

**3. 编译排除旧文件**：
将 `huidu.c` 替换为新文件 `gray_serial.c`，在 CCS 中右键旧文件 → Exclude from Build

**4. 硬件接线改动**：
```
旧接线 (5根):                      新接线 (2根):
  PA17 ← L2                       [释放，空闲]
  PB8  ← L1  ─┐                  PB9 (CLK) → 辅助板 PA3
  PB9  ← M   ─┤─→ 替换为 ──→     PB8 (DAT) ← 辅助板 PA4
  PA24 ← R1   │                  GND ─────── 辅助板 GND
  PA2  ← R2  ─┘                  [PA2, PA17, PA24 释放，空闲]
```

---

## 八、常见问题排查

| 现象 | 可能原因 | 解决方案 |
|------|---------|---------|
| 读取全 0x00 或全 0xFF | 辅助板未校准 | 按第二节步骤校准辅助板 |
| 读取全 0x00 | DAT 线上拉缺失 | 辅助板 PA4 已配置为推挽输出，检查接触 |
| 读取全 0xFF | CLK 未输出或接触不良 | 用示波器确认 PB9 有方波输出 |
| 数据闪烁、跳变 | CLK 频率过高或 delay_us 不足 | 增加 delay_us 到 10μs |
| VOFA+ 无输出 | 串口波特率不匹配 | 确认 UART 配置为 115200bps |
| 辅助板不响应 | 辅助板未上电或固件未烧录 | 确认辅助板供电，LED 指示正常 |
| 校准后仍误判 | 场地光线变化大 | 建议在赛道实际光照下重新校准 |

---

## 九、相关资源

- 辅助板固件: `MSPM0L1306辅助板源码/NO_MCU_BOARD/` (CCS 工程, 芯片 MSPM0L1306)
- 辅助板硬件: `灰度辅助板M0V1.3硬件开源_立创EDA专业版.eprj` (立创 EDA 专业版打开)
- 主控串行例程 (Keil): `辅助板MSPM0G3507串行例程/examples/` (可参考逻辑)
- 主控 ADC+校准 CCS 工程: `GanWei_MSPM0_AutoCalibration/` (改为串行模式的工程)


---

## 24H_4 八路巡线映射（实机）

桌面工程 `24H_4` 已改为敢为串行：

| 项目 | 值 |
|------|-----|
| CLK | PB9 `Serial_CLK` Output |
| DAT | PB8 `Serial_DAT` Input **RESISTOR_NONE 悬浮** |
| `huidu_value[0..7]` | 左→右, **1=黑 0=白** |
| `adjust_motor_pwm` | 8 路全用分级 diff：内侧 ±20，次外 ±120，最外 ±600；base=900 |
| 到点/丢线 | `huidu_near_center` / `huidu_any_black` / `huidu_all_white` |

原理：串行读出哪一路（或哪几路）压黑线 → 改左右轮 PWM 差速 → 车沿黑线循迹。整体效果量级贴近原五路。
