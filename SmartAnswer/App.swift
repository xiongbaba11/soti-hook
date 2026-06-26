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

class AppState: ObservableObject {
    @Published var token: String = "" {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
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
    
    init() {
        self.token = UserDefaults.standard.string(forKey: "token") ?? ""
        self.modelName = UserDefaults.standard.string(forKey: "modelName") ?? "deepseek-chat"
        self.preferLocal = UserDefaults.standard.object(forKey: "preferLocal") as? Bool ?? true
        QuestionBankManager.shared.loadBanks()
        self.questionBanks = QuestionBankManager.shared.banks
        
        // Load bundled example bank on first launch
        if questionBanks.isEmpty {
            QuestionBankManager.shared.loadBundledBank()
            self.questionBanks = QuestionBankManager.shared.banks
        }
    }
}
