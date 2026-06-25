import SwiftUI
import ReplayKit

struct ScreenSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var lastResult: Question?
    @State private var statusMessage = ""
    @State private var showStatus = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero card
                    VStack(spacing: 12) {
                        Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                            .font(.system(size: 48))
                            .foregroundColor(isRecording ? .red : .blue)
                        
                        Text(isRecording ? "录屏搜题中..." : "智能录屏搜题")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(isRecording ? "切换到答题App，录屏会自动记录" : "开启录屏后切换到答题App\n录屏结束后可查看截图识别")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: isRecording ? [.red.opacity(0.8), .orange.opacity(0.6)] : [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(24)
                    .padding(.horizontal, 16)
                    
                    // Strategy flow
                    VStack(alignment: .leading, spacing: 8) {
                        Text("搜索策略")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        FlowStep(icon: "🔍", text: "OCR识别题目文字", tag: nil, tagColor: .clear)
                        FlowArrow()
                        FlowStep(icon: "📚", text: "本地题库匹配", tag: "优先", tagColor: .green)
                        FlowArrow()
                        FlowStep(icon: "🤖", text: "DeepSeek AI 兜底", tag: "在线", tagColor: .blue)
                        FlowArrow()
                        FlowStep(icon: "💬", text: "显示答案", tag: nil, tagColor: .clear)
                    }
                    .padding(.horizontal, 16)
                    
                    // Start/Stop button
                    Button(action: toggleRecording) {
                        HStack {
                            Image(systemName: isRecording ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title3)
                            Text(isRecording ? "停止录屏" : "开启录屏搜题")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isRecording ? Color.red : Color.blue)
                        .cornerRadius(16)
                        .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 16)
                    
                    // Status message
                    if showStatus && !statusMessage.isEmpty {
                        HStack {
                            Image(systemName: statusMessage.contains("失败") || statusMessage.contains("错误") || statusMessage.contains("不可用") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(statusMessage.contains("失败") || statusMessage.contains("错误") || statusMessage.contains("不可用") ? .orange : .green)
                            Text(statusMessage)
                                .font(.subheadline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Last result
                    if let result = lastResult {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近结果")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            AnswerCard(question: result)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // History
                    if !appState.searchHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("搜索历史")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            ForEach(appState.searchHistory.prefix(5)) { record in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.question)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(record.answer)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(record.source)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("录屏搜题")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let recorder = RPScreenRecorder.shared()
        
        guard recorder.isAvailable else {
            showStatusMsg("录屏不可用，请检查设备支持")
            return
        }
        
        recorder.startRecording { error in
            DispatchQueue.main.async {
                if let error = error {
                    showStatusMsg("启动失败: \(error.localizedDescription)")
                } else {
                    isRecording = true
                    showStatusMsg("录屏已开启，请切换到答题App")
                }
            }
        }
    }
    
    private func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        
        recorder.stopRecording { previewVC, error in
            DispatchQueue.main.async {
                isRecording = false
                
                if let error = error {
                    showStatusMsg("停止失败: \(error.localizedDescription)")
                    return
                }
                
                if let previewVC = previewVC {
                    previewVC.previewControllerDelegate = ScreenPreviewDelegate.shared
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(previewVC, animated: true)
                    }
                }
                
                showStatusMsg("录屏已停止")
            }
        }
    }
    
    private func showStatusMsg(_ msg: String) {
        statusMessage = msg
        withAnimation { showStatus = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showStatus = false }
        }
    }
}

// MARK: - Screen Preview Delegate
class ScreenPreviewDelegate: NSObject, RPPreviewViewControllerDelegate {
    static let shared = ScreenPreviewDelegate()
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}

// MARK: - Flow Components
struct FlowStep: View {
    let icon: String
    let text: String
    let tag: String?
    let tagColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            if let tag = tag {
                Text(tag)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagColor)
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct FlowArrow: View {
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }
}
