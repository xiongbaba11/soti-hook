import Foundation
import UIKit
import Vision

class OCRService {
    static let shared = OCRService()
    
    func recognizeText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let observations = (request.results as? [Any]) ?? []
                let text = observations.compactMap { obs -> String? in
                    guard let obs = obs as? VNRecognizedTextObservation else { return nil }
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
