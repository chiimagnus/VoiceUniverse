import SwiftUI
import PDFKit

struct PDFKitView: NSViewRepresentable {
    let pdfView: PDFView
    let speechManager: SpeechManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> PDFView {
        pdfView.delegate = context.coordinator
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Update view if needed
    }
    
    // Coordinator 类来处理 PDF 代理
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        // 当用户选择文本时触发
        func pdfViewSelectionDidChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection,
                  let selectedText = selection.string else { return }
            
            // 确保在主线程上调用
            Task { @MainActor in
                // 停止当前朗读
                parent.speechManager.stop()
                // 从选中的文本开始朗读
                parent.speechManager.speak(text: selectedText)
            }
        }
        
        // 修改点击处理方法
        func pdfView(_ pdfView: PDFView, clickedAt point: NSPoint) {
            guard let page = pdfView.page(for: point, nearest: true) else { return }
            
            // 获取页面中的完整文本
            guard let pageText = page.string else { return }
            
            // 转换点击位置到页面坐标系
            let pagePoint = pdfView.convert(point, to: page)
            
            // 创建一个选区来获取点击位置的文本
            let wordRange = NSRange(location: 0, length: pageText.count)
            if let selection = page.selection(for: wordRange) {
                // 找到点击位置最近的句子
                let sentences = pageText.components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // 获取点击位置最近的句子
                if let clickedSentence = sentences.first {
                    Task { @MainActor in
                        // 停止当前朗读
                        parent.speechManager.stop()
                        // 从句子开始朗读
                        parent.speechManager.speak(text: clickedSentence)
                    }
                }
            }
        }
    }
}

struct PDFViewerView: View {
    let pdfDocument: PDFDocument
    @ObservedObject var speechManager: SpeechManager
    @StateObject private var highlightManager: HighlightManager
    
    private let pdfView: PDFView
    
    // 私有初始化器
    private init(pdfDocument: PDFDocument, 
                speechManager: SpeechManager, 
                pdfView: PDFView, 
                highlightManager: HighlightManager) {
        self.pdfDocument = pdfDocument
        self.speechManager = speechManager
        self.pdfView = pdfView
        self._highlightManager = StateObject(wrappedValue: highlightManager)
    }
    
    // 静态工厂方法
    static func create(pdfDocument: PDFDocument, speechManager: SpeechManager) -> PDFViewerView {
        let pdfView = PDFView()
        let highlightManager = HighlightManager(pdfView: pdfView)
        return PDFViewerView(pdfDocument: pdfDocument, 
                           speechManager: speechManager, 
                           pdfView: pdfView, 
                           highlightManager: highlightManager)
    }
    
    var body: some View {
        PDFKitView(pdfView: pdfView, speechManager: speechManager)
            .onAppear {
                setupPDFView()
                setupSpeechManagerCallbacks()
            }
    }
    
    private func setupPDFView() {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.document = pdfDocument
    }
    
    private func setupSpeechManagerCallbacks() {
        // 设置回调
        speechManager.onSentenceChanged = { [highlightManager] sentence in
            Task { @MainActor in
                highlightManager.highlightSentence(sentence)
            }
        }
        
        speechManager.onHighlight = { [highlightManager] word in
            Task { @MainActor in
                highlightManager.highlightSentence(word)
            }
        }
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let document = PDFDocument(url: url) {
        PDFViewerView.create(pdfDocument: document, speechManager: SpeechManager())
    } else {
        Text("Preview not available")
    }
} 