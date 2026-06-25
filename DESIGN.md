# 智能答题 App — 工作流 & 设计方案

## 功能总览

```
┌─────────────────────────────────────────────┐
│              智能答题 App                     │
├──────────────────┬──────────────────────────┤
│   📷 拍照搜题     │   🎬 录屏悬浮搜题         │
│                  │                          │
│  相机取景框       │  开启录屏 → 悬浮窗         │
│  ↓               │  ↓                       │
│  拍照/选图        │  实时截屏识别              │
│  ↓               │  ↓                       │
│  OCR识别题目      │  OCR识别题目              │
│  ↓               │  ↓                       │
│  DeepSeek API    │  DeepSeek API            │
│  ↓               │  ↓                       │
│  显示答案         │  悬浮窗显示答案            │
└──────────────────┴──────────────────────────┘
```

## 技术架构

```
┌─────────────────────────────────────────────┐
│                  SwiftUI                     │
├─────────────────────────────────────────────┤
│  主页面 (TabView)                            │
│  ├── 📷 拍照搜题页                            │
│  │   └── AVFoundation (相机)                 │
│  │   └── Vision (OCR)                       │
│  │                                          │
│  ├── 🎬 录屏搜题页                            │
│  │   └── ReplayKit (屏幕录制)                │
│  │   └── Broadcast Upload Extension         │
│  │   └── 悬浮窗 (UIWindow level)             │
│  │                                          │
│  └── ⚙️ 设置页                               │
│      └── API Key 配置                        │
│      └── 悬浮窗样式设置                       │
├─────────────────────────────────────────────┤
│  网络层                                      │
│  └── DeepSeek API (chat/completions)        │
├─────────────────────────────────────────────┤
│  平台: iOS 15.0+                            │
│  安装: TrollStore (免签名)                    │
└─────────────────────────────────────────────┘
```

## 页面结构

### 1. 主页 (TabView)
- 底部两个Tab: 📷 拍照搜题 | 🎬 录屏搜题
- 顶部Logo + App名称

### 2. 拍照搜题页
- 全屏相机预览
- 底部: 拍照按钮 + 相册选择按钮
- 拍照后 → 识别中动画 → 答案卡片弹出

### 3. 录屏搜题页
- 说明卡片: 如何开启录屏
- 一键启动按钮
- 悬浮窗: 半透明圆角卡片，可拖动

### 4. 设置页
- API Key 输入框
- 悬浮窗大小/透明度调节
- 历史记录

## 色彩方案 (iOS 26 风格)

```
主色: #0A84FF (亮蓝)
辅色: #30D158 (翠绿)
强调: #FF9F0A (暖橙)
背景: #F2F2F7 (浅灰)
卡片: #FFFFFF (白)
文字: #1C1C1E (深黑)
次要文字: #8E8E93 (灰)
```

## 编译 & 安装流程

```
1. 编写 Swift 源码
       ↓
2. GitHub Actions (macOS runner + Xcode)
       ↓
3. xcodebuild 编译 .app
       ↓
4. 打包成 .ipa
       ↓
5. 下载 → TrollStore 安装
```

## 文件结构

```
SmartAnswer/
├── SmartAnswer.xcodeproj/
├── SmartAnswer/
│   ├── App.swift                 # 入口
│   ├── ContentView.swift         # 主TabView
│   ├── Views/
│   │   ├── CameraSearchView.swift    # 拍照搜题
│   │   ├── ScreenSearchView.swift    # 录屏搜题
│   │   ├── SettingsView.swift        # 设置
│   │   ├── AnswerCard.swift          # 答案卡片组件
│   │   └── FloatingWindow.swift      # 悬浮窗
│   ├── Services/
│   │   ├── DeepSeekService.swift     # API调用
│   │   ├── OCRService.swift          # OCR识别
│   │   └── ScreenCaptureService.swift # 屏幕截取
│   ├── Models/
│   │   └── Question.swift            # 数据模型
│   └── Assets.xcassets/
├── ScreenExtension/              # Broadcast Upload Extension
│   └── SampleHandler.swift
└── .github/
    └── workflows/
        └── build.yml
```

## 开发步骤

| 步骤 | 内容 | 预计时间 |
|------|------|---------|
| 1 | 创建Xcode项目结构 | 10min |
| 2 | 实现主页TabView + UI | 15min |
| 3 | 实现DeepSeek API调用 | 10min |
| 4 | 实现拍照搜题 (相机+OCR) | 20min |
| 5 | 实现录屏搜题 (ReplayKit+悬浮窗) | 30min |
| 6 | 设置页 | 10min |
| 7 | GitHub Actions编译 | 15min |
| 8 | 打包IPA + 测试 | 10min |
| **总计** | | **约2小时** |
