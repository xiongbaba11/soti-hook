import SwiftUI

@main
struct SmartAnswerApp: App {
    @StateObject private var appState = AppState()
    @State private var importedFileURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
        }
    }
    
    private func handleIncomingFile(_ url: URL) {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        
        let success = QuestionBankManager.shared.importBank(from: url)
        if success {
            appState.questionBanks = QuestionBankManager.shared.banks
        }
        appState.importResult = success
        appState.showImportAlert = true
    }
}

// MARK: - AI Provider
enum AIProvider: String, CaseIterable, Identifiable {
    case deepseek = "deepseek"
    case mimo = "mimo"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .mimo: return "MiMo (小米)"
        }
    }
    
    var models: [String] {
        switch self {
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        case .mimo: return ["MiMo-7B-RL"]
        }
    }
    
    var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .mimo: return "MiMo-7B-RL"
        }
    }
    
    var baseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/chat/completions"
        case .mimo: return "https://api.xiaomi.com/v1/chat/completions"
        }
    }
    
    var keyPlaceholder: String {
        switch self {
        case .deepseek: return "sk-..."
        case .mimo: return "小米API Key"
        }
    }
    
    var helpURL: String {
        switch self {
        case .deepseek: return "platform.deepseek.com"
        case .mimo: return "小米大模型开放平台"
        }
    }
}

class AppState: ObservableObject {
    @Published var token: String = "" {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }
    @Published var mimoToken: String = "" {
        didSet { UserDefaults.standard.set(mimoToken, forKey: "mimoToken") }
    }
    @Published var aiProvider: AIProvider = .deepseek {
        didSet { UserDefaults.standard.set(aiProvider.rawValue, forKey: "aiProvider") }
    }
    @Published var modelName: String = "deepseek-chat" {
        didSet { UserDefaults.standard.set(modelName, forKey: "modelName") }
    }
    @Published var preferLocal: Bool = true {
        didSet { UserDefaults.standard.set(preferLocal, forKey: "preferLocal") }
    }
    @Published var questionBanks: [QuestionBank] = []
    @Published var searchHistory: [SearchRecord] = []
    @Published var importResult: Bool?
    @Published var showImportAlert = false
    
    /// Current active token based on provider
    var activeToken: String {
        switch aiProvider {
        case .deepseek: return token
        case .mimo: return mimoToken
        }
    }
    
    init() {
        self.token = UserDefaults.standard.string(forKey: "token") ?? ""
        self.mimoToken = UserDefaults.standard.string(forKey: "mimoToken") ?? ""
        if let raw = UserDefaults.standard.string(forKey: "aiProvider"),
           let provider = AIProvider(rawValue: raw) {
            self.aiProvider = provider
        }
        self.modelName = UserDefaults.standard.string(forKey: "modelName") ?? AIProvider.deepseek.defaultModel
        self.preferLocal = UserDefaults.standard.object(forKey: "preferLocal") as? Bool ?? true
        QuestionBankManager.shared.loadBanks()
        self.questionBanks = QuestionBankManager.shared.banks
        
        if questionBanks.isEmpty {
            QuestionBankManager.shared.loadBundledBank()
            self.questionBanks = QuestionBankManager.shared.banks
        }
    }
}
