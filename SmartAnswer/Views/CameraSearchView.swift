import SwiftUI
import AVFoundation
import PhotosUI

struct CameraSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var camera = CameraService()
    @State private var result: SearchResult?
    @State private var isLoading = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Camera preview
                ZStack {
                    CameraPreviewView(session: camera.session)
                        .frame(height: 380)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                    
                    // Viewfinder overlay
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        .frame(width: 280, height: 200)
                }
                .padding(.top, 8)
                
                // Controls
                HStack(spacing: 40) {
                    Button(action: { showPhotoPicker = true }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    Button(action: takePhoto) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 68, height: 68)
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .shadow(color: .blue.opacity(0.3), radius: 8)
                    }
                    .disabled(isLoading)
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.vertical, 20)
                
                // Result
                if isLoading {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("识别中...")
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                
                if let result = result {
                    switch result {
                    case .found(let question):
                        AnswerCard(question: question)
                            .padding(.horizontal, 16)
                    case .notFound:
                        Text("未找到答案")
                            .foregroundColor(.secondary)
                            .padding()
                    case .error(let msg):
                        Text(msg)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("拍照搜题")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker { image in
                    if let image = image {
                        capturedImage = image
                        Task { await recognizeAndSearch(image: image) }
                    }
                }
            }
            .onAppear { camera.start() }
            .onDisappear { camera.stop() }
        }
    }
    
    private func takePhoto() {
        camera.capturePhoto { image in
            if let image = image {
                capturedImage = image
                Task { await recognizeAndSearch(image: image) }
            }
        }
    }
    
    private func recognizeAndSearch(image: UIImage) async {
        isLoading = true
        result = nil
        
        guard let text = await OCRService.shared.recognizeText(from: image) else {
            isLoading = false
            result = .error("无法识别文字")
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
            
            // Save to history
            if case .found(let q) = searchResult {
                let record = SearchRecord(question: q.question, answer: q.answer, source: q.source, timestamp: Date())
                appState.searchHistory.insert(record, at: 0)
            }
        }
    }
}

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
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

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
