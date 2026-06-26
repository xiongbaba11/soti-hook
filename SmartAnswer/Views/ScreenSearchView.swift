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
    @State private var showSuccess = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero card
                    VStack(spacing: 16) {
                        // Animated recording indicator
                        ZStack {
                            if isRecording {
                                // Pulse rings
                                ForEach(0..<3) { i in
                                    Circle()
                                        .stroke(DuoColors.red.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                                        .frame(width: 60 + CGFloat(i) * 20, height: 60 + CGFloat(i) * 20)
                                        .scaleEffect(pulseScale)
                                        .animation(
                                            .easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.3),
                                            value: pulseScale
                                        )
                                }
                            }
                            
                            Image(systemName: isRecording ? "record.circle.fill" : "record.circle")
                                .font(.system(size: 56))
                                .foregroundColor(isRecording ? DuoColors.red : DuoColors.green)
                                .bounceEffect(trigger: isRecording)
                        }
                        .onAppear {
                            if isRecording {
                                pulseScale = 1.2
                            }
                        }
                        .onChange(of: isRecording) { newValue in
                            pulseScale = newValue ? 1.2 : 1.0
                        }
                        
                        Text(isRecording ? "录屏搜题中..." : "录屏搜题")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text(isRecording ? "切换到答题App，切回自动识别" : "开启录屏后切换到答题App\n切回本App自动识别屏幕内容")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: isRecording ? [DuoColors.red, DuoColors.orange] : [DuoColors.green, DuoColors.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // Steps
                    if isRecording {
                        DuoCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("使用方法")
                                    .font(.system(size: 18, weight: .bold))
                                
                                StepRow(num: 1, text: "录屏已开启，切换到答题App", color: DuoColors.green)
                                StepRow(num: 2, text: "在答题App中看到题目", color: DuoColors.blue)
                                StepRow(num: 3, text: "切回本App，自动识别", color: DuoColors.orange)
                                StepRow(num: 4, text: "下方显示答案", color: DuoColors.purple)
                            }
                        }
                        .padding(.horizontal, 20)
                        .slideIn(show: isRecording, from: .top)
                    }
                    
                    // Action button
                    Button(action: toggleRecording) {
                        HStack(spacing: 10) {
                            Image(systemName: isRecording ? "stop.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text(isRecording ? "停止录屏" : "开启录屏搜题")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isRecording ? DuoColors.red : DuoColors.green)
                        )
                        .shadow(color: (isRecording ? DuoColors.red : DuoColors.green).opacity(0.4), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .scaleEffect(isRecording ? 1.0 : 1.0)
                    
                    // Status message
                    if showStatus && !statusMessage.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: statusMessage.contains("失败") || statusMessage.contains("错误") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(statusMessage.contains("失败") || statusMessage.contains("错误") ? DuoColors.orange : DuoColors.green)
                            Text(statusMessage)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(DuoColors.white)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                        .padding(.horizontal, 20)
                        .slideIn(show: showStatus)
                    }
                    
                    // Results
                    if !recognizedQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("识别结果")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                                Text("\(currentIndex + 1)/\(recognizedQuestions.count)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(DuoColors.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(DuoColors.green.opacity(0.1))
                                    )
                            }
                            
                            TabView(selection: $currentIndex) {
                                ForEach(Array(recognizedQuestions.enumerated()), id: \.offset) { index, question in
                                    DuoCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: question.source == "local" ? "books.vertical.fill" : "brain")
                                                    .font(.system(size: 12))
                                                Text(question.source == "local" ? "本地题库" : question.source)
                                                    .font(.system(size: 12, weight: .semibold))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(question.source == "local" ? DuoColors.green : DuoColors.blue)
                                            )
                                            
                                            Text(question.question)
                                                .font(.system(size: 15))
                                                .lineLimit(3)
                                            
                                            Text(question.answer)
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(DuoColors.green)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 20)
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .automatic))
                            .frame(height: 220)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 16)
            }
            .background(DuoColors.background)
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
            recorder.stopRecording { previewVC, error in
                DispatchQueue.main.async {
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                        isRecording = false
                    }
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
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                            isRecording = true
                        }
                        showStatusMsg("录屏已开启，切换到答题App")
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
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                            recognizedQuestions.insert(q, at: 0)
                            if recognizedQuestions.count > 5 {
                                recognizedQuestions.removeLast()
                            }
                            currentIndex = 0
                            showSuccess = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { showSuccess = false }
                        }
                    }
                }
            }
        }
    }
    
    private func showStatusMsg(_ msg: String) {
        statusMessage = msg
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) { showStatus = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showStatus = false }
        }
    }
}

struct StepRow: View {
    let num: Int
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Text("\(num)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color)
                )
            Text(text)
                .font(.system(size: 15))
        }
    }
}
