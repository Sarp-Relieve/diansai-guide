# 泰山派 RK3566 视觉方案

> **视觉上位机**: 立创·泰山派 RK3566 — Linux 系统, OpenCV + 传统视觉优先, 通过 UART 与 MSPM0G3507 通信
> Skill 来源: [Taishan-RK3566-Skill](https://github.com/1nuoiscute/Taishan-RK3566-Skill) v1.1.0

---

## 一、双芯架构总览

```
┌──────────────────────────────┐      UART        ┌─────────────────────────┐
│  泰山派 RK3566 (视觉大脑)      │ ←─────────────→ │  MSPM0G3507 (控制核心)    │
│                              │   TX/RX + GND    │                         │
│  OpenCV 传统视觉 / RKNN 推理  │                  │  巡线 / 电机 PID / 舵机   │
│  坐标计算 / 目标跟踪           │                  │  编码器 / 汇电籽-601 / OLED  │
│  Linux (Ubuntu/OpenKylin)    │                  │  传感器采集 / 安全控制     │
└──────────────────────────────┘                  └─────────────────────────┘
```

**职责边界**:
- 泰山派: 视觉处理、坐标/误差计算、决策逻辑、UART 发送目标位置
- MSPM0G: 巡线、电机控制、编码器、舵机、传感器采集、安全急停
- **UART 仅传递已确认的视觉结果, 不传递原始图像或未确认指令**

---

## 二、硬件连接

### UART 通信 (必需)

MSPM0G 侧引脚由用户实际接线确认, 常用方案:

| 方案 | MSPM0G 引脚 | 说明 |
|------|-----------|------|
| 空闲 UART | 由用户指定 | 地猛星小车：PB2/PB3 为 OLED I2C1，不可占；printf 常用 PA10/PA11（24H_4 DEBUG），汇电籽-601 占用 UART3 PA26/PA25。泰山派通信脚必须先问用户 |
| UART1 | PB6=RX, PB7=TX | 若 PB2/PB3 被编码器占用则备用 |
| UART2 | PA22=RX, PA23=TX | 需确认 PA23 为 VREF+ 是否可用 |

**泰山派侧**: 通过 40Pin 排针的 UART 接口引出, 具体 TX/RX 引脚由板端 `gpioinfo` 和设备树确定, 不写死。

### 供电

| 设备 | 供电 | 说明 |
|------|------|------|
| 泰山派 | 5V Type-C | 独立供电, 与动力电池隔离 |
| MSPM0G | 7.4V → 3.3V LDO | 动力电池 |
| 共地 | GND | **必须共地**, 否则 UART 通信失败 |

---

## 三、泰山派开发环境

### VS Code Remote-SSH

推荐开发方式: VS Code Remote-SSH 直连泰山派 Linux。代码编辑在 VS Code 中完成, 实际文件、编译和运行均在泰山派板端。

### 板端环境探测

首次使用或新刷镜像后, 运行基础探针:

```bash
# 系统信息
cat /etc/os-release && uname -a && uname -m

# 摄像头
ls -l /dev/video* /dev/media* 2>/dev/null
v4l2-ctl --list-devices 2>/dev/null

# OpenCV
python3 -c "import cv2; print('OpenCV', cv2.__version__)"

# UART 设备
ls -l /dev/ttyS* /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# GPIO
gpioinfo 2>/dev/null || true
```

详细探测流程见 `references/taishan-board.md`。

### Codex 可访问性边界

**重要**: VS Code Remote-SSH 让 VS Code 在板端工作, 但 Codex 不一定能直接执行板端命令。如果 Codex 只连接用户电脑:

1. 不能声称已运行板端脚本或读取板端日志
2. 输出用户可复制到 Remote-SSH 终端的完整命令
3. 要求用户返回输出文件/文本/截图后再更新"实板已验证"结论

---

## 四、UART 通信协议 (MSPM0G ↔ 泰山派)

### 协议设计原则

- **先确认题目需求再定协议**: 不要默认加入序号、ACK、心跳、重发
- **最小化帧内容**: 只传视觉处理后的目标坐标/误差, 不传原始图像
- **波特率从低开始**: 如 9600 或 115200, 实测稳定后再提速

### 帧协议模板 (按题目调整)

```
帧头 2B + 数据区 + 校验 1B

示例 (云台瞄准):
  0xFF 0xFE  Pan_H  Pan_L  Tilt_H  Tilt_L  0x00  0x00  BCC
  BCC = XOR(Byte0..Byte6)
  Pan: 0~180°, Tilt: 0~180° (或按实际舵机量程)
```

### MSPM0G 侧帧解析模板

```c
#define UART_BUF_SIZE 64
volatile uint8_t uart_rx_buf[UART_BUF_SIZE];
volatile uint8_t uart_rx_idx = 0;

// UART RX 中断中将数据填入环形缓冲区
// 主循环中解析帧:
void parse_vision_frame(void) {
    // 查找帧头 0xFF 0xFE
    // 验证 BCC
    // 提取 pan/tilt → 更新舵机目标
}
```

### 协议确认清单

使用 `templates/serial-protocol-decision.md` (来自泰山派 skill) 逐项确认:

- [ ] 帧头字节数
- [ ] 数据区含义和单位
- [ ] 是否需要序号/ACK/心跳
- [ ] 校验方式
- [ ] 超时处理
- [ ] 丢失目标时的默认值

---

## 五、视觉方案选择

泰山派优先使用 OpenCV 传统视觉, 推荐路线:

| 题目类型 | 推荐方法 | 是否需要模型 |
|---------|---------|------------|
| 颜色区域识别 | HSV/LAB 颜色分割 + findContours | 否 |
| 光斑定位 | 阈值分割 + 质心计算 | 否 |
| 直线/矩形/圆检测 | Canny + HoughLines/HoughCircles | 否 |
| 编码标记/二维码 | findContours + 几何判断 / zbar | 否 |
| 物体分类 | 需要时才走 RKNN 模型推理 | 仅在传统方法失败时 |

详细信息见 `references/taishan-vision-tasks.md`。

---

## 六、完整工程参考

| 参考资料 | 位置 |
|---------|------|
| 泰山派 skill 入口 | [SKILL.md](https://github.com/1nuoiscute/Taishan-RK3566-Skill/blob/main/SKILL.md) |
| 板端环境发现 | `references/taishan-board.md` |
| 视觉任务分类 | `references/taishan-vision-tasks.md` |
| 工程架构 | `references/taishan-arch.md` |
| 资料索引 | `references/taishan-source-index.md` |
| 泰山派官方 Wiki | https://wiki.lckfb.com/zh-hans/tspi-rk3566/ |
| IO 分配表 | https://wiki.lckfb.com/zh-hans/tspi-rk3566/documentation/io-allocation-table.html |

---

## 七、已知注意事项

1. **不要凭 `GPIOx_y` 推导 Linux GPIO 编号**, 必须在板端用 `gpioinfo` 确认
2. **不要假设 `/dev/video0` 就是摄像头**, 用 `v4l2-ctl --list-devices` 确认
3. **不要在未知波特率时生成完整串口协议**, 先确认对端配置
4. **先做单帧采集验证再做闭环联调**, 每轮只改变一个变量
5. **桌面电脑的 FPS 不能代表板端性能**, 必须在目标板实测
6. **MSPM0G 负责电机/巡线/舵机等底层控制, 泰山派不直接控制执行机构**
