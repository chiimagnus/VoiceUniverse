import Foundation
import SwiftUI
import PDFKit

@MainActor
final class SentenceManager: ObservableObject {
    @Published private(set) var currentSentence: String = ""
    @Published private(set) var isLastSentence: Bool = false
    @Published private(set) var hasText: Bool = false
    @Published private(set) var currentPageIndex: Int = 0
    @Published private(set) var currentSentenceIndex: Int = 0
    @Published private(set) var totalSentencesInCurrentPage: Int = 0
    
    // 存储每个页面的句子
    private var pagesSentences: [Int: [String]] = [:]
    private var currentPageSentences: [String] = []
    
    var onNextSentence: ((String) -> Void)?
    
    // 设置新的文本并重置状态
    func setText(_ text: String, pageIndex: Int) {
        print("Setting text for page \(pageIndex), length: \(text.count)")
        let sentences = splitIntoSentences(text)
        pagesSentences[pageIndex] = sentences
        
        if currentPageIndex == pageIndex {
            // 如果是当前页面，更新当前页面的句子
            updateCurrentPage(pageIndex)
        }
        
        hasText = !pagesSentences.isEmpty
    }
    
    // 切换到指定页面
    func switchToPage(_ pageIndex: Int) {
        currentPageIndex = pageIndex
        updateCurrentPage(pageIndex)
        reset()
    }
    
    // 获取下一个句子
    func nextSentence() -> String? {
        guard !currentPageSentences.isEmpty else { return nil }
        
        currentSentenceIndex += 1
        if currentSentenceIndex >= currentPageSentences.count {
            currentSentenceIndex = currentPageSentences.count - 1
            isLastSentence = true
            return nil
        }
        
        currentSentence = currentPageSentences[currentSentenceIndex]
        isLastSentence = currentSentenceIndex == currentPageSentences.count - 1
        print("Next sentence [\(currentSentenceIndex)/\(currentPageSentences.count)] on page \(currentPageIndex): \(currentSentence)")
        
        onNextSentence?(currentSentence)
        return currentSentence
    }
    
    // 获取当前句子
    func getCurrentSentence() -> String {
        return currentSentence
    }
    
    // 重置到当前页面的开始位置
    func reset() {
        currentSentenceIndex = -1
        currentSentence = ""
        isLastSentence = false
        hasText = !pagesSentences.isEmpty
    }
    
    // 获取当前页面的总句子数
    func getCurrentPageSentenceCount() -> Int {
        return currentPageSentences.count
    }
    
    // 获取当前页面的句子索引（从1开始）
    func getCurrentSentenceNumber() -> Int {
        return currentSentenceIndex + 1
    }
    
    // 私有方法：更新当前页面的句子
    private func updateCurrentPage(_ pageIndex: Int) {
        currentPageSentences = pagesSentences[pageIndex] ?? []
        totalSentencesInCurrentPage = currentPageSentences.count
        print("Updated to page \(pageIndex) with \(totalSentencesInCurrentPage) sentences")
    }
    
    // 将文本分割成句子
    private func splitIntoSentences(_ text: String) -> [String] {
        // 定义句子分隔符
        let separators = CharacterSet(charactersIn: "。！？\n")
        var sentences: [String] = []
        var currentSentence = ""
        
        for char in text {
            currentSentence.append(char)
            if CharacterSet(charactersIn: String(char)).isSubset(of: separators) {
                let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                currentSentence = ""
            }
        }
        
        // 处理最后一个句子
        if !currentSentence.isEmpty {
            let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                sentences.append(trimmed)
            }
        }
        
        return sentences
    }
} 