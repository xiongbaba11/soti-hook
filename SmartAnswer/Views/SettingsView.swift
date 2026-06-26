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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(appState.aiProvider.displayName) API Key")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DuoColors.gray)
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
                        .font(.system(size: 15))
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("模型")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("", selection: $appState.modelName) {
                            ForEach(appState.aiProvider.models, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Toggle(isOn: $appState.preferLocal) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("优先本地题库")
                                .font(.system(size: 15, weight: .medium))
                            Text("开启后先搜本地，未命中再调AI")
                                .font(.system(size: 13))
                                .foregroundColor(DuoColors.gray)
                        }
                    }
                } header: {
                    Text("AI 模型")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                } footer: {
                    Text("获取 API Key: \(appState.aiProvider.helpURL)")
                        .font(.system(size: 12))
                }
                
                // OCR Info
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DuoColors.green)
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Vision (离线)")
                                .font(.system(size: 15, weight: .medium))
                            Text("无需网络，支持中英文")
                                .font(.system(size: 13))
                                .foregroundColor(DuoColors.gray)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("OCR 引擎")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                }
                
                // History
                Section {
                    if appState.searchHistory.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 30))
                                    .foregroundColor(DuoColors.gray)
                                Text("暂无记录")
                                    .font(.system(size: 15))
                                    .foregroundColor(DuoColors.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        ForEach(appState.searchHistory.prefix(20)) { record in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.question)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                HStack {
                                    Text(record.answer)
                                        .font(.system(size: 13))
                                        .foregroundColor(DuoColors.blue)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(record.source)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(record.source == "local" ? DuoColors.green : DuoColors.blue)
                                        )
                                    Text(record.timestamp, style: .relative)
                                        .font(.system(size: 11))
                                        .foregroundColor(DuoColors.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("搜索历史")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                }
                
                // Clear
                Section {
                    Button(action: {
                        withAnimation { appState.searchHistory.removeAll() }
                    }) {
                        HStack {
                            Spacer()
                            Text("清除搜索历史")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(DuoColors.red)
                            Spacer()
                        }
                    }
                }
                
                // About
                Section {
                    HStack {
                        Text("版本")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("1.2.0")
                            .font(.system(size: 15))
                            .foregroundColor(DuoColors.gray)
                    }
                    HStack {
                        Text("题库数")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(appState.questionBanks.count)")
                            .font(.system(size: 15))
                            .foregroundColor(DuoColors.gray)
                    }
                    HStack {
                        Text("AI 服务商")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text(appState.aiProvider.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(DuoColors.gray)
                    }
                } header: {
                    Text("关于")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DuoColors.gray)
                }
            }
            .listStyle(.insetGrouped)
            .background(DuoColors.background)
            .navigationTitle("设置")
        }
    }
}
