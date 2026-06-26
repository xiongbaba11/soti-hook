import SwiftUI
import ReplayKit

struct ScreenSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var statusMessage = ""
    @State private var showStatus = false
    @State private var recognizedQuestions: [Question] = []
    @State private var currentIndex = 0
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero card
                    VStack(spacing: 12) {
                        Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                            .font(.system(size: 48))
                            .foregroundColor(isRecording ? .red : .blue)
                        
                        Text(isRecording ? "录屏搜题中..." : "录屏搜题")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(isRecording ? "切换到答题App，切回本App自动识别" : "开启录屏后切换到答题App\n切回本App自动识别屏幕内容")
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
                    
                    // Steps
                    if isRecording {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("使用方法")
                                .font(.headline)
                            StepRow(num: 1, text: "录屏已开启，切换到答题App")
                            StepRow(num: 2, text: "在答题App中看到题目")
                            StepRow(num: 3, text: "切回本App，自动识别屏幕")
                            StepRow(num: 4, text: "下方显示识别结果")
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }
                    
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
                    
                    // Status
                    if showStatus && !statusMessage.isEmpty {
                        HStack {
                            Image(systemName: statusMessage.contains("失败") || statusMessage.contains("错误") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(statusMessage.contains("失败") || statusMessage.contains("错误") ? .orange : .green)
                            Text(statusMessage)
                                .font(.subheadline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Results
                    if !recognizedQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("识别结果")
                                    .font(.headline)
                                Spacer()
                                Text("\(currentIndex + 1)/\(recognizedQuestions.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            TabView(selection: $currentIndex) {
                                ForEach(Array(recognizedQuestions.enumerated()), id: \.offset) { index, question in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Image(systemName: question.source == "local" ? "books.vertical.fill" : "brain")
                                                .font(.caption2)
                                            Text(question.source == "local" ? "本地题库" : question.source)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(question.source == "local" ? Color.green : Color.blue)
                                        .cornerRadius(6)
                                        
                                        Text(question.question)
                                            .font(.subheadline)
                                        
                                        Text(question.answer)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(16)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                                    .padding(.horizontal, 4)
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .automatic))
                            .frame(height: 200)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("录屏搜题")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil, queue: .main
            ) { _ in
                if isRecording {
                    captureAndRecognize()
                }
            }
        }
    }
    
    private func toggleRecording() {
        let recorder = RPScreenRecorder.shared()
        
        if isRecording {
            // Stop recording - DON'T present preview, just stop cleanly
            recorder.stopRecording { previewVC, error in
                DispatchQueue.main.async {
                    isRecording = false
                    // Dismiss the previewVC immediately to prevent freeze
                    if let error = error {
                        showStatusMsg("停止失败: \(error.localizedDescription)")
                    } else {
                        showStatusMsg("录屏已停止")
                    }
                }
            }
        } else {
            guard recorder.isAvailable else {
                showStatusMsg("设备不支持录屏")
                return
            }
            
            recorder.startRecording { error in
                DispatchQueue.main.async {
                    if let error = error {
                        showStatusMsg("启动失败: \(error.localizedDescription)")
                    } else {
                        isRecording = true
                        showStatusMsg("录屏已开启，切换到答题App后切回本App查看结果")
                    }
                }
            }
        }
    }
    
    private func captureAndRecognize() {
        guard !isProcessing else { return }
        isProcessing = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            isProcessing = false
            return
        }
        
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let screenshot = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        
        Task {
            guard let text = await OCRService.shared.recognizeText(from: screenshot) else {
                await MainActor.run { isProcessing = false }
                return
            }
            
            let result = await SearchService.shared.search(
                query: text,
                token: appState.activeToken,
                model: appState.modelName,
                provider: appState.aiProvider,
                preferLocal: appState.preferLocal
            )
            
            await MainActor.run {
                isProcessing = false
                if case .found(let q) = result {
                    if recognizedQuestions.first?.question != q.question {
                        recognizedQuestions.insert(q, at: 0)
                        if recognizedQuestions.count > 5 {
                            recognizedQuestions.removeLast()
                        }
                        currentIndex = 0
                    }
                }
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

struct StepRow: View {
    let num: Int
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Text("\(num)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .cornerRadius(12)
            Text(text)
                .font(.subheadline)
        }
    }
}
