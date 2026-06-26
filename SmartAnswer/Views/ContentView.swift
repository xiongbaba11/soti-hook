import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraSearchView()
                .tabItem {
                    DuoTabItem(icon: "camera.fill", title: "拍照", isSelected: selectedTab == 0, color: DuoColors.green)
                }
                .tag(0)
            
            ScreenSearchView()
                .tabItem {
                    DuoTabItem(icon: "record.circle", title: "录屏", isSelected: selectedTab == 1, color: DuoColors.blue)
                }
                .tag(1)
            
            QuestionBankView()
                .tabItem {
                    DuoTabItem(icon: "books.vertical.fill", title: "题库", isSelected: selectedTab == 2, color: DuoColors.orange)
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    DuoTabItem(icon: "gearshape.fill", title: "设置", isSelected: selectedTab == 3, color: DuoColors.gray)
                }
                .tag(3)
        }
        .tint(DuoColors.green)
    }
}
