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
            
            // Fuzzy match - check if key parts overlap
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
        
        if ext == "txt" || ext == "csv" {
            return parseTextFile(url: url)
        } else if ext == "json" {
            return parseJSONFile(url: url)
        }
        return parseTextFile(url: url)
    }
    
    private func parseTextFile(url: URL) -> [Question] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var questions: [Question] = []
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        for line in lines {
            // Try JSON format per line
            if let data = line.data(using: .utf8),
               let q = try? JSONDecoder().decode(Question.self, from: data) {
                questions.append(Question(question: q.question, answer: q.answer, options: q.options, source: "local"))
                continue
            }
            
            // Try "question?answer" format
            let parts = line.components(separatedBy: ["?", "？", "|", "\t"])
            if parts.count >= 2 {
                let q = parts[0].trimmingCharacters(in: .whitespaces)
                let a = parts[1].trimmingCharacters(in: .whitespaces)
                if !q.isEmpty && !a.isEmpty {
                    questions.append(Question(question: q, answer: a, options: nil, source: "local"))
                }
            }
        }
        return questions
    }
    
    private func parseJSONFile(url: URL) -> [Question] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        
        if let arr = try? JSONDecoder().decode([Question].self, from: data) {
            return arr.map { Question(question: $0.question, answer: $0.answer, options: $0.options, source: "local") }
        }
        return []
    }
    
    var totalQuestions: Int {
        banks.reduce(0) { $0 + $1.questionCount }
    }
    
    var enabledBankNames: [String] {
        banks.filter { $0.enabled }.map { $0.name }
    }
}
