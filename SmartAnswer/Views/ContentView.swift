import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraSearchView()
                .tabItem {
                    Label("拍照", systemImage: "camera.fill")
                }
                .tag(0)
            
            ScreenSearchView()
                .tabItem {
                    Label("录屏", systemImage: "record.circle")
                }
                .tag(1)
            
            QuestionBankView()
                .tabItem {
                    Label("题库", systemImage: "books.vertical.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
