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
    @StateObject private var sentenceManager = SentenceManager()
    @StateObject private var speechManager: SpeechManager
    @State private var pdfDocument: PDFDocument?
    @State private var showFileImporter = false
    @State private var documentTitle: String = ""
    
    init() {
        let sentenceManager = SentenceManager()
        let speechManager = SpeechManager(sentenceManager: sentenceManager)
        _sentenceManager = StateObject(wrappedValue: sentenceManager)
        _speechManager = StateObject(wrappedValue: speechManager)
    }
    
    var body: some View {
        NavigationStack {
            if let pdfDocument = pdfDocument {
                PDFViewerView(
                    pdfDocument: pdfDocument,
                    sentenceManager: sentenceManager,
                    speechManager: speechManager
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(documentTitle)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        HStack(spacing: 12) {
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("PreviousPage"), object: nil)
                            }) {
                                Image(systemName: "chevron.left")
                            }
                            .help("上一页")
                            
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("NextPage"), object: nil)
                            }) {
                                Image(systemName: "chevron.right")
                            }
                            .help("下一页")
                            
                            Divider()
                            
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("ZoomOut"), object: nil)
                            }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .help("缩小")
                            
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("ZoomIn"), object: nil)
                            }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .help("放大")
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 8) {
                            Button(action: {
                                if speechManager.isPlaying {
                                    speechManager.pause()
                                } else if let text = pdfDocument.string {
                                    if sentenceManager.getCurrentSentence().isEmpty {
                                        sentenceManager.setText(text)
                                    }
                                    speechManager.speak()
                                }
                            }) {
                                Label(
                                    speechManager.isPlaying ? "暂停" : "继续",
                                    systemImage: speechManager.isPlaying ? "pause.fill" : "play.fill"
                                )
                            }
                            .help(speechManager.isPlaying ? "暂停朗读" : "继续朗读")
                            
                            Button(action: {
                                speechManager.stop()
                            }) {
                                Label("停止", systemImage: "stop.fill")
                            }
                            .help("停止朗读")
                        }
                    }
                }
                .toolbarBackground(.visible, for: .windowToolbar)
                .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
            } else {
                VStack(spacing: 20) {
                    Button(action: {
                        showFileImporter = true
                    }) {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("请选择一个 PDF 文件开始阅读")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("VoiceVerse")
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
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
                    documentTitle = file.lastPathComponent
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .onAppear {
            // 监听打开 PDF 的通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenPDF"),
                object: nil,
                queue: .main
            ) { _ in
                showFileImporter = true
            }
        }
    }
}

#Preview {
    ContentView()
}
