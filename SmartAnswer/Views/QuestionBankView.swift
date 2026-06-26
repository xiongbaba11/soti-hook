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
                        VStack(spacing: 16) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(DuoColors.orange.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 32))
                                    .foregroundColor(DuoColors.orange)
                            }
                            VStack(spacing: 8) {
                                Text("暂无题库")
                                    .font(.system(size: 18, weight: .bold))
                                Text("点击下方导入，或从其他App分享")
                                    .font(.system(size: 14))
                                    .foregroundColor(DuoColors.gray)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    
                    ForEach(appState.questionBanks) { bank in
                        HStack(spacing: 14) {
                            Text(bankIcon(bank.name))
                                .font(.system(size: 28))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bank.name)
                                    .font(.system(size: 16, weight: .semibold))
                                Text("\(bank.questionCount) 题 · \(bank.importDate, style: .date)")
                                    .font(.system(size: 13))
                                    .foregroundColor(DuoColors.gray)
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
                            .tint(DuoColors.green)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { indexSet in
                        withAnimation {
                            for index in indexSet {
                                QuestionBankManager.shared.deleteBank(appState.questionBanks[index])
                            }
                            appState.questionBanks = QuestionBankManager.shared.banks
                        }
                    }
                } header: {
                    Text("已导入题库")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                }
                
                // Import section
                Section {
                    Button(action: { showImporter = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(DuoColors.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("导入题库文件")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DuoColors.blue)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(DuoColors.green)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("从其他App导入")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Text("在微信、QQ中打开文件 → 分享 → 选择「智能答题」")
                            .font(.system(size: 13))
                            .foregroundColor(DuoColors.gray)
                            .padding(.leading, 44)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("导入新题库")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                } footer: {
                    Text("支持 .txt / .json 格式")
                        .font(.system(size: 12))
                }
                
                // Stats
                Section {
                    HStack {
                        Text("总题目数")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(QuestionBankManager.shared.totalQuestions)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DuoColors.green)
                    }
                    HStack {
                        Text("已启用题库")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(appState.questionBanks.filter { $0.enabled }.count)")
                            .font(.system(size: 15))
                            .foregroundColor(DuoColors.gray)
                    }
                } header: {
                    Text("题库统计")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                }
            }
            .listStyle(.insetGrouped)
            .background(DuoColors.background)
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
                        message: Text("题库已导入，可以在拍照或录屏中使用"),
                        dismissButton: .default(Text("确定")) { importSuccess = nil }
                    )
                } else {
                    return Alert(
                        title: Text("❌ 导入失败"),
                        message: Text("请确保文件格式正确"),
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
