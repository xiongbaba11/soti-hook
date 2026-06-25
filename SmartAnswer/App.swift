import SwiftUI

@main
struct SmartAnswerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
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
    
    init() {
        self.token = UserDefaults.standard.string(forKey: "token") ?? ""
        self.modelName = UserDefaults.standard.string(forKey: "modelName") ?? "deepseek-chat"
        self.preferLocal = UserDefaults.standard.object(forKey: "preferLocal") as? Bool ?? true
        QuestionBankManager.shared.loadBanks()
        self.questionBanks = QuestionBankManager.shared.banks
    }
}
