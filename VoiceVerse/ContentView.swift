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
        NavigationSplitView {
            if let pdfDocument = pdfDocument {
                // 左侧栏：PDF缩略图
                PDFThumbnailView(pdfDocument: pdfDocument)
            } else {
                // 左侧栏：空状态
                Text("请打开一个 PDF 文件")
                    .foregroundColor(.secondary)
            }
        } detail: {
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
                }
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

struct PDFThumbnailView: View {
    let pdfDocument: PDFDocument
    
    var body: some View {
        List {
            ForEach(0..<pdfDocument.pageCount, id: \.self) { index in
                if let page = pdfDocument.page(at: index) {
                    ThumbnailCell(page: page, pageNumber: index + 1)
                        .frame(height: 160)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct ThumbnailCell: View {
    let page: PDFPage
    let pageNumber: Int
    
    var body: some View {
        VStack(spacing: 4) {
            let thumbnail = page.thumbnail(of: CGSize(width: 160, height: 120), for: .artBox)
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(radius: 1)
            
            Text("第 \(pageNumber) 页")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(
                name: NSNotification.Name("GoToPage"),
                object: nil,
                userInfo: ["pageIndex": pageNumber - 1]
            )
        }
    }
}

#Preview {
    ContentView()
}

