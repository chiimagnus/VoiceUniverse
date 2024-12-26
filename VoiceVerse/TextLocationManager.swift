import Foundation
import PDFKit

@MainActor
class TextLocationManager: ObservableObject {
    // 定义分段位置枚举
    enum SegmentPosition {
        case start    // 句子开头
        case middle   // 句子中间
        case end      // 句子结尾
    }
    
    // 文本片段结构
    struct TextSegment: Hashable {
        let text: String           // 分段的文本内容
        let position: SegmentPosition  // 在原句中的位置
        let originalIndex: Int     // 在原句中的起始索引
        
        // 实现 Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(originalIndex)
        }
        
        static func == (lhs: TextSegment, rhs: TextSegment) -> Bool {
            return lhs.text == rhs.text && lhs.originalIndex == rhs.originalIndex
        }
    }
    
    // 分段配置
    private struct SegmentConfig {
        static let segmentLength = 3       // 每个分段的字符数
        static let minSegments = 3         // 最少需要多少个分段
        static let maxSegments = 5         // 最多使用多少个分段
        static let coverage = 0.6          // 分段覆盖率（0.0-1.0）
    }
    
    /// 将文本分段并选择关键位置
    /// - Parameter text: 需要分段的原始文本
    /// - Returns: 选择的关键文本片段数组
    func segmentText(_ text: String) -> [TextSegment] {
        // 1. 清理文本，移除多余的空白字符
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return [] }
        
        // 2. 将文本按固定长度分段
        var allSegments: [TextSegment] = []
        let characters = Array(cleanText)
        var currentIndex = 0
        
        while currentIndex < characters.count {
            let endIndex = min(currentIndex + SegmentConfig.segmentLength, characters.count)
            let segment = String(characters[currentIndex..<endIndex])
            
            // 确定段落位置
            let position: SegmentPosition
            if currentIndex == 0 {
                position = .start
            } else if endIndex == characters.count {
                position = .end
            } else {
                position = .middle
            }
            
            // 创建文本片段
            let textSegment = TextSegment(
                text: segment,
                position: position,
                originalIndex: currentIndex
            )
            allSegments.append(textSegment)
            
            currentIndex = endIndex
        }
        
        // 3. 选择关键位置的片段
        return selectKeySegments(from: allSegments, totalLength: cleanText.count)
    }
    
    /// 从所有分段中选择关键位置的片段
    /// - Parameters:
    ///   - segments: 所有的文本片段
    ///   - totalLength: 原始文本的总长度
    /// - Returns: 选择的关键文本片段
    private func selectKeySegments(from segments: [TextSegment], totalLength: Int) -> [TextSegment] {
        guard !segments.isEmpty else { return [] }
        
        var selectedSegments: [TextSegment] = []
        
        // 1. 总是选择第一个片段（开头）
        selectedSegments.append(segments.first!)
        
        // 2. 如果文本足够长，选择中间的片段
        if segments.count > 2 {
            let middleIndex = segments.count / 2
            selectedSegments.append(segments[middleIndex])
        }
        
        // 3. 如果不是很短的文本，选择最后一个片段
        if segments.count > 1 {
            selectedSegments.append(segments.last!)
        }
        
        // 4. 根据文本长度和配置的覆盖率，可能需要添加更多的片段
        let currentCoverage = Double(selectedSegments.count * SegmentConfig.segmentLength) / Double(totalLength)
        
        if currentCoverage < SegmentConfig.coverage && segments.count > selectedSegments.count {
            // 在已选片段之间均匀选择额外的片段
            let remainingSegments = segments.filter { !selectedSegments.contains($0) }
            let additionalNeeded = min(
                SegmentConfig.maxSegments - selectedSegments.count,
                remainingSegments.count
            )
            
            if additionalNeeded > 0 {
                let step = remainingSegments.count / (additionalNeeded + 1)
                for i in 1...additionalNeeded {
                    let index = i * step - 1
                    if index < remainingSegments.count {
                        selectedSegments.append(remainingSegments[index])
                    }
                }
            }
        }
        
        // 5. 按原始索引排序
        return selectedSegments.sorted { $0.originalIndex < $1.originalIndex }
    }
    
    /// 打印分段信息（用于调试）
    func printSegments(_ segments: [TextSegment]) {
        print("文本分段结果：")
        for (index, segment) in segments.enumerated() {
            print("[\(index)] 位置: \(segment.position), 索引: \(segment.originalIndex), 文本: \"\(segment.text)\"")
        }
    }
} 