//
//  VoiceVerseApp.swift
//  VoiceVerse
//
//  Created by chii_magnus on 2024/12/21.
//

import SwiftUI

@main
struct VoiceVerseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // 使用系统默认命令
            CommandGroup(replacing: .newItem) {
                Button("打开 PDF...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenPDF"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            // 扩展系统 View 菜单
            CommandGroup(after: .toolbar) {
                // 缩放选项
                Button("放大") {
                    NotificationCenter.default.post(name: NSNotification.Name("ZoomIn"), object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("缩小") {
                    NotificationCenter.default.post(name: NSNotification.Name("ZoomOut"), object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("实际大小") {
                    NotificationCenter.default.post(name: NSNotification.Name("ActualSize"), object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                // 句子导航
                Button("下一句") {
                    NotificationCenter.default.post(name: NSNotification.Name("NextSentence"), object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                
                Divider()
                
                // 页面显示模式
                Button("单页") {
                    NotificationCenter.default.post(name: NSNotification.Name("SinglePage"), object: nil)
                }
                
                Button("单页连续") {
                    NotificationCenter.default.post(name: NSNotification.Name("SinglePageContinuous"), object: nil)
                }
                
                Button("双页") {
                    NotificationCenter.default.post(name: NSNotification.Name("TwoPages"), object: nil)
                }
                
                Button("双页连续") {
                    NotificationCenter.default.post(name: NSNotification.Name("TwoPagesContinuous"), object: nil)
                }
                
                Divider()
                
                // 页面导航
                Button("下一页") {
                    NotificationCenter.default.post(name: NSNotification.Name("NextPage"), object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("上一页") {
                    NotificationCenter.default.post(name: NSNotification.Name("PreviousPage"), object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}
