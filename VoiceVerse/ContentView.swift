//
//  ContentView.swift
//  VoiceVerse
//
//  Created by chii_magnus on 2024/12/21.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var pdfDocument: PDFDocument?
    @State private var showFileImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏 - 添加 zIndex 确保始终在最上层
            HStack {
                Button("打开 PDF") {
                    showFileImporter = true
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                if pdfDocument != nil {
                    HStack(spacing: 16) {
                        Button(action: {
                            if speechManager.isPlaying {
                                speechManager.pause()
                            } else if let text = pdfDocument?.string {
                                if speechManager.currentText.isEmpty {
                                    speechManager.speak(text: text)
                                } else {
                                    speechManager.resume()
                                }
                            }
                        }) {
                            Label(
                                speechManager.isPlaying ? "暂停" : "继续",
                                systemImage: speechManager.isPlaying ? "pause.fill" : "play.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            speechManager.stop()
                        }) {
                            Label("停止", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .zIndex(1) // 确保工具栏始终在最上层
            
            // PDF 查看区域
            if let pdfDocument = pdfDocument {
                PDFViewerView.create(pdfDocument: pdfDocument, speechManager: speechManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0) // PDF 视图在底层
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("请选择一个 PDF 文件开始阅读")
                        .font(.title2)
                    Button("打开 PDF") {
                        showFileImporter = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                guard let file = files.first else { return }
                guard file.startAccessingSecurityScopedResource() else { return }
                defer { file.stopAccessingSecurityScopedResource() }
                
                if let document = PDFDocument(url: file) {
                    pdfDocument = document
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
