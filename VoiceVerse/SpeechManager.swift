import Foundation
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    private let synthesizer = AVSpeechSynthesizer()
    private let sentenceManager: SentenceManager
    var isUserInitiated = false
    
    var onFinishSpeaking: (() -> Void)?
    var onFinishSentence: (() -> Void)?
    
    init(sentenceManager: SentenceManager) {
        self.sentenceManager = sentenceManager
        super.init()
        synthesizer.delegate = self
    }
    
    func speak() {
        print("🔵 speak() called - auto mode")
        isUserInitiated = false  // 系统自动朗读
        guard let sentence = sentenceManager.nextSentence() else {
            stop()
            return
        }
        
        // 直接朗读当前句子
        speakSentence(sentence)
    }
    
    private func speakSentence(_ sentence: String) {
        print("🟣 speakSentence() called with: \(sentence)")
        let utterance = AVSpeechUtterance(string: sentence)
        configureUtterance(utterance)
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
    }
    
    func stop() {
        print("🔴 stop() called")
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        sentenceManager.reset()
        // 清除高亮也通过 sentenceManager 处理
        sentenceManager.onNextSentence?("")
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
    }
    
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
        }
    }
    
    // 朗读下一句
    func speakNext() {
        print("🟡 speakNext() called - user initiated")
        // 标记为用户手动触发
        isUserInitiated = true
        
        // 如果当前正在朗读，先停止
        if isPlaying {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // 获取并朗读下一句
        if let nextSentence = sentenceManager.nextSentence() {
            // 直接朗读当前句子
            speakSentence(nextSentence)
        }
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            print("🟢 didFinish called, isUserInitiated: \(isUserInitiated)")
            onFinishSentence?()  // 先清除当前句子的高亮
            
            // 短暂延迟后再处理下一句，确保高亮清除效果可见
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒延迟
            
            // 只有在非用户手动触发且不是最后一句时，才自动朗读下一句
            if !isUserInitiated && !sentenceManager.isLastSentence {
                print("🔵 Auto proceeding to next sentence")
                speak()  // 自动朗读下一句
            } else {
                print("🟣 Triggering onFinishSpeaking")
                onFinishSpeaking?()  // 否则只触发完成回调
            }
            
            // 重置标志
            isUserInitiated = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
        }
    }
} 
