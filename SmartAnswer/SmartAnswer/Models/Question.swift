import Foundation

struct Question: Identifiable, Codable {
    let id = UUID()
    let question: String
    let answer: String
    let options: [String]?
    let source: String // "local" or "deepseek"
    
    enum CodingKeys: String, CodingKey {
        case question, answer, options, source
    }
}

struct QuestionBank: Identifiable, Codable {
    let id: UUID
    var name: String
    var fileName: String
    var questionCount: Int
    var enabled: Bool
    var importDate: Date
}

struct SearchRecord: Identifiable, Codable {
    let id = UUID()
    let question: String
    let answer: String
    let source: String
    let timestamp: Date
}

struct DeepSeekResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

struct DeepSeekRequest: Codable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}
