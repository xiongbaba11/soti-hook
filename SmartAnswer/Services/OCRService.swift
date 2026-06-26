import Foundation
import UIKit
import Vision

class OCRService {
    static let shared = OCRService()
    
    // Default Baidu OCR credentials
    private let defaultApiKey = "lj7nn2nsItgfQPfPcME1xg4K"
    private let defaultSecretKey = "wxvEhZF5NkC3YHjoZz0OckbIZG4zpwdR"
    
    func recognizeText(from image: UIImage) async -> String? {
        // Use Baidu OCR (user-configured or default)
        let apiKey = UserDefaults.standard.string(forKey: "baiduApiKey") ?? defaultApiKey
        let secretKey = UserDefaults.standard.string(forKey: "baiduSecretKey") ?? defaultSecretKey
        
        if !apiKey.isEmpty && !secretKey.isEmpty {
            if let result = await BaiduOCRService.shared.recognizeText(from: image, apiKey: apiKey, secretKey: secretKey) {
                return result
            }
            print("OCR: Baidu failed, falling back to Vision")
        }
        
        // Fallback: Apple Vision (local)
        return await recognizeWithVision(from: image)
    }
    
    private func recognizeWithVision(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { obs -> String? in
                    return obs.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
