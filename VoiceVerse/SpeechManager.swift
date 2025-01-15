import Foundation
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    let synthesizer = AVSpeechSynthesizer()
    private let sentenceManager: SentenceManager
    private let cosyVoiceManager = CosyVoiceManager()
    var isUserInitiated = false
    
    // 语音引擎选择
    enum VoiceEngine {
        case system
        case cosyVoice
    }
    @Published var currentEngine: VoiceEngine = .system
    
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
        
        switch currentEngine {
        case .system:
            let utterance = AVSpeechUtterance(string: sentence)
            configureUtterance(utterance)
            synthesizer.speak(utterance)
            isPlaying = true
            
        case .cosyVoice:
            cosyVoiceManager.synthesize(text: sentence) { [weak self] success in
                if success {
                    self?.isPlaying = true
                } else {
                    // 如果CosyVoice失败，回退到系统语音
                    print("CosyVoice合成失败，回退到系统语音")
                    self?.currentEngine = .system
                    self?.speakSentence(sentence)
                }
            }
        }
    }
    
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
    }
    
    func stop() {
        print("🔴 stop() called")
        switch currentEngine {
        case .system:
            synthesizer.stopSpeaking(at: .immediate)
        case .cosyVoice:
            cosyVoiceManager.stop()
        }
        isPlaying = false
        
        // 只有在非用户手动触发时才重置状态
        if !isUserInitiated {
            sentenceManager.reset()
            // 清除高亮也通过 sentenceManager 处理
            sentenceManager.onNextSentence?("")
        }
    }
    
    func pause() {
        print("⏸️ Pausing speech")
        switch currentEngine {
        case .system:
            synthesizer.pauseSpeaking(at: .immediate)
        case .cosyVoice:
            cosyVoiceManager.pause()
        }
        isPlaying = false
    }
    
    func resume() {
        print("▶️ Resuming speech")
        switch currentEngine {
        case .system:
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
                isPlaying = true
            } else {
                // 如果不是暂停状态，可能需要重新开始朗读当前句子
                if !sentenceManager.getCurrentSentence().isEmpty {
                    speakSentence(sentenceManager.getCurrentSentence())
                }
            }
        case .cosyVoice:
            if !sentenceManager.getCurrentSentence().isEmpty {
                cosyVoiceManager.resume()
                isPlaying = true
            }
        }
    }
    
    // 朗读下一句
    func speakNext() {
        print("🟡 speakNext() called - user initiated")
        // 标记为用户手动触发
        isUserInitiated = true
        
        // 如果当前正在朗读，先停止播放但不重置状态
        if isPlaying {
            stop()
        }
        
        // 获取并朗读下一句
        if let nextSentence = sentenceManager.nextSentence() {
            // 直接朗读当前句子
            speakSentence(nextSentence)
        } else {
            // 如果没有下一句了，触发完成回调
            print("🔴 No more sentences to speak")
            onFinishSpeaking?()
            // 清除高亮
            sentenceManager.onNextSentence?("")
        }
    }
    
    // 切换语音引擎
    func toggleVoiceEngine() {
        stop() // 先停止当前播放
        currentEngine = currentEngine == .system ? .cosyVoice : .system
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
