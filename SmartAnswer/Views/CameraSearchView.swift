import SwiftUI
import AVFoundation
import PhotosUI

struct CameraSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var camera = CameraService()
    @State private var isLoading = false
    @State private var showPhotoPicker = false
    @State private var cameraReady = false
    @State private var recognizedQuestions: [Question] = []
    @State private var currentIndex = 0
    @State private var scale: CGFloat = 1.0
    @State private var autoRecognize = true
    @State private var lastRecognizeTime: Date = Date.distantPast
    
    private let recognizeInterval: TimeInterval = 2.5
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera area (top half)
            ZStack {
                if cameraReady {
                    AutoCapturePreview(
                        session: camera.session,
                        scale: $scale,
                        autoRecognize: $autoRecognize,
                        onCapture: { image in
                            Task { await recognizeAndSearch(image: image) }
                        }
                    )
                    .clipped()
                } else {
                    Color.black
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
                
                // Full-width blue frame
                Rectangle()
                    .stroke(Color.blue.opacity(0.7), lineWidth: 2.5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .frame(height: 200)
                
                // Hint at bottom
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(autoRecognize ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(autoRecognize ? "自动识别中..." : "点击快门手动识别")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                    .padding(.bottom, 16)
                }
                
                // Loading overlay
                if isLoading {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("AI 识别中...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(20)
                        .padding(.bottom, 50)
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.45)
            
            // Result area (bottom half)
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("识别结果")
                            .font(.headline)
                        Text("最多显示5道，左右滑动查看")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("\(recognizedQuestions.isEmpty ? 0 : currentIndex + 1)/\(recognizedQuestions.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                if recognizedQuestions.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack {
                            CornerBracketView()
                                .frame(width: 60, height: 60)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(20)
                        
                        Text("等待识别题目")
                            .font(.headline)
                        Text("把题干和选项完整放入上方画面，移动后保持稳定。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(recognizedQuestions.enumerated()), id: \.offset) { index, question in
                            ScrollView {
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
                                .padding(.horizontal, 16)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
                
                // Bottom controls
                HStack(spacing: 40) {
                    Button(action: { showPhotoPicker = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    Button(action: takePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.blue, lineWidth: 3)
                                .frame(width: 64, height: 64)
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 54, height: 54)
                        }
                    }
                    .disabled(isLoading || !cameraReady)
                    
                    Button(action: { withAnimation { scale = 1.0 } }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.vertical, 12)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { image in
                if let image = image {
                    Task { await recognizeAndSearch(image: image) }
                }
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                camera.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cameraReady = true
                }
            }
        }
        .onDisappear { camera.stop() }
    }
    
    private func takePhoto() {
        camera.capturePhoto { image in
            if let image = image {
                Task { await recognizeAndSearch(image: image) }
            }
        }
    }
    
    private func recognizeAndSearch(image: UIImage) async {
        let now = Date()
        guard now.timeIntervalSince(lastRecognizeTime) > recognizeInterval else { return }
        
        await MainActor.run {
            guard !isLoading else { return }
            isLoading = true
            lastRecognizeTime = now
        }
        
        guard let text = await OCRService.shared.recognizeText(from: image) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let searchResult = await SearchService.shared.search(
            query: text,
            token: appState.activeToken,
            model: appState.modelName,
            provider: appState.aiProvider,
            preferLocal: appState.preferLocal
        )
        
        await MainActor.run {
            isLoading = false
            
            if case .found(let q) = searchResult {
                if recognizedQuestions.first?.question != q.question {
                    recognizedQuestions.insert(q, at: 0)
                    if recognizedQuestions.count > 5 {
                        recognizedQuestions.removeLast()
                    }
                    currentIndex = 0
                    
                    let record = SearchRecord(question: q.question, answer: q.answer, source: q.source, timestamp: Date())
                    appState.searchHistory.insert(record, at: 0)
                }
            }
        }
    }
}

// MARK: - Auto Capture Preview
struct AutoCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var scale: CGFloat
    @Binding var autoRecognize: Bool
    let onCapture: (UIImage) -> Void
    
    func makeUIView(context: Context) -> AutoCaptureView {
        let view = AutoCaptureView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.previewLayer = layer
        view.layer.addSublayer(layer)
        view.onCapture = onCapture
        view.autoRecognize = autoRecognize
        
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        
        return view
    }
    
    func updateUIView(_ uiView: AutoCaptureView, context: Context) {
        DispatchQueue.main.async {
            uiView.previewLayer?.frame = uiView.bounds
            uiView.autoRecognize = autoRecognize
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scale: $scale)
    }
    
    class AutoCaptureView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var onCapture: ((UIImage) -> Void)?
        var autoRecognize: Bool = true
        private var captureTimer: Timer?
        private var lastCaptureTime: Date = Date.distantPast
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
            startAutoCapture()
        }
        
        func startAutoCapture() {
            captureTimer?.invalidate()
            captureTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                guard let self = self, self.autoRecognize else { return }
                self.captureCurrentFrame()
            }
        }
        
        private func captureCurrentFrame() {
            let now = Date()
            guard now.timeIntervalSince(lastCaptureTime) > 2.5 else { return }
            lastCaptureTime = now
            
            guard let previewLayer = previewLayer else { return }
            
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            let image = renderer.image { ctx in
                layer.render(in: ctx.cgContext)
            }
            
            let cropRect = CGRect(
                x: image.size.width * 0.05,
                y: image.size.height * 0.2,
                width: image.size.width * 0.9,
                height: image.size.height * 0.6
            )
            
            if let cgImage = image.cgImage?.cropping(to: CGRect(
                x: cropRect.origin.x * image.scale,
                y: cropRect.origin.y * image.scale,
                width: cropRect.width * image.scale,
                height: cropRect.height * image.scale
            )) {
                let cropped = UIImage(cgImage: cgImage)
                onCapture?(cropped)
            }
        }
        
        deinit {
            captureTimer?.invalidate()
        }
    }
    
    class Coordinator: NSObject {
        @Binding var scale: CGFloat
        private var initialScale: CGFloat = 1.0
        
        init(scale: Binding<CGFloat>) {
            _scale = scale
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                initialScale = scale
            case .changed:
                let newScale = initialScale * gesture.scale
                scale = min(max(newScale, 1.0), 5.0)
                applyZoom(scale)
            default:
                break
            }
        }
        
        private func applyZoom(_ scale: CGFloat) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = min(scale, device.activeFormat.videoMaxZoomFactor)
                device.unlockForConfiguration()
            } catch {}
        }
    }
}

// MARK: - Corner Bracket View
struct CornerBracketView: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 20)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 20, y: 0))
            }.stroke(Color.blue, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: 40, y: 0)); p.addLine(to: CGPoint(x: 60, y: 0)); p.addLine(to: CGPoint(x: 60, y: 20))
            }.stroke(Color.blue, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 40)); p.addLine(to: CGPoint(x: 0, y: 60)); p.addLine(to: CGPoint(x: 20, y: 60))
            }.stroke(Color.blue, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: 40, y: 60)); p.addLine(to: CGPoint(x: 60, y: 60)); p.addLine(to: CGPoint(x: 60, y: 40))
            }.stroke(Color.blue, lineWidth: 3)
        }
    }
}

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { onPick(nil); return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async { self.onPick(image as? UIImage) }
            }
        }
    }
}
