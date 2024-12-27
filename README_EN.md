<h1 align="center">
    🎉 VoiceVerse
</h1>

<div align="center">
    <a href="readme.md">中文</a> | <a href="readme_en.md">English</a>
</div>

VoiceVerse is a PDF reader for macOS that supports *text-to-speech* and *PDF highlighting*.

## 1. Features
- 🎯 Auto-highlighting of spoken text🌟
- 🔊 Text-to-speech
- ⌨️ Keyboard shortcuts
- 📍 Smart positioning of current reading location🌟
- [ ] Voice API integration

## 2. Usage Guide
### Basic Operations
- Open PDF: Command + o

### Page Navigation
- Next page: Command + →
- Previous page: Command + ←
- Next sentence: →

## 3. Technical Documentation
### Core Components

- VoiceVerseApp.swift: Application entry point, responsible for app initialization and main window configuration. Provides unified menu command support for file operations, view control, and page navigation.

- ContentView.swift: Main view container, responsible for overall layout and component organization. Integrates PDF viewer, toolbar, and progress bar, handles file import and basic interaction logic.

- PDFViewerView.swift: Core PDF reader component, encapsulating PDFKit's PDFView. Features include:
  - PDF document display and interaction (zoom, page turning, scrolling)
  - Page layout control (single page, two pages, continuous modes)
  - Progress bar display and navigation
  - Integration with speech synthesis system

- SentenceManager.swift: Sentence manager, handles text processing and reading control:
  - Intelligent sentence segmentation
  - Sentence navigation (previous/next)
  - Multi-page text management
  - Reading progress tracking

- SpeechManager.swift: Speech synthesis manager, responsible for text-to-speech functionality:
  - Text-to-speech based on AVSpeechSynthesizer
  - Reading control (play, pause, resume, stop)
  - Automatic/manual reading mode switching
  - Speech status management and callback handling

- HighlightManager.swift: Highlight display manager, handles text highlighting:
  - Precise text location and highlighting
  - Multi-page highlight synchronization
  - Highlight animation and scroll control
  - Highlight state management and cleanup

- TextLocationManager.swift: PDF text location manager, responsible for precise text location and validation:
  - Text segmentation: Intelligently splits long text into segments for accurate positioning
  - Text search: Searches for text segments in PDF pages, supporting current and adjacent pages
  - Position validation: Validates positional relationships between found text segments
  - Cache management: Implements search result caching for improved performance

## 4. Acknowledgments


## 5. Sponsorship
[buymeacoffee](https://github.com/chiimagnus/logseq-AIsearch/blob/master/public/buymeacoffee.jpg)
<div align="center">
  <img src="https://github.com/chiimagnus/logseq-AIsearch/blob/master/public/buymeacoffee.jpg" width="400">
</div>
