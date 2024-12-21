import Foundation
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    private let synthesizer = AVSpeechSynthesizer()
    private let sentenceManager: SentenceManager
    
    var onFinishSpeaking: (() -> Void)?
    
    init(sentenceManager: SentenceManager) {
        self.sentenceManager = sentenceManager
        super.init()
        synthesizer.delegate = self
    }
    
    func speak() {
        guard let sentence = sentenceManager.nextSentence() else {
            stop()
            return
        }
        
        // 直接朗读当前句子
        speakSentence(sentence)
        
        // 句子变化会自动触发 onNextSentence 回调
    }
    
    private func speakSentence(_ sentence: String) {
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
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinishSpeaking?()
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
