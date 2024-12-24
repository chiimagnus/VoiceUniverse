# VoiceVerse

VoiceVerse是一款macOS平台的PDF阅读器，具有文本朗读功能，让您的阅读体验更加丰富。

## 1. 功能特点

- 📖 PDF文档查看
- 🔊 中文文本朗读
- 🎯 朗读文本自动高亮
- ⌨️ 快捷键支持
- [ ] 🖱️ 点击朗读选中文本

## 2. 使用说明

### 基本操作
- 打开PDF：Command + O
- 自动调整大小：Command + R
- 放大：Command + +
- 缩小：Command + -
- 实际大小：Command + 0

### 页面导航
- 下一页：Command + →
- 上一页：Command + ←

### 朗读控制
- 开始/暂停朗读：点击工具栏播放按钮
- 停止朗读：点击工具栏停止按钮
- 点击文本：朗读选中段落

### 显示模式
- 单页
- 单页连续
- 双页
- 双页连续

## 代码说明
- ContentView.swift：主视图，负责整体布局和组件组织，包含工具栏和PDF阅读区域。

- HighlightView.swift：高亮管理器，负责PDF文本的高亮显示功能，包括查找文本、添加高亮、移除高亮等操作。当朗读时会自动高亮当前朗读的句子。

- PDFViewerView.swift：PDF查看器视图，封装了PDFKit的PDFView，提供PDF文档的基本显示和交互功能，如缩放、翻页等。

- SentenceManager.swift：句子管理器，负责将PDF文本分割成句子，并管理当前朗读的句子位置。提供获取下一句、上一句等功能。

- SpeechManager.swift：语音管理器，负责文本朗读功能，使用macOS的语音合成引擎将文本转换为语音，支持暂停、继续、停止等控制。

- VoiceVerseApp.swift：应用程序入口，负责初始化应用程序和配置主窗口。


## 致谢

