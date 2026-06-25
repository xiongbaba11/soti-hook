import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeyInput = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("AI 模型") {
                    HStack {
                        Text("API Key")
                        Spacer()
                        SecureField("sk-...", text: $apiKeyInput)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 200)
                    }
                    
                    HStack {
                        Text("模型")
                        Spacer()
                        Text(appState.modelName)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("优先本地题库", isOn: $appState.preferLocal)
                }
                
                Section {
                    NavigationLink("搜索历史 (\(appState.searchHistory.count))") {
                        HistoryView()
                    }
                }
                
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { apiKeyInput = appState.apiKey }
            .onChange(of: apiKeyInput) { newValue in
                appState.apiKey = newValue
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            if appState.searchHistory.isEmpty {
                Text("暂无搜索记录")
                    .foregroundColor(.secondary)
            }
            ForEach(appState.searchHistory) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.question)
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack {
                        Text(record.answer)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        Spacer()
                        Text(record.source == "local" ? "📚" : "🤖")
                        Text(record.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("搜索历史")
    }
}
