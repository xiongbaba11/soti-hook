import Foundation
import UIKit

class BaiduOCRService {
    static let shared = BaiduOCRService()
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    // MARK: - Public
    
    func recognizeText(from image: UIImage, apiKey: String, secretKey: String) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Get access token
        guard let token = await getAccessToken(apiKey: apiKey, secretKey: secretKey) else {
            print("BaiduOCR: Failed to get access token")
            return nil
        }
        
        // Compress image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        let base64Image = imageData.base64EncodedString()
        
        // Call OCR API
        return await callOCR(token: token, base64Image: base64Image)
    }
    
    // MARK: - Get Access Token
    
    private func getAccessToken(apiKey: String, secretKey: String) async -> String? {
        // Check cached token
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        
        let urlStr = "https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=\(apiKey)&client_secret=\(secretKey)"
        
        guard let url = URL(string: urlStr) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("BaiduOCR: Token request failed")
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String,
               let expiresIn = json["expires_in"] as? Int {
                self.accessToken = token
                self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
                return token
            }
        } catch {
            print("BaiduOCR: Token error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Call OCR
    
    private func callOCR(token: String, base64Image: String) async -> String? {
        let urlStr = "https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic?access_token=\(token)"
        
        guard let url = URL(string: urlStr) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let body = "image=\(base64Image.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? base64Image)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("BaiduOCR: Request failed")
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let wordsResult = json["words_result"] as? [[String: Any]] {
                let texts = wordsResult.compactMap { $0["words"] as? String }
                let result = texts.joined(separator: "\n")
                return result.isEmpty ? nil : result
            }
        } catch {
            print("BaiduOCR: Error: \(error)")
        }
        
        return nil
    }
}
