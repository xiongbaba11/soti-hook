import ReplayKit
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.smartanswer.screen")
        sharedDefaults?.set(true, forKey: "isBroadcasting")
        sharedDefaults?.synchronize()
    }
    
    override func broadcastPaused() {
    }
    
    override func broadcastResumed() {
    }
    
    override func broadcastFinished() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.smartanswer.screen")
        sharedDefaults?.set(false, forKey: "isBroadcasting")
        sharedDefaults?.synchronize()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let image = UIImage(cgImage: cgImage)
            if let data = image.jpegData(compressionQuality: 0.5) {
                let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.smartanswer.screen")
                let frameURL = sharedContainer?.appendingPathComponent("current_frame.jpg")
                try? data.write(to: frameURL!)
                
                let sharedDefaults = UserDefaults(suiteName: "group.com.smartanswer.screen")
                sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "lastFrameTime")
                sharedDefaults?.synchronize()
            }
            
        case .audioApp:
            break
        case .audioMic:
            break
        @unknown default:
            break
        }
    }
}
