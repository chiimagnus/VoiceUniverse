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
    
    // 搜索结果结构
    struct SearchResult {
        let segment: TextSegment        // 搜索的文本片段
        let page: PDFPage              // 找到的页面
        let range: NSRange             // 在页面中的范围
        let bounds: CGRect             // 在页面中的边界框
    }
    
    // 搜索配置
    private struct SearchConfig {
        static let maxSearchRange = 2     // 向前后最多搜索的页数
        static let positionTolerance = 50 // 位置容差（点）
    }
    
    // 保存上次搜索的页面和位置，用于优化搜索
    private var lastSearchPage: PDFPage?
    private var lastSearchLocation: CGPoint?
    
    // 位置验证配置
    private struct ValidationConfig {
        static let horizontalTolerance: CGFloat = 100  // 水平方向容差（点）
        static let verticalTolerance: CGFloat = 30     // 垂直方向容差（点）
        static let maxLineDifference = 2               // 最大允许的行数差异
        static let expectedSegmentSpacing: CGFloat = 50 // 预期的片段间距（点）
    }
    
    /// 验证结果结构
    struct ValidationResult {
        let isValid: Bool
        let searchResults: [SearchResult]
        let errorType: ValidationError?
        
        enum ValidationError {
            case tooFarApart          // 片段间距太大
            case wrongOrder           // 顺序错误
            case differentLines       // 不在同一行或相邻行
            case differentPages       // 在不同页面且距离过远
            case inconsistentLayout   // 布局不一致
        }
    }
    
    // 缓存配置
    private struct CacheConfig {
        static let maxCacheSize = 100          // 最大缓存条目数
        static let cleanupThreshold = 80       // 清理阈值
        static let maxAge: TimeInterval = 300  // 缓存最大年龄（秒）
    }
    
    // 缓存条目结构
    private struct CacheEntry {
        let searchResult: SearchResult
        let timestamp: Date
        let pageIndex: Int
        
        var age: TimeInterval {
            return Date().timeIntervalSince(timestamp)
        }
    }
    
    // 缓存键结构
    private struct CacheKey: Hashable {
        let text: String           // 搜索的文本
        let pageIndex: Int         // 页面索引
        let documentID: String     // 文档唯一标识
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(pageIndex)
            hasher.combine(documentID)
        }
    }
    
    // 缓存存储
    private var cache: [CacheKey: CacheEntry] = [:]
    private var currentDocumentID: String = ""
    
    /// 从缓存中获取搜索结果
    /// - Parameters:
    ///   - segment: 文本片段
    ///   - document: PDF文档
    ///   - pageIndex: 页面索引
    /// - Returns: 缓存的搜索结果（如果存在且有效）
    private func getCachedResult(
        for segment: TextSegment,
        in document: PDFDocument,
        pageIndex: Int
    ) -> SearchResult? {
        let key = CacheKey(
            text: segment.text,
            pageIndex: pageIndex,
            documentID: currentDocumentID
        )
        
        guard let entry = cache[key] else { return nil }
        
        // 检查缓存是否过期
        if entry.age > CacheConfig.maxAge {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return entry.searchResult
    }
    
    /// 将搜索结果添加到缓存
    /// - Parameters:
    ///   - result: 搜索结果
    ///   - document: PDF文档
    ///   - pageIndex: 页面索引
    private func cacheResult(
        _ result: SearchResult,
        in document: PDFDocument,
        pageIndex: Int
    ) {
        // 如果缓存已满，执行清理
        if cache.count >= CacheConfig.maxCacheSize {
            cleanCache()
        }
        
        let key = CacheKey(
            text: result.segment.text,
            pageIndex: pageIndex,
            documentID: currentDocumentID
        )
        
        let entry = CacheEntry(
            searchResult: result,
            timestamp: Date(),
            pageIndex: pageIndex
        )
        
        cache[key] = entry
    }
    
    /// 清理过期和过多的缓存条目
    private func cleanCache() {
        // 1. 删除过期条目
        let now = Date()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.timestamp) <= CacheConfig.maxAge
        }
        
        // 2. 如果仍然超过清理阈值，删除最旧的条目
        if cache.count > CacheConfig.cleanupThreshold {
            let sortedEntries = cache.sorted { $0.value.timestamp > $1.value.timestamp }
            let entriesToKeep = sortedEntries.prefix(CacheConfig.cleanupThreshold)
            cache = Dictionary(uniqueKeysWithValues: entriesToKeep.map { ($0.key, $0.value) })
        }
    }
    
    /// 设置当前文档ID
    /// - Parameter document: PDF文档
    func setCurrentDocument(_ document: PDFDocument) {
        // 使用文档的唯一标识（如果有）或生成一个新的
        if let documentURL = document.documentURL?.absoluteString {
            currentDocumentID = documentURL
        } else {
            // 如果没有URL，使用文档的哈希值作为ID
            currentDocumentID = String(document.hashValue)
        }
        
        // 清除旧文档的缓存
        clearCache()
    }
    
    /// 清除所有缓存
    func clearCache() {
        cache.removeAll()
        clearSearchCache() // 同时清除搜索缓存
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
    
    /// 在PDF中搜索文本片段
    /// - Parameters:
    ///   - segment: 要搜索的文本片段
    ///   - document: PDF文档
    ///   - currentPage: 当前页面
    /// - Returns: 搜索结果
    func searchSegment(_ segment: TextSegment, in document: PDFDocument, currentPage: PDFPage) -> SearchResult? {
        let currentPageIndex = document.index(for: currentPage)
        
        // 1. 尝试从缓存获取结果
        if let cachedResult = getCachedResult(for: segment, in: document, pageIndex: currentPageIndex) {
            lastSearchPage = cachedResult.page
            lastSearchLocation = cachedResult.bounds.origin
            return cachedResult
        }
        
        // 2. 如果缓存中没有，执行实际搜索
        if let result = performSearch(segment, in: document, currentPage: currentPage) {
            // 3. 将结果添加到缓存
            cacheResult(result, in: document, pageIndex: currentPageIndex)
            return result
        }
        
        return nil
    }
    
    /// 执行实际的搜索操作
    private func performSearch(_ segment: TextSegment, in document: PDFDocument, currentPage: PDFPage) -> SearchResult? {
        // 1. 首先在当前页面搜索
        if let result = searchInPage(segment, page: currentPage) {
            lastSearchPage = currentPage
            lastSearchLocation = result.bounds.origin
            return result
        }
        
        // 2. 如果当前页面没找到，在附近页面搜索
        let currentPageIndex = document.index(for: currentPage)
        
        // 2.1 向后搜索
        for offset in 1...SearchConfig.maxSearchRange {
            let nextPageIndex = currentPageIndex + offset
            guard nextPageIndex < document.pageCount,
                  let nextPage = document.page(at: nextPageIndex),
                  let result = searchInPage(segment, page: nextPage) else {
                continue
            }
            lastSearchPage = nextPage
            lastSearchLocation = result.bounds.origin
            return result
        }
        
        // 2.2 向前搜索
        for offset in 1...SearchConfig.maxSearchRange {
            let previousPageIndex = currentPageIndex - offset
            guard previousPageIndex >= 0,
                  let previousPage = document.page(at: previousPageIndex),
                  let result = searchInPage(segment, page: previousPage) else {
                continue
            }
            lastSearchPage = previousPage
            lastSearchLocation = result.bounds.origin
            return result
        }
        
        return nil
    }
    
    /// 在单个页面中搜索文本片段
    /// - Parameters:
    ///   - segment: 要搜索的文本片段
    ///   - page: 要搜索的页面
    /// - Returns: 搜索结果
    private func searchInPage(_ segment: TextSegment, page: PDFPage) -> SearchResult? {
        guard let pageContent = page.string else { return nil }
        
        // 1. 查找文本在页面中的位置
        let searchText = segment.text
        guard let range = pageContent.range(of: searchText) else { return nil }
        
        // 2. 转换为NSRange
        let nsRange = NSRange(
            range,
            in: pageContent
        )
        
        // 3. 获取文本边界
        guard let selection = page.selection(for: nsRange) else { return nil }
        let bounds = selection.bounds(for: page)
        
        // 4. 如果有上次的搜索位置，验证新位置是否合理
        if let lastLocation = lastSearchLocation {
            let distance = abs(bounds.origin.y - lastLocation.y)
            if distance > CGFloat(SearchConfig.positionTolerance) {
                // 如果位置差距太大，可能是找到了错误的匹配
                return nil
            }
        }
        
        return SearchResult(
            segment: segment,
            page: page,
            range: nsRange,
            bounds: bounds
        )
    }
    
    /// 清除搜索缓存
    func clearSearchCache() {
        lastSearchPage = nil
        lastSearchLocation = nil
    }
    
    /// 验证多个搜索结果的位置关系
    /// - Parameter results: 搜索结果数组
    /// - Returns: 验证结果
    func validatePositions(_ results: [SearchResult]) -> ValidationResult {
        guard results.count >= 2 else {
            // 如果只有一个结果，直接认为有效
            return ValidationResult(isValid: true, searchResults: results, errorType: nil)
        }
        
        // 按原始索引排序
        let sortedResults = results.sorted { $0.segment.originalIndex < $1.segment.originalIndex }
        
        // 1. 验证页面关系
        if !validatePageRelations(sortedResults) {
            return ValidationResult(isValid: false, searchResults: sortedResults, errorType: .differentPages)
        }
        
        // 2. 验证垂直位置关系
        if !validateVerticalPositions(sortedResults) {
            return ValidationResult(isValid: false, searchResults: sortedResults, errorType: .differentLines)
        }
        
        // 3. 验证水平位置关系
        if !validateHorizontalPositions(sortedResults) {
            return ValidationResult(isValid: false, searchResults: sortedResults, errorType: .wrongOrder)
        }
        
        // 4. 验证整体布局一致性
        if !validateLayoutConsistency(sortedResults) {
            return ValidationResult(isValid: false, searchResults: sortedResults, errorType: .inconsistentLayout)
        }
        
        return ValidationResult(isValid: true, searchResults: sortedResults, errorType: nil)
    }
    
    /// 验证页面关系
    private func validatePageRelations(_ results: [SearchResult]) -> Bool {
        var lastPage: PDFPage? = nil
        var lastBounds: CGRect = .zero
        
        for result in results {
            if let lastPage = lastPage {
                // 如果在不同页面，检查是否在合理范围内
                if result.page != lastPage {
                    // 检查是否是相邻页面的首尾
                    let lastPageBottom = lastBounds.maxY
                    let currentPageTop = result.bounds.minY
                    
                    // 如果不是相邻页面的合理位置，返回false
                    if abs(lastPageBottom - currentPageTop) > ValidationConfig.verticalTolerance {
                        return false
                    }
                }
            }
            
            lastPage = result.page
            lastBounds = result.bounds
        }
        
        return true
    }
    
    /// 验证垂直位置关系
    private func validateVerticalPositions(_ results: [SearchResult]) -> Bool {
        var lastY: CGFloat? = nil
        var lineCount = 0
        
        for result in results {
            let currentY = result.bounds.midY
            
            if let lastY = lastY {
                let verticalDifference = abs(currentY - lastY)
                
                // 如果垂直差距超过容差，增加行数计数
                if verticalDifference > ValidationConfig.verticalTolerance {
                    lineCount += 1
                    
                    // 如果行数差异过大，返回false
                    if lineCount > ValidationConfig.maxLineDifference {
                        return false
                    }
                }
            }
            
            lastY = currentY
        }
        
        return true
    }
    
    /// 验证水平位置关系
    private func validateHorizontalPositions(_ results: [SearchResult]) -> Bool {
        for i in 0..<results.count-1 {
            let current = results[i]
            let next = results[i+1]
            
            // 如果在同一行，检查水平顺序
            if abs(current.bounds.midY - next.bounds.midY) <= ValidationConfig.verticalTolerance {
                // 确保水平位置是按照正确顺序排列的
                if current.bounds.maxX > next.bounds.minX {
                    return false
                }
                
                // 检查间距是否合理
                let spacing = next.bounds.minX - current.bounds.maxX
                if spacing > ValidationConfig.horizontalTolerance {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// 验证整体布局一致性
    private func validateLayoutConsistency(_ results: [SearchResult]) -> Bool {
        var spacings: [CGFloat] = []
        
        // 计算相邻片段之间的间距
        for i in 0..<results.count-1 {
            let current = results[i]
            let next = results[i+1]
            
            // 如果在同一行
            if abs(current.bounds.midY - next.bounds.midY) <= ValidationConfig.verticalTolerance {
                let spacing = next.bounds.minX - current.bounds.maxX
                spacings.append(spacing)
            }
        }
        
        // 如果有多个间距，检查它们是否相近
        if spacings.count >= 2 {
            let averageSpacing = spacings.reduce(0, +) / CGFloat(spacings.count)
            
            for spacing in spacings {
                if abs(spacing - averageSpacing) > ValidationConfig.expectedSegmentSpacing {
                    return false
                }
            }
        }
        
        return true
    }
} 