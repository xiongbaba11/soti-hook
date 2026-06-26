import Foundation
import UIKit
import Vision

class OCRService {
    static let shared = OCRService()
    
    // Use Apple Vision as primary OCR (offline, free, works well for Chinese)
    func recognizeText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { obs -> String? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    return candidate.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            
            // Use accurate mode for better Chinese recognition
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en"]
            request.usesLanguageCorrection = true
            // Support both horizontal and vertical text
            request.customWords = []
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
