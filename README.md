<h1 align="center">
    🎉 VoiceVerse
</h1>

<div align="center">
    <a href="readme.md">中文</a> | <a href="readme_en.md">English</a>
</div>

VoiceVerse是一款macOS平台的PDF阅读器，能够*文本朗读*和*PDF高亮*。

## 1. 功能特点
- 🎯 朗读文本自动高亮🌟
- 🔊 文本朗读
- 🔍 文本跳转
- ⌨️ 快捷键支持
- [ ] 人声朗读API调用

## 2. 使用说明
### 基本操作
- 打开PDF：Command + o

### 页面导航
- 下一页：Command + →
- 上一页：Command + ←
- 下一句：→

## 3.技术文档
- VoiceVerseApp.swift：应用程序入口，负责初始化应用程序和配置主窗口。提供统一的菜单命令支持，包括文件操作、视图控制和页面导航等功能。

- ContentView.swift：主视图容器，负责整体布局和组件组织。集成了PDF查看器、工具栏和进度条，处理文件导入和基本交互逻辑。

- PDFViewerView.swift：PDF阅读器核心组件，封装PDFKit的PDFView。提供以下功能：
  - PDF文档显示和交互（缩放、翻页、滚动）
  - 页面布局控制（单页、双页、连续模式等）
  - 进度条显示和跳转功能
  - 与语音朗读系统的集成

- SentenceManager.swift：句子管理器，负责文本处理和朗读控制：
  - 智能分句处理
  - 句子导航（上一句、下一句）
  - 多页面文本管理
  - 朗读进度跟踪

- SpeechManager.swift：语音合成管理器，负责文本朗读功能：
  - 基于 AVSpeechSynthesizer 的文本朗读
  - 朗读控制（播放、暂停、继续、停止）
  - 自动/手动朗读模式切换
  - 朗读状态管理和回调处理

- HighlightManager.swift：高亮显示管理器，负责文本高亮功能：
  - 精确文本定位和高亮
  - 多页面高亮同步
  - 高亮动画和滚动控制
  - 高亮状态管理和清理

- TextLocationManager.swift：PDF文本定位管理器，负责在PDF中精确定位和验证文本位置：
  - 文本分段：将长文本智能分割成多个片段，确保准确定位
  - 文本搜索：在PDF页面中搜索文本片段，支持当前页面及相邻页面搜索
  - 位置验证：验证找到的文本片段之间的位置关系，确保符合自然阅读顺序
  - 缓存管理：实现搜索结果缓存，提高重复搜索效率

## 4. 致谢


## 5. 赞助
[buymeacoffee](https://github.com/chiimagnus/logseq-AIsearch/blob/master/public/buymeacoffee.jpg)
<div align="center">
  <img src="https://github.com/chiimagnus/logseq-AIsearch/blob/master/public/buymeacoffee.jpg" width="400">
</div>