import Foundation
import AVFoundation
import SwiftUI

class CosyVoiceManager: NSObject, ObservableObject {
    // API相关配置
    private let apiBaseURL = "https://api.cosyvoice.com"  // 示例URL，需要替换为实际的API地址
    @AppStorage("COSYVOICE_API_KEY") private var apiKey: String = ""
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isPlaying = false
    @Published var isLoading = false
    
    override init() {
        super.init()
    }
    
    /// 将文本转换为语音
    /// - Parameters:
    ///   - text: 需要转换的文本
    ///   - completion: 完成回调，返回是否成功
    func synthesize(text: String, completion: @escaping (Bool) -> Void) {
        guard !apiKey.isEmpty else {
            print("错误：未设置API密钥")
            completion(false)
            return
        }
        
        isLoading = true
        
        // 准备请求URL和参数
        guard let url = URL(string: "\(apiBaseURL)/tts") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "Authorization")
        
        // 请求参数
        let parameters: [String: Any] = [
            "text": text,
            "voice_id": "chinese_female_1",  // 示例voice_id，需要根据实际API调整
            "speed": 1.0,
            "volume": 1.0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("错误：参数序列化失败 - \(error.localizedDescription)")
            completion(false)
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("错误：API请求失败 - \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("错误：未收到数据")
                    completion(false)
                    return
                }
                
                // 播放返回的音频数据
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.delegate = self
                    self.audioPlayer?.play()
                    self.isPlaying = true
                    completion(true)
                } catch {
                    print("错误：音频播放失败 - \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
        
        task.resume()
    }
    
    /// 暂停播放
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    /// 继续播放
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    /// 停止播放
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

// MARK: - AVAudioPlayerDelegate
extension CosyVoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
} 