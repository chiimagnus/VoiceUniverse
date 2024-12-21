import PDFKit

@MainActor
class HighlightManager: ObservableObject {
    // 高亮类型枚举
    enum HighlightType {
        case sentence   // 整句高亮
        case word      // 当前词高亮
    }
    
    // 高亮状态结构
    struct HighlightState {
        var currentSentence: String = ""
        var currentWord: String = ""
        var sentenceAnnotation: PDFAnnotation?
        var wordAnnotation: PDFAnnotation?
    }
    
    private let pdfView: PDFView
    private var currentState: HighlightState = HighlightState()
    
    init(pdfView: PDFView) {
        self.pdfView = pdfView
    }
    
    // 高亮当前句子
    func highlightSentence(_ sentence: String) {
        removeAllHighlights()
        
        guard !sentence.isEmpty else { return }
        currentState.currentSentence = sentence
        
        // 在所有页面中查找并高亮文本
        for pageIndex in 0..<pdfView.document!.pageCount {
            guard let page = pdfView.document?.page(at: pageIndex),
                  let pageString = page.string else { continue }
            
            let cleanedPageText = pageString.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let range = cleanedPageText.range(of: cleanedSentence, options: [.caseInsensitive, .diacriticInsensitive]) {
                let nsRange = NSRange(range, in: cleanedPageText)
                if let textSelection = page.selection(for: nsRange) {
                    let bounds = textSelection.bounds(for: page)
                    let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    highlight.color = NSColor.systemYellow.withAlphaComponent(0.3)
                    page.addAnnotation(highlight)
                    currentState.sentenceAnnotation = highlight
                    
                    // 滚动到高亮位置
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.3
                        context.allowsImplicitAnimation = true
                        pdfView.go(to: textSelection)
                    }
                    break
                }
            }
        }
    }
    
    // 移除所有高亮
    func removeAllHighlights() {
        guard let document = pdfView.document else { return }
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            page.annotations.forEach { annotation in
                if annotation.type == PDFAnnotationSubtype.highlight.rawValue {
                    page.removeAnnotation(annotation)
                }
            }
        }
        
        currentState.sentenceAnnotation = nil
        currentState.wordAnnotation = nil
    }
}
