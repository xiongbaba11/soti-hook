import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var baiduApiKey = UserDefaults.standard.string(forKey: "baiduApiKey") ?? ""
    @State private var baiduSecretKey = UserDefaults.standard.string(forKey: "baiduSecretKey") ?? ""
    
    var body: some View {
        NavigationView {
            List {
                // AI Provider Selection
                Section {
                    Picker("AI 服务商", selection: $appState.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appState.aiProvider) { newProvider in
                        appState.modelName = newProvider.defaultModel
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(appState.aiProvider.displayName) API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField(appState.aiProvider.keyPlaceholder, text: Binding(
                            get: {
                                switch appState.aiProvider {
                                case .deepseek: return appState.token
                                case .mimo: return appState.mimoToken
                                }
                            },
                            set: { newValue in
                                switch appState.aiProvider {
                                case .deepseek: appState.token = newValue
                                case .mimo: appState.mimoToken = newValue
                                }
                            }
                        ))
                        .textContentType(.password)
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("模型")
                        Spacer()
                        Picker("", selection: $appState.modelName) {
                            ForEach(appState.aiProvider.models, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Toggle(isOn: $appState.preferLocal) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("优先本地题库")
                            Text("开启后先搜本地题库，未命中再调AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI 模型")
                } footer: {
                    Text("获取 API Key: \(appState.aiProvider.helpURL)")
                }
                
                // OCR Info
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Apple Vision (离线)")
                            .font(.subheadline)
                        Spacer()
                        Text("默认")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("OCR 引擎")
                } footer: {
                    Text("使用 Apple Vision 框架离线识别，支持中英文，无需网络")
                }
                
                // History
                Section("搜索历史") {
                    if appState.searchHistory.isEmpty {
                        Text("暂无记录")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(appState.searchHistory.prefix(20)) { record in
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
                                    Text(record.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                // Clear
                Section {
                    Button("清除搜索历史") {
                        appState.searchHistory.removeAll()
                    }
                    .foregroundColor(.red)
                }
                
                // About
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.2.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("题库数")
                        Spacer()
                        Text("\(appState.questionBanks.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("OCR")
                        Spacer()
                        Text("Apple Vision (离线)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("AI 服务商")
                        Spacer()
                        Text(appState.aiProvider.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
