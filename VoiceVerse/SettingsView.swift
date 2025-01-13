import SwiftUI

struct SettingsView: View {
    @AppStorage("COSYVOICE_API_KEY") private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("CosyVoice API设置")) {
                SecureField("API密钥", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                Text("请在此处输入您的CosyVoice API密钥")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("完成") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
} 