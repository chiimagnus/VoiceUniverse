import Foundation
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isPlaying = false
    @Published var currentSentence: String = ""
    @Published var currentText: String = ""
    
    private var currentUtterance: AVSpeechUtterance?
    private var currentIndex: Int = 0
    private var isPaused: Bool = false
    
    var onHighlight: ((String) -> Void)?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(text: String) {
        currentText = text
        isPaused = false
        
        if synthesizer.isPaused {
            // 如果是暂停状态，从当前位置继续
            let remainingText = String(text[text.index(text.startIndex, offsetBy: currentIndex)...])
            let utterance = AVSpeechUtterance(string: remainingText)
            configureUtterance(utterance)
            currentUtterance = utterance
            synthesizer.speak(utterance)
        } else {
            // 从头开始朗读
            let utterance = AVSpeechUtterance(string: text)
            configureUtterance(utterance)
            currentUtterance = utterance
            currentIndex = 0
            synthesizer.speak(utterance)
        }
        
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
        isPaused = false
        currentUtterance = nil
        currentText = ""
        currentIndex = 0
        currentSentence = ""
    }
    
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        isPaused = true
    }
    
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
        } else if isPaused && !currentText.isEmpty {
            // 如果处于暂停状态但合成器没有暂停，从当前位置重新开始
            let remainingText = String(currentText[currentText.index(currentText.startIndex, offsetBy: currentIndex)...])
            let utterance = AVSpeechUtterance(string: remainingText)
            configureUtterance(utterance)
            currentUtterance = utterance
            synthesizer.speak(utterance)
            isPlaying = true
            isPaused = false
        }
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let sentence = (utterance.speechString as NSString).substring(with: characterRange)
            currentSentence = sentence
            onHighlight?(sentence)
            currentIndex = characterRange.location
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
            currentSentence = ""
            currentUtterance = nil
            isPaused = false
            // 保持 currentText 和 currentIndex，以便支持继续朗读
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = false
            isPaused = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isPlaying = true
            isPaused = false
        }
    }
} 
