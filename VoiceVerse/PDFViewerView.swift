import SwiftUI
import PDFKit

struct PDFViewerView: View {
    let pdfDocument: PDFDocument
    @ObservedObject var speechManager: SpeechManager
    
    private let pdfView = PDFView()
    
    var body: some View {
        PDFKitView(pdfView: pdfView)
            .onAppear {
                setupPDFView()
            }
            .onChange(of: speechManager.currentSentence) { newValue in
                highlightCurrentSentence(newValue)
            }
    }
    
    private func setupPDFView() {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.document = pdfDocument
    }
    
    private func highlightCurrentSentence(_ sentence: String) {
        // 移除之前的高亮
        if let page = pdfView.currentPage {
            page.annotations.forEach { annotation in
                if annotation.type == PDFAnnotationSubtype.highlight.rawValue {
                    page.removeAnnotation(annotation)
                }
            }
        }
        
        // 如果句子为空，不添加新高亮
        guard !sentence.isEmpty else { return }
        
        // 在所有页面中查找并高亮文本
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageString = page.string else { continue }
            
            // 使用更灵活的文本匹配
            let cleanedPageText = pageString.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let range = cleanedPageText.range(of: cleanedSentence, options: [.caseInsensitive, .diacriticInsensitive]) {
                let nsRange = NSRange(range, in: cleanedPageText)
                if let textSelection = page.selection(for: nsRange) {
                    let bounds = textSelection.bounds(for: page)
                    let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    
                    // 使用更醒目的高亮颜色
                    highlight.color = NSColor.systemYellow.withAlphaComponent(0.4)
                    page.addAnnotation(highlight)
                    
                    // 平滑滚动到高亮位置
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.3
                        context.allowsImplicitAnimation = true
                        pdfView.go(to: textSelection)
                    }
                    
                    // 找到匹配后就退出循环
                    break
                }
            }
        }
    }
}

struct PDFKitView: NSViewRepresentable {
    let pdfView: PDFView
    
    func makeNSView(context: Context) -> PDFView {
        pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        // Update view if needed
    }
}

#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "pdf"),
       let document = PDFDocument(url: url) {
        PDFViewerView(pdfDocument: document, speechManager: SpeechManager())
    } else {
        Text("Preview not available")
    }
} 