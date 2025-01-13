import Foundation
import AVFoundation
import SwiftUI

class CosyVoiceManager: NSObject, ObservableObject {
    // 本地服务配置
    private let serviceURL = "http://localhost:50000/tts"  // 本地CosyVoice服务地址
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isPlaying = false
    @Published var isLoading = false
    
    // 语音模型配置
    enum VoiceModel: String {
        case sft = "sft"
        case zeroShot = "zero_shot"
        case crossLingual = "cross_lingual"
        case instruct = "instruct"
    }
    
    override init() {
        super.init()
    }
    
    /// 将文本转换为语音
    /// - Parameters:
    ///   - text: 需要转换的文本
    ///   - model: 使用的模型类型
    ///   - completion: 完成回调，返回是否成功
    func synthesize(text: String, model: VoiceModel = .sft, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        // 准备请求URL和参数
        guard let url = URL(string: serviceURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 请求参数
        let parameters: [String: Any] = [
            "text": text,
            "mode": model.rawValue,
            "speaker": "中文女",  // 对于sft模式
            "stream": false
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
                    print("错误：服务请求失败 - \(error.localizedDescription)")
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