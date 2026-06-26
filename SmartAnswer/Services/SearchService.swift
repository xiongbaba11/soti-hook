import Foundation

enum SearchResult {
    case found(Question)
    case notFound
    case error(String)
}

class SearchService {
    static let shared = SearchService()
    
    func search(query: String, token: String, model: String, provider: AIProvider, preferLocal: Bool) async -> SearchResult {
        // Step 1: Try local bank
        if preferLocal, let localResult = QuestionBankManager.shared.search(query) {
            return .found(localResult)
        }
        
        // Step 2: Call AI
        guard !token.isEmpty else {
            if let localResult = QuestionBankManager.shared.search(query) {
                return .found(localResult)
            }
            return .error("请先在设置中配置 \(provider.displayName) API Key")
        }
        
        do {
            let answer = try await DeepSeekService.shared.ask(question: query, token: token, model: model, provider: provider)
            if answer.isEmpty {
                return .notFound
            }
            let question = Question(question: query, answer: answer, options: nil, source: provider.displayName)
            return .found(question)
        } catch {
            // Fallback to local if API fails
            if let localResult = QuestionBankManager.shared.search(query) {
                return .found(localResult)
            }
            return .error("\(provider.displayName) 调用失败: \(error.localizedDescription)")
        }
    }
}
