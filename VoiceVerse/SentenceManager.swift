import Foundation
import SwiftUI

@MainActor
final class SentenceManager: ObservableObject {
    @Published private(set) var currentSentence: String = ""
    @Published private(set) var isLastSentence: Bool = false
    @Published private(set) var hasText: Bool = false
    private var sentences: [String] = []
    private var currentIndex: Int = -1
    
    var onNextSentence: ((String) -> Void)?  // 新增回调
    
    // 设置新的文本并重置状态
    func setText(_ text: String) {
        print("Setting text, length: \(text.count)")
        sentences = splitIntoSentences(text)
        print("Split into \(sentences.count) sentences")
        currentIndex = -1
        currentSentence = ""
        isLastSentence = false
        hasText = !sentences.isEmpty
    }
    
    // 获取下一个句子
    func nextSentence() -> String? {
        guard !sentences.isEmpty else { return nil }
        
        currentIndex += 1
        if currentIndex >= sentences.count {
            currentIndex = sentences.count - 1
            isLastSentence = true
            return nil
        }
        
        currentSentence = sentences[currentIndex]
        isLastSentence = currentIndex == sentences.count - 1
        print("Next sentence [\(currentIndex)/\(sentences.count)]: \(currentSentence)")
        
        // 触发回调，通知监听者句子变化
        onNextSentence?(currentSentence)
        
        return currentSentence
    }
    
    // 获取当前句子
    func getCurrentSentence() -> String {
        return currentSentence
    }
    
    // 重置到开始位置
    func reset() {
        currentIndex = -1
        currentSentence = ""
        isLastSentence = false
        hasText = !sentences.isEmpty
    }
    
    // 将文本分割成句子
    private func splitIntoSentences(_ text: String) -> [String] {
        // 定义句子分隔符
        let separators = CharacterSet(charactersIn: "。！？\n")  // 简化分隔符,主要使用中文标点
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
    
    // 中心化的处理下一个句子的函数
    func processNextSentence() {
        guard let sentence = nextSentence() else { return }
        
        // 通知所有监听者
        onNextSentence?(sentence)
    }
} 