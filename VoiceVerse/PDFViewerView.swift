import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let pdfView: PDFView
    let speechManager: SpeechManager
    let sentenceManager: SentenceManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> PDFView {
        pdfView.delegate = context.coordinator
        
        // 基本设置
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        
        // 设置缩放
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 4.0
        pdfView.scaleFactor = 1.0  // 初始缩放比例
        
        // 设置页面布局
        pdfView.pageShadowsEnabled = true
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // 更新视图大小
        if let window = nsView.window {
            let bounds = window.contentView?.bounds ?? .zero
            nsView.frame = bounds
        }
    }
    
    // Coordinator 类来处理 PDF 代理
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        nonisolated func pdfViewSelectionDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            
            Task { @MainActor in
                guard let selection = pdfView.currentSelection,
                      let selectedText = selection.string else { return }
                
                // 停止当前朗读
                parent.speechManager.stop()
                // 设置新文本并开始朗读
                parent.sentenceManager.setText(selectedText)
                parent.speechManager.speak()
            }
        }
        
        nonisolated func pdfView(_ pdfView: PDFView, clickedAt point: NSPoint) {
            Task { @MainActor in
                guard let page = pdfView.page(for: point, nearest: true),
                      let pageText = page.string else { return }
                
                // 不需要在这里自己分割句子，应该使用 SentenceManager 来处理
                parent.sentenceManager.setText(pageText)  // 让 SentenceManager 处理文本分割
                parent.speechManager.speak()  // 开始朗读第一个句子
            }
        }
    }
}

struct PDFViewerView: View {
    let pdfDocument: PDFDocument
    let sentenceManager: SentenceManager
    let speechManager: SpeechManager
    @StateObject private var highlightManager: HighlightManager
    
    private let pdfView: PDFView
    
    init(pdfDocument: PDFDocument, 
         sentenceManager: SentenceManager,
         speechManager: SpeechManager) {
        self.pdfDocument = pdfDocument
        self.sentenceManager = sentenceManager
        self.speechManager = speechManager
        
        let pdfView = PDFView()
        self.pdfView = pdfView
        
        // 先设置 PDF 文档
        pdfView.document = pdfDocument
        
        // 然后创建 highlightManager
        let highlightManager = HighlightManager(pdfView: pdfView, sentenceManager: sentenceManager)
        _highlightManager = StateObject(wrappedValue: highlightManager)
    }
    
    var body: some View {
        GeometryReader { geometry in
            PDFKitView(
                pdfView: pdfView,
                speechManager: speechManager,
                sentenceManager: sentenceManager
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            setupPDFView()
            setupMenuCommandObservers()
            setupCallbacks()
        }
    }
    
    private func setupPDFView() {
        // 基本设置
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // 设置缩放范围
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit * 0.5
        pdfView.maxScaleFactor = 5.0
        
        // 设置页面布局
        pdfView.pageShadowsEnabled = true
        pdfView.pageBreakMargins = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        // 配置滚动视图
        if let scrollView = pdfView.documentView?.enclosingScrollView {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .allowed
            
            // 设置内容边距，为工具留出空间
            let contentInsets = NSEdgeInsets(top: 28, left: 0, bottom: 0, right: 0)
            scrollView.contentInsets = contentInsets
            scrollView.scrollerInsets = contentInsets
            
            // 设置背景颜色
            scrollView.backgroundColor = .clear
            scrollView.drawsBackground = false
            pdfView.backgroundColor = .clear
        }
        
        // 调整初始显示
        DispatchQueue.main.async {
            // 设置初始缩放以适应度
            let scaleFactor = pdfView.scaleFactorForSizeToFit
            pdfView.scaleFactor = scaleFactor
            
            // 滚动到文档开始
            if let firstPage = pdfView.document?.page(at: 0) {
                pdfView.go(to: PDFDestination(page: firstPage, at: NSPoint(x: 0, y: firstPage.bounds(for: .mediaBox).height)))
            }
        }
    }
    
    private func setupMenuCommandObservers() {
        // 自动调整大小命令
        NotificationCenter.default.addObserver(forName: NSNotification.Name("AutoResize"), object: nil, queue: .main) { _ in
            pdfView.autoScales = true
            // 调整缩放以适应视图大小
            if let scrollView = pdfView.documentView?.enclosingScrollView {
                let viewSize = scrollView.contentView.bounds.size
                if let firstPage = pdfView.document?.page(at: 0) {
                    let pageSize = firstPage.bounds(for: .mediaBox).size
                    let scaleWidth = viewSize.width / pageSize.width
                    let scaleHeight = viewSize.height / pageSize.height
                    let scale = min(scaleWidth, scaleHeight)
                    pdfView.scaleFactor = scale
                }
            }
        }
        
        // 缩放命令
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ZoomIn"), object: nil, queue: .main) { _ in
            pdfView.scaleFactor *= 1.25
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ZoomOut"), object: nil, queue: .main) { _ in
            pdfView.scaleFactor *= 0.8
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ActualSize"), object: nil, queue: .main) { _ in
            pdfView.scaleFactor = 1.0
        }
        
        // 页面显示模式命令
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SinglePage"), object: nil, queue: .main) { _ in
            pdfView.displayMode = .singlePage
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SinglePageContinuous"), object: nil, queue: .main) { _ in
            pdfView.displayMode = .singlePageContinuous
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TwoPages"), object: nil, queue: .main) { _ in
            pdfView.displayMode = .twoUp
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TwoPagesContinuous"), object: nil, queue: .main) { _ in
            pdfView.displayMode = .twoUpContinuous
        }
        
        // 页面导航命令
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NextPage"), object: nil, queue: .main) { _ in
            if let currentPage = pdfView.currentPage,
               let nextPageIndex = pdfView.document?.index(for: currentPage) {
                let nextIndex = nextPageIndex + 1
                if nextIndex < pdfView.document?.pageCount ?? 0,
                   let nextPage = pdfView.document?.page(at: nextIndex) {
                    pdfView.go(to: nextPage)
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("PreviousPage"), object: nil, queue: .main) { _ in
            if let currentPage = pdfView.currentPage,
               let previousPageIndex = pdfView.document?.index(for: currentPage) {
                let previousIndex = previousPageIndex - 1
                if previousIndex >= 0,
                   let previousPage = pdfView.document?.page(at: previousIndex) {
                    pdfView.go(to: previousPage)
                }
            }
        }
    }
    
    private func setupCallbacks() {
        // 设置文本并开始处理
        if let text = pdfDocument.string {
            sentenceManager.setText(text)
        }
        
        // 朗读完一个句子后自动朗读下一个
        speechManager.onFinishSpeaking = {
            if !sentenceManager.isLastSentence {
                speechManager.speak()
            }
        }
        
        // 当句子朗读完成时清除高亮
        speechManager.onFinishSentence = { [highlightManager] in
            highlightManager.highlightSentence("")  // 清除高亮
        }
        
        // 当句子改变时更新高亮
        sentenceManager.onNextSentence = { [highlightManager] sentence in
            highlightManager.highlightSentence(sentence)
        }
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let document = PDFDocument(url: url) {
        let sentenceManager = SentenceManager()
        let speechManager = SpeechManager(sentenceManager: sentenceManager)
        PDFViewerView(
            pdfDocument: document,
            sentenceManager: sentenceManager,
            speechManager: speechManager
        )
    } else {
        Text("Preview not available")
    }
} 
