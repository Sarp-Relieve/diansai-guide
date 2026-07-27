# 电赛指北 — 全国大学生电子设计竞赛全栈资料库

> 立创·地猛星 MSPM0G3507 + 泰山派 RK3566 双芯架构，从硬件接线到 AI 部署的完整竞赛指南。

---

## 这是什么？

一套面向**全国大学生电子设计竞赛控制类题目**的开源资料库，包含：

- 硬件接线、模块选型与避坑指南
- MSPM0G3507 外设驱动与引脚映射（Claude Code Skill）
- 电赛技术报告自动写作（Claude Code Skill）
- YOLO 视觉训练与泰山派部署流程

无论你是第一次参加电赛，还是想换用 MSPM0G 平台的老选手，这里都有你需要的。

---

## 目录结构

```
├── README.md                           # 你现在看的东西
├── guide/                              # 竞赛指南（硬件接线、模块、训练、AI）
│   ├── README.md                       # 指南目录
│   ├── images/                         # 接线原理图等图片
│   └── ...（内容文件）
├── mspm0g-contest/                     # Claude Code Skill：MSPM0G 开发助手
│   ├── SKILL.md                        # Skill 主文件
│   ├── pins.md                         # 引脚映射表（I2C/SPI/UART/PWM/GPIO）
│   ├── pwm.md                          # PWM 电机/舵机驱动例程
│   ├── adc.md                          # ADC 采样
│   ├── i2c.md / uart.md                # 通信协议
│   ├── imu601.md                       # 汇电籽 601 陀螺仪
│   ├── gray_serial.md                  # 敢为八路灰度模块（串行/GPIO）
│   ├── encoder.md                      # 编码器
│   ├── pid.md                          # PID 控制 + VOFA+ 调试
│   ├── pid_tuner_protocol.md           # PID 在线调参协议
│   ├── expansion_board.md              # 拓展板接线
│   ├── taishan_pai.md                  # 泰山派视觉模块
│   ├── tools.md                        # 工具链（烧录/环境配置）
│   ├── contest.md                      # 电赛真题方案（25E/24H/23E）
│   ├── templates/                      # VS Code c_cpp_properties 模板
│   ├── examples/                       # 完整示例代码
│   └── references/                     # 泰山派参考文档
└── 电赛报告/                            # Claude Code Skill：电赛技术报告写作
    ├── SKILL.md                         # Skill 主文件
    ├── scripts/md_to_docx.py           # MD 转 Word 脚本
    ├── templates/report_outline.md      # 报告大纲模板
    └── references/                      # 写作规范与硬件参考
```

---

## 快速开始

### 1. 使用 Skill

两个 skill 放入 Claude Code 的 skills 目录即可：

```bash
# 克隆仓库
git clone https://github.com/Sarp-Relieve/diansai-guide.git

# 复制 skill 到 Claude Code 配置目录
cp -r diansai-guide/mspm0g-contest ~/.claude/skills/
cp -r diansai-guide/电赛报告 ~/.claude/skills/
```

重启 Claude Code 后，两个 skill 自动生效：
- 写 MSPM0G 代码时自动调用 `mspm0g-contest`
- 写技术报告时说"写电赛报告"触发 `电赛报告`

### 2. 浏览竞赛指南

进入 `guide/` 目录查看完整竞赛指南，涵盖从接线到 AI 部署的全流程。

---

## 硬件平台

| 模块 | 型号 | 备注 |
|------|------|------|
| 主控 | 立创·地猛星 MSPM0G3507 | 双板架构（小车+云台各一片） |
| 视觉 | 泰山派 RK3566 | OpenCV / YOLO |
| 电机驱动 | TB6612 / AT8236 | 310 / 513 电机 |
| 陀螺仪 | 汇电籽 601（ICM42688）/ MPU6500 | 串口 / I2C |
| 灰度 | 敢为八路 | 串行 / GPIO |
| 舵机 | MR996R | PWM |

---

## 相关链接

- [地猛星购买](https://item.szlcsc.com/24478333.html)
- [MSPM0 烧录工具](https://wiki.lckfb.com/storage/html/mspm0-web-flasher/index.html)
