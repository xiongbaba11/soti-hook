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
    @State private var showSuccess = false
    
    private let recognizeInterval: TimeInterval = 2.5
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera area
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
                    DuoColors.background
                    ProgressView()
                        .tint(DuoColors.green)
                        .scaleEffect(1.2)
                }
                
                // Viewfinder frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DuoColors.green.opacity(0.6), lineWidth: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .frame(height: 220)
                
                // Status badge
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Circle()
                            .fill(autoRecognize ? DuoColors.green : DuoColors.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(autoRecognize ? "自动识别中" : "点击快门识别")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(.bottom, 20)
                }
                
                // Loading overlay
                if isLoading {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("识别中...")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(DuoColors.blue)
                        )
                        .padding(.bottom, 60)
                    }
                }
                
                // Success checkmark
                if showSuccess {
                    SuccessCheckmark(show: showSuccess)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.45)
            
            // Results area
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("识别结果")
                            .font(.system(size: 20, weight: .bold))
                        Text("最多5道题，左右滑动")
                            .font(.system(size: 13))
                            .foregroundColor(DuoColors.gray)
                    }
                    
                    Spacer()
                    
                    if !recognizedQuestions.isEmpty {
                        Text("\(currentIndex + 1)/\(recognizedQuestions.count)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DuoColors.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DuoColors.green.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                if recognizedQuestions.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(DuoColors.green.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(DuoColors.green)
                        }
                        
                        VStack(spacing: 8) {
                            Text("等待识别题目")
                                .font(.system(size: 18, weight: .bold))
                            
                            Text("将题目放入取景框内\n保持稳定等待识别")
                                .font(.system(size: 14))
                                .foregroundColor(DuoColors.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Results carousel
                    TabView(selection: $currentIndex) {
                        ForEach(Array(recognizedQuestions.enumerated()), id: \.offset) { index, question in
                            DuoCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Source badge
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
                                    
                                    // Question
                                    Text(question.question)
                                        .font(.system(size: 15))
                                        .lineLimit(3)
                                    
                                    // Answer
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
                }
                
                // Bottom controls
                HStack(spacing: 50) {
                    Button(action: { showPhotoPicker = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(DuoColors.gray)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(DuoColors.grayLight)
                            )
                    }
                    
                    Button(action: takePhoto) {
                        ZStack {
                            Circle()
                                .stroke(DuoColors.green, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            
                            Circle()
                                .fill(DuoColors.green)
                                .frame(width: 60, height: 60)
                                .shadow(color: DuoColors.green.opacity(0.4), radius: 8, y: 4)
                        }
                    }
                    .disabled(isLoading || !cameraReady)
                    .scaleEffect(isLoading ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isLoading)
                    
                    Button(action: { withAnimation { scale = 1.0 } }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20))
                            .foregroundColor(DuoColors.gray)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(DuoColors.grayLight)
                            )
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DuoColors.background)
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
                    withAnimation(.easeIn(duration: 0.3)) {
                        cameraReady = true
                    }
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
                    withAnimation(.interpolatingSpring(stiffness: 200, damping: 15)) {
                        recognizedQuestions.insert(q, at: 0)
                        if recognizedQuestions.count > 5 {
                            recognizedQuestions.removeLast()
                        }
                        currentIndex = 0
                        showSuccess = true
                    }
                    
                    // Hide success after 1s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation { showSuccess = false }
                    }
                    
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
