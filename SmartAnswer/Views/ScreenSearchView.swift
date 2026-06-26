import SwiftUI
import ReplayKit

struct ScreenSearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var statusMessage = ""
    @State private var showStatus = false
    @State private var recognizedQuestions: [Question] = []
    @State private var currentIndex = 0
    @State private var pollTimer: Timer?
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.smartanswer.screen")
    
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
                        
                        Text(isRecording ? "切换到答题App，悬浮窗会自动识别" : "开启录屏后切换到答题App\n悬浮窗自动识别题目")
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
                    
                    // Broadcast picker button (system UI for screen recording)
                    VStack(spacing: 12) {
                        Text("点击下方按钮开启录屏")
                            .font(.headline)
                        
                        // System broadcast picker
                        BroadcastPickerView()
                            .frame(width: 80, height: 80)
                        
                        Text("选择「智能答题」开始录屏")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // How it works
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用步骤")
                            .font(.headline)
                        
                        StepRow(num: 1, text: "点击上方按钮，选择「智能答题」开始录屏")
                        StepRow(num: 2, text: "切换到答题App，悬浮窗自动显示")
                        StepRow(num: 3, text: "悬浮窗实时识别屏幕题目")
                        StepRow(num: 4, text: "识别结果直接显示在悬浮窗上")
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
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
                                            Text(question.source == "local" ? "本地题库" : "DeepSeek AI")
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
            checkBroadcastStatus()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func checkBroadcastStatus() {
        isRecording = sharedDefaults?.bool(forKey: "isBroadcasting") ?? false
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkBroadcastStatus()
            if isRecording {
                processFrameIfAvailable()
            }
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
    }
    
    private func processFrameIfAvailable() {
        guard let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.smartanswer.screen") else { return }
        
        let frameURL = sharedContainer.appendingPathComponent("current_frame.jpg")
        guard let data = try? Data(contentsOf: frameURL),
              let image = UIImage(data: data) else { return }
        
        Task {
            guard let text = await OCRService.shared.recognizeText(from: image) else { return }
            
            let result = await SearchService.shared.search(
                query: text,
                token: appState.token,
                model: appState.modelName,
                preferLocal: appState.preferLocal
            )
            
            await MainActor.run {
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
}

// MARK: - Broadcast Picker (wraps RPSystemBroadcastPickerView)
struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = "com.smartanswer.screen"
        picker.showsMicrophoneButton = false
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
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
