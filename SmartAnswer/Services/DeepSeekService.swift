import Foundation

class DeepSeekService {
    static let shared = DeepSeekService()
    
    private let url = URL(string: "https://api.deepseek.com/chat/completions")!
    
    func ask(question: String, token: String, model: String) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        
        let body = DeepSeekRequest(
            model: model,
            messages: [
                DeepSeekRequest.Message(role: "system", content: "你是答题助手，直接给答案不解释。选择题只给选项字母，填空题直接给内容。"),
                DeepSeekRequest.Message(role: "user", content: question)
            ],
            max_tokens: 512,
            temperature: 0.1
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        return result.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
