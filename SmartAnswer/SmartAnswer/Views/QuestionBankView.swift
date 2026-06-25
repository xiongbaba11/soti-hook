import SwiftUI
import UniformTypeIdentifiers

struct QuestionBankView: View {
    @EnvironmentObject var appState: AppState
    @State private var showImporter = false
    @State private var importSuccess: Bool?
    
    var body: some View {
        NavigationView {
            List {
                Section("已导入题库") {
                    if appState.questionBanks.isEmpty {
                        Text("暂无题库，点击下方导入")
                            .foregroundColor(.secondary)
                    }
                    ForEach(appState.questionBanks) { bank in
                        HStack {
                            Text(bankIcon(bank.name))
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bank.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("\(bank.questionCount) 题 · \(bank.importDate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { bank.enabled },
                                set: { _ in
                                    QuestionBankManager.shared.toggleBank(bank)
                                    appState.questionBanks = QuestionBankManager.shared.banks
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            QuestionBankManager.shared.deleteBank(appState.questionBanks[index])
                        }
                        appState.questionBanks = QuestionBankManager.shared.banks
                    }
                }
                
                Section {
                    Button(action: { showImporter = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("导入题库文件")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("导入新题库")
                } footer: {
                    Text("支持格式: 文本 (.txt) · JSON (.json)")
                }
                
                Section("题库统计") {
                    HStack {
                        Text("总题目数")
                        Spacer()
                        Text("\(QuestionBankManager.shared.totalQuestions)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("题库管理")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.plainText, .json, .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                    
                    importSuccess = QuestionBankManager.shared.importBank(from: url)
                    appState.questionBanks = QuestionBankManager.shared.banks
                }
            }
            .alert(importSuccess == true ? "导入成功" : "导入失败", isPresented: Binding(
                get: { importSuccess != nil },
                set: { if !$0 { importSuccess = nil } }
            )) {
                Button("确定") { importSuccess = nil }
            }
        }
    }
    
    private func bankIcon(_ name: String) -> String {
        if name.contains("驾") { return "🚗" }
        if name.contains("学习") { return "📖" }
        if name.contains("安全") { return "🛡️" }
        return "📝"
    }
}
