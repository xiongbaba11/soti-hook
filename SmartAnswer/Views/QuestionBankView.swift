import SwiftUI
import UniformTypeIdentifiers

struct QuestionBankView: View {
    @EnvironmentObject var appState: AppState
    @State private var showImporter = false
    @State private var importSuccess: Bool?
    @State private var showImportResult = false
    
    var body: some View {
        NavigationView {
            List {
                // Existing banks
                Section {
                    if appState.questionBanks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("暂无题库")
                                .font(.headline)
                            Text("点击下方导入，或从其他App分享文件到本App")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    
                    ForEach(appState.questionBanks) { bank in
                        HStack(spacing: 12) {
                            Text(bankIcon(bank.name))
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
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
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            QuestionBankManager.shared.deleteBank(appState.questionBanks[index])
                        }
                        appState.questionBanks = QuestionBankManager.shared.banks
                    }
                } header: {
                    Text("已导入题库")
                }
                
                // Import section
                Section {
                    Button(action: {
                        showImporter = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("导入题库文件")
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.green)
                            Text("从其他App导入")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text("在微信、QQ等App中打开题库文件 → 分享 → 选择「智能答题」")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("导入新题库")
                } footer: {
                    Text("支持格式: .txt (题目?答案) · .json")
                }
                
                // Stats
                Section("题库统计") {
                    HStack {
                        Text("总题目数")
                        Spacer()
                        Text("\(QuestionBankManager.shared.totalQuestions)")
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("已启用题库")
                        Spacer()
                        Text("\(appState.questionBanks.filter { $0.enabled }.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("题库管理")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [
                    .plainText,
                    .json,
                    UTType(filenameExtension: "txt") ?? .plainText,
                    UTType(filenameExtension: "csv") ?? .plainText
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
                    
                    let success = QuestionBankManager.shared.importBank(from: url)
                    appState.questionBanks = QuestionBankManager.shared.banks
                    importSuccess = success
                    showImportResult = true
                    
                case .failure(let error):
                    print("File import error: \(error)")
                    importSuccess = false
                    showImportResult = true
                }
            }
            .alert(isPresented: $showImportResult) {
                if importSuccess == true {
                    return Alert(
                        title: Text("✅ 导入成功"),
                        message: Text("题库已成功导入，可以在「拍照」或「录屏」中使用"),
                        dismissButton: .default(Text("确定")) { importSuccess = nil }
                    )
                } else {
                    return Alert(
                        title: Text("❌ 导入失败"),
                        message: Text("请确保文件格式正确（.txt 或 .json）"),
                        dismissButton: .default(Text("确定")) { importSuccess = nil }
                    )
                }
            }
        }
    }
    
    private func bankIcon(_ name: String) -> String {
        if name.contains("驾") { return "🚗" }
        if name.contains("学习") || name.contains("考试") { return "📖" }
        if name.contains("安全") { return "🛡️" }
        if name.contains("数学") { return "🔢" }
        if name.contains("英语") || name.contains("English") { return "🔤" }
        return "📝"
    }
}
