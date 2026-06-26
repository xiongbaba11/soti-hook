import SwiftUI
import AVFoundation
import PhotosUI

struct CameraSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var camera = CameraService()
    @State private var result: SearchResult?
    @State private var isLoading = false
    @State private var showPhotoPicker = false
    @State private var showResultSheet = false
    @State private var cameraReady = false
    
    var body: some View {
        ZStack {
            // Full-screen camera background
            if cameraReady {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
            
            // Viewfinder overlay
            VStack {
                Spacer()
                
                // Viewfinder frame
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 300, height: 220)
                    .overlay(
                        ZStack {
                            CornerAccent(position: .topLeading)
                            CornerAccent(position: .topTrailing)
                            CornerAccent(position: .bottomLeading)
                            CornerAccent(position: .bottomTrailing)
                        }
                    )
                
                Spacer()
                
                // Status indicator
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("AI 识别中...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(25)
                    .padding(.bottom, 12)
                }
                
                // Bottom controls
                HStack(spacing: 50) {
                    Button(action: { showPhotoPicker = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(15)
                    }
                    
                    Button(action: takePhoto) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 78, height: 78)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .disabled(isLoading || !cameraReady)
                    .scaleEffect(isLoading ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isLoading)
                    
                    Color.clear.frame(width: 50, height: 50)
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showResultSheet) {
            ResultSheet(result: result, isLoading: isLoading)
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
        await MainActor.run {
            isLoading = true
            result = nil
        }
        
        guard let text = await OCRService.shared.recognizeText(from: image) else {
            await MainActor.run {
                isLoading = false
                result = .error("无法识别文字，请重新拍照")
                showResultSheet = true
            }
            return
        }
        
        let searchResult = await SearchService.shared.search(
            query: text,
            token: appState.token,
            model: appState.modelName,
            preferLocal: appState.preferLocal
        )
        
        await MainActor.run {
            isLoading = false
            result = searchResult
            showResultSheet = true
            
            if case .found(let q) = searchResult {
                let record = SearchRecord(question: q.question, answer: q.answer, source: q.source, timestamp: Date())
                appState.searchHistory.insert(record, at: 0)
            }
        }
    }
}

// MARK: - Result Sheet (iOS 15 compatible)
struct ResultSheet: View {
    let result: SearchResult?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("AI 正在分析题目...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = result {
                    switch result {
                    case .found(let question):
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                // Source badge
                                HStack {
                                    Image(systemName: question.source == "local" ? "books.vertical.fill" : "brain")
                                        .font(.caption)
                                    Text(question.source == "local" ? "本地题库" : "DeepSeek AI")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(question.source == "local" ? Color.green : Color.blue)
                                .cornerRadius(8)
                                
                                Text("题目")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(question.question)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                
                                Text("答案")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(question.answer)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                        
                    case .notFound:
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("未找到匹配答案")
                                .font(.headline)
                            Text("试试调整拍照角度或导入更多题库")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .error(let msg):
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(msg)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("对准题目拍照")
                            .font(.headline)
                        Text("支持选择题、填空题、问答题")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("搜题结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Corner Accent
struct CornerAccent: View {
    enum Position { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    let position: Position
    
    var body: some View {
        let length: CGFloat = 20
        let lineWidth: CGFloat = 3
        
        ZStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: length, height: lineWidth)
                .offset(x: horizontalOffset, y: verticalEdge)
            
            Rectangle()
                .fill(Color.blue)
                .frame(width: lineWidth, height: length)
                .offset(x: verticalEdge, y: horizontalOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
    
    private var horizontalOffset: CGFloat {
        let half = CGFloat(10)
        switch position {
        case .topLeading, .bottomLeading: return half
        case .topTrailing, .bottomTrailing: return -half
        }
    }
    
    private var verticalEdge: CGFloat { 0 }
    
    private var alignment: Alignment {
        switch position {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                layer.frame = uiView.bounds
            }
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
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPick(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async { self.onPick(image as? UIImage) }
            }
        }
    }
}
