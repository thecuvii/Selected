//
//  Defaults.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//

import Defaults
import Foundation

// Service Configuration
extension Defaults.Keys {
    static let aiService = Key<String>("AIService", default: "OpenAI")
    
    // OpenAI
    static let openAIAPIKey = Key<String>("OpenAIAPIKey", default: "")
    static let openAIAPIHost = Key<String>("OpenAIAPIHost",default: "api.openai.com")
    
    // Gemini
    static let geminiAPIKey = Key<String>("GeminiAPIKey", default: "")
    static let geminiAPIHost = Key<String>("GeminiAPIHost", default: "")
}


// 应用程序支持目录的URL
let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Selected/", isDirectory: true)

