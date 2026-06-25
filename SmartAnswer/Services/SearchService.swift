import Foundation

enum SearchResult {
    case found(Question)
    case notFound
    case error(String)
}

class SearchService {
    static let shared = SearchService()
    
    func search(query: String, apiKey: String, model: String, preferLocal: Bool) async -> SearchResult {
        // Step 1: Try local bank
        if preferLocal, let localResult = QuestionBankManager.shared.search(query) {
            return .found(localResult)
        }
        
        // Step 2: Call DeepSeek
        guard !apiKey.isEmpty else {
            if let localResult = QuestionBankManager.shared.search(query) {
                return .found(localResult)
            }
            return .error("请先设置API Key")
        }
        
        do {
            let answer = try await DeepSeekService.shared.ask(question: query, apiKey: apiKey, model: model)
            if answer.isEmpty {
                return .notFound
            }
            let question = Question(question: query, answer: answer, options: nil, source: "deepseek")
            return .found(question)
        } catch {
            // Fallback to local if API fails
            if let localResult = QuestionBankManager.shared.search(query) {
                return .found(localResult)
            }
            return .error("API调用失败: \error.localizedDescription)")
        }
    }
}
