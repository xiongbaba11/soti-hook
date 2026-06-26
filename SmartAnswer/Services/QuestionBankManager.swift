import Foundation

class QuestionBankManager {
    static let shared = QuestionBankManager()
    
    private(set) var banks: [QuestionBank] = []
    private var questions: [String: [Question]] = [:]
    
    private var documentsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func loadBanks() {
        let banksURL = documentsPath.appendingPathComponent("banks.json")
        if let data = try? Data(contentsOf: banksURL),
           let decoded = try? JSONDecoder().decode([QuestionBank].self, from: data) {
            banks = decoded
            for bank in banks {
                loadQuestions(for: bank)
            }
        }
    }
    
    func saveBanks() {
        let banksURL = documentsPath.appendingPathComponent("banks.json")
        try? JSONEncoder().encode(banks).write(to: banksURL)
    }
    
    func importBank(from url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let destURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            
            let qs = parseFile(url: destURL)
            let bank = QuestionBank(
                id: UUID(),
                name: fileName.replacingOccurrences(of: "." + url.pathExtension, with: ""),
                fileName: fileName,
                questionCount: qs.count,
                enabled: true,
                importDate: Date()
            )
            
            banks.append(bank)
            questions[fileName] = qs
            saveBanks()
            saveQuestions(for: bank)
            return true
        } catch {
            print("Import error: \(error)")
            return false
        }
    }
    
    func toggleBank(_ bank: QuestionBank) {
        if let idx = banks.firstIndex(where: { $0.id == bank.id }) {
            banks[idx].enabled.toggle()
            saveBanks()
        }
    }
    
    func deleteBank(_ bank: QuestionBank) {
        banks.removeAll { $0.id == bank.id }
        questions.removeValue(forKey: bank.fileName)
        let fileURL = documentsPath.appendingPathComponent(bank.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        saveBanks()
    }
    
    func search(_ query: String) -> Question? {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for bank in banks where bank.enabled {
            guard let qs = questions[bank.fileName] else { continue }
            
            // Exact match
            for q in qs {
                if q.question.lowercased().contains(queryLower) || queryLower.contains(q.question.lowercased()) {
                    return q
                }
            }
            
            // Fuzzy match
            let queryParts = queryLower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            var bestMatch: Question?
            var bestScore = 0
            
            for q in qs {
                let qParts = q.question.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let commonCount = queryParts.filter { qp in qParts.contains { $0.contains(qp) || qp.contains($0) } }.count
                let score = commonCount * 100 / max(queryParts.count, 1)
                if score > bestScore && score > 50 {
                    bestScore = score
                    bestMatch = q
                }
            }
            
            if let match = bestMatch {
                return match
            }
        }
        return nil
    }
    
    private func loadQuestions(for bank: QuestionBank) {
        let qsURL = documentsPath.appendingPathComponent(bank.fileName + ".questions.json")
        if let data = try? Data(contentsOf: qsURL),
           let decoded = try? JSONDecoder().decode([Question].self, from: data) {
            questions[bank.fileName] = decoded
        } else {
            let fileURL = documentsPath.appendingPathComponent(bank.fileName)
            questions[bank.fileName] = parseFile(url: fileURL)
        }
    }
    
    private func saveQuestions(for bank: QuestionBank) {
        guard let qs = questions[bank.fileName] else { return }
        let qsURL = documentsPath.appendingPathComponent(bank.fileName + ".questions.json")
        try? JSONEncoder().encode(qs).write(to: qsURL)
    }
    
    private func parseFile(url: URL) -> [Question] {
        let ext = url.pathExtension.lowercased()
        
        if ext == "json" {
            return parseJSONFile(url: url)
        }
        // Default: try text file (supports JSON-per-line, q/a/ans format, and plain text)
        return parseTextFile(url: url)
    }
    
    private func parseTextFile(url: URL) -> [Question] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var result: [Question] = []
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            
            // Try q/a/ans format (小包搜题 format)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let q = obj["q"] as? String, !q.isEmpty {
                let options = obj["a"] as? [String]
                let ansKey = obj["ans"] as? String ?? ""
                let answer = resolveAnswer(ansKey: ansKey, options: options)
                result.append(Question(question: q, answer: answer, options: options, source: "local"))
                continue
            }
            
            // Try standard question/answer JSON format
            if let q = try? JSONDecoder().decode(Question.self, from: data) {
                result.append(Question(question: q.question, answer: q.answer, options: q.options, source: "local"))
                continue
            }
            
            // Try "question?answer" plain text format
            let parts = line.components(separatedBy: ["?", "？", "|", "\t"])
            if parts.count >= 2 {
                let q = parts[0].trimmingCharacters(in: .whitespaces)
                let a = parts[1].trimmingCharacters(in: .whitespaces)
                if !q.isEmpty && !a.isEmpty {
                    result.append(Question(question: q, answer: a, options: nil, source: "local"))
                }
            }
        }
        return result
    }
    
    private func parseJSONFile(url: URL) -> [Question] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        
        // Try as array of q/a/ans objects
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr.compactMap { obj -> Question? in
                guard let q = obj["q"] as? String, !q.isEmpty else { return nil }
                let options = obj["a"] as? [String]
                let ansKey = obj["ans"] as? String ?? ""
                let answer = resolveAnswer(ansKey: ansKey, options: options)
                return Question(question: q, answer: answer, options: options, source: "local")
            }
        }
        
        // Try as array of Question objects
        if let arr = try? JSONDecoder().decode([Question].self, from: data) {
            return arr.map { Question(question: $0.question, answer: $0.answer, options: $0.options, source: "local") }
        }
        
        return []
    }
    
    /// Resolve answer key (A/B/C/D) to actual answer text
    private func resolveAnswer(ansKey: String, options: [String]?) -> String {
        guard let options = options, !ansKey.isEmpty else { return ansKey }
        
        let index: Int
        switch ansKey.uppercased() {
        case "A": index = 0
        case "B": index = 1
        case "C": index = 2
        case "D": index = 3
        case "E": index = 4
        default: return ansKey
        }
        
        if index < options.count {
            return "\(ansKey). \(options[index])"
        }
        return ansKey
    }
    
    var totalQuestions: Int {
        banks.reduce(0) { $0 + $1.questionCount }
    }
    
    var enabledBankNames: [String] {
        banks.filter { $0.enabled }.map { $0.name }
    }
    
    /// Load bundled example question bank from app bundle
    func loadBundledBank() {
        guard let url = Bundle.main.url(forResource: "xiaobao", withExtension: "txt") else {
            print("Bundled bank not found")
            return
        }
        
        let qs = parseFile(url: url)
        guard !qs.isEmpty else { return }
        
        let bank = QuestionBank(
            id: UUID(),
            name: "电钳工题库（示例）",
            fileName: "xiaobao.txt",
            questionCount: qs.count,
            enabled: true,
            importDate: Date()
        )
        
        banks.append(bank)
        questions["xiaobao.txt"] = qs
        saveBanks()
        saveQuestions(for: bank)
    }
}
