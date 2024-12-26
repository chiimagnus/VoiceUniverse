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
                      let selectedText = selection.string,
                      let currentPage = pdfView.currentPage,
                      let pageIndex = pdfView.document?.index(for: currentPage) else { return }
                
                // 停止当前朗读
                parent.speechManager.stop()
                // 设置新文本并开始朗读
                parent.sentenceManager.setText(selectedText, pageIndex: pageIndex)
                parent.speechManager.speak()
            }
        }
        
        nonisolated func pdfView(_ pdfView: PDFView, clickedAt point: NSPoint) {
            Task { @MainActor in
                guard let page = pdfView.page(for: point, nearest: true),
                      let pageText = page.string,
                      let pageIndex = pdfView.document?.index(for: page) else { return }
                
                // 不需要在这里自己分割句子，应该使用 SentenceManager 来处理
                parent.sentenceManager.setText(pageText, pageIndex: pageIndex)  // 让 SentenceManager 处理文本分割
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
        VStack(spacing: 0) {
            GeometryReader { geometry in
                PDFKitView(
                    pdfView: pdfView,
                    speechManager: speechManager,
                    sentenceManager: sentenceManager
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            // 底部进度条
            ProgressBarView(
                sentenceManager: sentenceManager,
                totalPages: pdfDocument.pageCount,
                pdfView: pdfView,
                speechManager: speechManager,
                pdfDocument: pdfDocument
            )
            .frame(height: 40)
            .background(.ultraThinMaterial)
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
        if let firstPage = pdfDocument.page(at: 0),
           let pageText = firstPage.string {
            // 从第一页开始设置文本
            sentenceManager.setText(pageText, pageIndex: 0)
        }
        
        // 朗读完一个句子后自动朗读下一个
        speechManager.onFinishSpeaking = {
            if !sentenceManager.isLastSentence {
                speechManager.speak()
            } else {
                // 如果当前页面的最后一句已读完，尝试切换到下一页
                let nextPageIndex = sentenceManager.currentPageIndex + 1
                if nextPageIndex < self.pdfDocument.pageCount,
                   let nextPage = self.pdfDocument.page(at: nextPageIndex),
                   let nextPageText = nextPage.string {
                    print("Switching to page \(nextPageIndex)")
                    // 切换到下一页
                    self.pdfView.go(to: nextPage)
                    // 设置新页面的文本
                    self.sentenceManager.setText(nextPageText, pageIndex: nextPageIndex)
                    // 确保重置状态后再开始朗读
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.speechManager.speak()
                    }
                }
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

// 进度条视图
struct ProgressBarView: View {
    @ObservedObject var sentenceManager: SentenceManager
    let totalPages: Int
    let pdfView: PDFView
    let speechManager: SpeechManager
    let pdfDocument: PDFDocument
    
    @State private var showingPageDialog = false
    @State private var showingSentenceDialog = false
    @State private var inputText = ""
    
    var body: some View {
        HStack(spacing: 16) {
            // 页面信息
            Button(action: {
                showingPageDialog = true
            }) {
                Text("page: \(sentenceManager.currentPageIndex + 1)/\(totalPages)")
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingPageDialog) {
                PageJumpDialog(
                    isPresented: $showingPageDialog,
                    totalPages: totalPages,
                    onJump: { pageNumber in
                        jumpToPage(pageNumber - 1)  // 转换为0基索引
                    }
                )
                .frame(width: 300, height: 150)
            }
            
            // 句子进度
            Button(action: {
                showingSentenceDialog = true
            }) {
                Text("sentence: \(sentenceManager.getCurrentSentenceNumber())/\(sentenceManager.getCurrentPageSentenceCount())")
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingSentenceDialog) {
                SentenceJumpDialog(
                    isPresented: $showingSentenceDialog,
                    totalSentences: sentenceManager.getCurrentPageSentenceCount(),
                    onJump: { sentenceNumber in
                        jumpToSentence(sentenceNumber - 1)  // 转换为0基索引
                    }
                )
                .frame(width: 300, height: 150)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress)
                }
                .frame(height: 4)
            }
            .frame(height: 4)
            
            // 下一句按钮
            Button(action: {
                // 如果当前句子为空，说明是第一次朗读
                if sentenceManager.getCurrentSentence().isEmpty {
                    speechManager.speak()
                } else {
                    speechManager.speakNext()
                }
            }) {
                Text("下一句")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal)
    }
    
    // 计算当前进度（0-1之间）
    private var progress: Double {
        guard sentenceManager.getCurrentPageSentenceCount() > 0 else { return 0 }
        return Double(sentenceManager.getCurrentSentenceNumber()) / Double(sentenceManager.getCurrentPageSentenceCount())
    }
    
    // 跳转到指定页面
    private func jumpToPage(_ pageIndex: Int) {
        guard let page = pdfDocument.page(at: pageIndex),
              let pageText = page.string else { return }
        
        // 停止当前朗读
        speechManager.stop()
        
        // 切换到目标页面
        pdfView.go(to: page)
        
        // 设置新页面的文本
        sentenceManager.setText(pageText, pageIndex: pageIndex)
        
        // 开始朗读
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            speechManager.speak()
        }
    }
    
    // 跳转到当前页面的指定句子
    private func jumpToSentence(_ sentenceIndex: Int) {
        // 停止当前朗读
        speechManager.stop()
        
        // 重置到开始位置
        sentenceManager.reset()
        
        // 跳转到指定句子
        for _ in 0..<sentenceIndex {
            _ = sentenceManager.nextSentence()
        }
        
        // 开始朗读
        speechManager.speak()
    }
}

// 页面跳转对话框
struct PageJumpDialog: View {
    @Binding var isPresented: Bool
    let totalPages: Int
    let onJump: (Int) -> Void
    
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("跳转到页面")
                .font(.headline)
            
            TextField("输入页码 (1-\(totalPages))", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 200)
            
            HStack(spacing: 20) {
                Button("取消") {
                    isPresented = false
                }
                
                Button("确定") {
                    if let pageNumber = Int(inputText),
                       pageNumber >= 1 && pageNumber <= totalPages {
                        onJump(pageNumber)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding()
        .onAppear {
            isFocused = true
        }
    }
}

// 句子跳转对话框
struct SentenceJumpDialog: View {
    @Binding var isPresented: Bool
    let totalSentences: Int
    let onJump: (Int) -> Void
    
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("跳转到句子")
                .font(.headline)
            
            TextField("输入句子编号 (1-\(totalSentences))", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 200)
            
            HStack(spacing: 20) {
                Button("取消") {
                    isPresented = false
                }
                
                Button("确定") {
                    if let sentenceNumber = Int(inputText),
                       sentenceNumber >= 1 && sentenceNumber <= totalSentences {
                        onJump(sentenceNumber)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding()
        .onAppear {
            isFocused = true
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
