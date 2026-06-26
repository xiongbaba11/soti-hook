import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var baiduApiKey = UserDefaults.standard.string(forKey: "baiduApiKey") ?? ""
    @State private var baiduSecretKey = UserDefaults.standard.string(forKey: "baiduSecretKey") ?? ""
    
    var body: some View {
        NavigationView {
            List {
                // DeepSeek API Config
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DeepSeek API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("sk-...", text: $appState.token)
                            .textContentType(.password)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("模型")
                        Spacer()
                        Picker("", selection: $appState.modelName) {
                            Text("deepseek-chat").tag("deepseek-chat")
                            Text("deepseek-reasoner").tag("deepseek-reasoner")
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
                    Text("获取 API Key: platform.deepseek.com")
                }
                
                // Baidu OCR Config
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("百度OCR API Key", text: $baiduApiKey)
                            .textContentType(.username)
                            .font(.subheadline)
                            .onChange(of: baiduApiKey) { val in
                                UserDefaults.standard.set(val, forKey: "baiduApiKey")
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Secret Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("百度OCR Secret Key", text: $baiduSecretKey)
                            .textContentType(.password)
                            .font(.subheadline)
                            .onChange(of: baiduSecretKey) { val in
                                UserDefaults.standard.set(val, forKey: "baiduSecretKey")
                            }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: baiduApiKey.isEmpty ? "circle" : "checkmark.circle.fill")
                            .foregroundColor(baiduApiKey.isEmpty ? .secondary : .green)
                        Text(baiduApiKey.isEmpty ? "未配置（使用Apple Vision）" : "已配置（百度OCR优先）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("百度OCR（可选）")
                } footer: {
                    Text("百度OCR中文识别更准，每月免费1000次。获取: cloud.baidu.com → 文字识别")
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
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("题库数")
                        Spacer()
                        Text("\(appState.questionBanks.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}
