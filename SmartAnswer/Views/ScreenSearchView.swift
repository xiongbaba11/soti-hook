import SwiftUI
import ReplayKit
import UIKit

struct ScreenSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var lastResult: Question?
    @State private var showBroadcastPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero card
                    VStack(spacing: 10) {
                        Text("🎯 智能录屏搜题")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("开启录屏后切换到答题App\n悬浮窗自动识别题目并显示答案")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20)
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
                        FlowStep(icon: "💬", text: "悬浮窗显示答案", tag: nil, tagColor: .clear)
                    }
                    .padding(.horizontal, 16)
                    
                    // Start button
                    Button(action: toggleRecording) {
                        HStack {
                            Image(systemName: isRecording ? "stop.circle.fill" : "play.circle.fill")
                            Text(isRecording ? "停止录屏搜题" : "开启录屏搜题")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRecording ? Color.red : Color.blue)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    
                    // Last result preview
                    if let result = lastResult {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最近结果")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            AnswerCard(question: result)
                        }
                        .padding(.horizontal, 16)
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
            RPScreenRecorder.shared().stopRecording { previewVC, error in
                DispatchQueue.main.async { isRecording = false }
            }
        } else {
            RPScreenRecorder.shared().startRecording { error in
                DispatchQueue.main.async {
                    if error == nil { isRecording = true }
                }
            }
        }
    }
}

struct FlowStep: View {
    let icon: String
    let text: String
    let tag: String?
    let tagColor: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.title3)
            Text(text).font(.subheadline)
            Spacer()
            if let tag = tag {
                Text(tag)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tagColor)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct FlowArrow: View {
    var body: some View {
        Text("↓")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
    }
}
