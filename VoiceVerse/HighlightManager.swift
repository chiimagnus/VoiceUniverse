import PDFKit
import AppKit

@MainActor
class HighlightManager: ObservableObject {
    private let pdfView: PDFView
    private let sentenceManager: SentenceManager
    private var currentAnnotation: PDFAnnotation?
    private var lastHighlightedText: String = ""
    private var lastHighlightedPage: PDFPage?
    private var lastHighlightLocation: Int = 0
    
    init(pdfView: PDFView, sentenceManager: SentenceManager) {
        self.pdfView = pdfView
        self.sentenceManager = sentenceManager
        
        // 监听句子变化
        sentenceManager.onNextSentence = { [weak self] sentence in
            self?.highlightSentence(sentence)
        }
    }
    
    func highlightCurrentSentence() {
        let sentence = sentenceManager.getCurrentSentence()
        
        // 如果句子为空，清除高亮
        if sentence.isEmpty {
            removeHighlight()
            return
        }
        
        // 在当前页面查找并高亮文本
        if let currentPage = pdfView.currentPage,
           let selection = findTextInPage(sentence, in: currentPage, nearLocation: 0) {
            addHighlight(for: selection, in: currentPage)
        }
    }
    
    func highlightSentence(_ sentence: String, at location: Int = 0) {
        print("Attempting to highlight: \(sentence)")
        
        // 如果是空字符串，直接清除高亮并返回
        if sentence.isEmpty {
            print("Empty sentence, removing highlight")
            removeHighlight()
            return
        }
        
        // 如果是相同的文本，跳过
        guard sentence != lastHighlightedText else {
            print("Same as last text, skipping")
            return
        }
        lastHighlightedText = sentence
        
        // 在添加新高亮前，先清除旧的高亮
        removeHighlight()
        
        guard let document = pdfView.document else {
            print("No PDF document found")
            return
        }
        
        let cleanedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Cleaned sentence: \(cleanedSentence)")
        
        // 优先在上次高亮的页面附近查找
        if let lastPage = lastHighlightedPage,
           let selection = findTextInPage(cleanedSentence, in: lastPage, nearLocation: lastHighlightLocation) {
            addHighlight(for: selection, in: lastPage)
            return
        }
        
        // 如果在上次页面找不到，从当前页面开始查找
        let currentPage = pdfView.currentPage
        var foundHighlight = false
        
        if let currentPage = currentPage,
           let selection = findTextInPage(cleanedSentence, in: currentPage, nearLocation: location) {
            addHighlight(for: selection, in: currentPage)
            foundHighlight = true
            lastHighlightedPage = currentPage
            lastHighlightLocation = location
        }
        
        // 如果当前页面没找到，在相邻页面查找
        if !foundHighlight {
            print("Searching in nearby pages")
            // 获取当前页面索引
            let currentPageIndex = currentPage.flatMap { document.index(for: $0) } ?? 0
            
            // 先查找后面的页面
            for pageIndex in currentPageIndex..<min(currentPageIndex + 2, document.pageCount) {
                guard let page = document.page(at: pageIndex),
                      page != currentPage,
                      let selection = findTextInPage(cleanedSentence, in: page, nearLocation: 0) else { continue }
                
                print("Found text in page \(pageIndex)")
                addHighlight(for: selection, in: page)
                scrollToSelection(selection, in: page)
                lastHighlightedPage = page
                lastHighlightLocation = 0
                foundHighlight = true
                break
            }
            
            // 如果后面没找到，查找前面的页面
            if !foundHighlight {
                for pageIndex in stride(from: currentPageIndex - 1, through: max(0, currentPageIndex - 2), by: -1) {
                    guard let page = document.page(at: pageIndex),
                          let selection = findTextInPage(cleanedSentence, in: page, nearLocation: 0) else { continue }
                    
                    print("Found text in page \(pageIndex)")
                    addHighlight(for: selection, in: page)
                    scrollToSelection(selection, in: page)
                    lastHighlightedPage = page
                    lastHighlightLocation = 0
                    break
                }
            }
        }
    }
    
    private func findTextInPage(_ text: String, in page: PDFPage, nearLocation location: Int) -> PDFSelection? {
        guard let pageContent = page.string else { return nil }
        
        // 清理和标准化文本
        let normalizedText = text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let normalizedPageContent = pageContent.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 查找所有匹配位置
        var ranges: [Range<String.Index>] = []
        var searchRange = normalizedPageContent.startIndex..<normalizedPageContent.endIndex
        
        while let range = normalizedPageContent.range(of: normalizedText, 
                                                    options: [.caseInsensitive, .diacriticInsensitive],
                                                    range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<normalizedPageContent.endIndex
        }
        
        // 如果找到多个匹配，选择最接近给定位置的一个
        if let bestRange = ranges.min(by: { range1, range2 in
            let dist1 = abs(normalizedPageContent.distance(from: normalizedPageContent.startIndex, to: range1.lowerBound) - location)
            let dist2 = abs(normalizedPageContent.distance(from: normalizedPageContent.startIndex, to: range2.lowerBound) - location)
            return dist1 < dist2
        }) {
            let startIndex = pageContent.distance(from: pageContent.startIndex, to: bestRange.lowerBound)
            let length = pageContent.distance(from: bestRange.lowerBound, to: bestRange.upperBound)
            let nsRange = NSRange(location: startIndex, length: length)
            return page.selection(for: nsRange)
        }
        
        return nil
    }
    
    private func addHighlight(for selection: PDFSelection, in page: PDFPage) {
        // 移除旧的高亮
        removeHighlight()
        
        // 添加新的高亮
        let bounds = selection.bounds(for: page)
        let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        highlight.color = NSColor.systemYellow.withAlphaComponent(0.3)
        page.addAnnotation(highlight)
        currentAnnotation = highlight
    }
    
    private func scrollToSelection(_ selection: PDFSelection, in page: PDFPage) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            pdfView.go(to: selection)
        }
    }
    
    private func removeHighlight() {
        // 移除当前高亮
        if let currentAnnotation = currentAnnotation,
           let page = currentAnnotation.page {
            page.removeAnnotation(currentAnnotation)
        }
        currentAnnotation = nil
        
        // 确保清除所有页面上的高亮
        if let document = pdfView.document {
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                for annotation in page.annotations {
                    // PDFAnnotation的type属性是String类型，值为"Highlight"
                    if annotation.type == "Highlight" {
                        page.removeAnnotation(annotation)
                    }
                }
            }
        }
        
        // 重置状态
        lastHighlightedText = ""
        lastHighlightedPage = nil
        lastHighlightLocation = 0
    }
    
    private func findBestMatchingSentence(_ text: String, in sentences: [String]) -> String? {
        // 1. 完全匹配
        if let exact = sentences.first(where: { $0 == text }) {
            return exact
        }
        
        // 2. 包含匹配（考虑标点符号和格）
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return sentences.first { sentence in
            let cleanSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanSentence.contains(cleanText)
        }
    }
}

// 辅助扩展，用于分割句子
private extension String {
    func split(by separators: [Character]) -> [String] {
        var result: [String] = []
        var currentSentence = ""
        
        for char in self {
            currentSentence.append(char)
            if separators.contains(char) {
                result.append(currentSentence)
                currentSentence = ""
            }
        }
        
        if !currentSentence.isEmpty {
            result.append(currentSentence)
        }
        
        return result
    }
}
