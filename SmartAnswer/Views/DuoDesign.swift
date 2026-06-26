import SwiftUI

// MARK: - Duo Design System
struct DuoColors {
    static let green = Color(red: 0.345, green: 0.800, blue: 0.008) // #58CC02
    static let greenDark = Color(red: 0.290, green: 0.682, blue: 0.008) // #49AD02
    static let blue = Color(red: 0.220, green: 0.624, blue: 0.949) // #38A0F2
    static let blueDark = Color(red: 0.176, green: 0.522, blue: 0.835) // #2D85D5
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
    static let redDark = Color(red: 0.839, green: 0.184, blue: 0.184) // #D62E2E
    static let orange = Color(red: 1.000, green: 0.584, blue: 0.000) // #FF9500
    static let orangeDark = Color(red: 0.878, green: 0.510, blue: 0.000) // #E08200
    static let purple = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF7
    static let yellow = Color(red: 1.000, green: 0.800, blue: 0.000) // #FFCC00
    static let gray = Color(red: 0.475, green: 0.475, blue: 0.475) // #797979
    static let grayLight = Color(red: 0.925, green: 0.925, blue: 0.925) // #ECECEC
    static let background = Color(red: 0.969, green: 0.969, blue: 0.969) // #F7F7F7
    static let white = Color.white
}

// MARK: - Duo Button Style
struct DuoButtonStyle: ButtonStyle {
    let color: Color
    let darkColor: Color
    
    init(color: Color = DuoColors.green, darkColor: Color = DuoColors.greenDark) {
        self.color = color
        self.darkColor = darkColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(darkColor)
                    .padding(.top, configuration.isPressed ? 0 : 4)
                    .mask(RoundedRectangle(cornerRadius: 16))
                    .opacity(configuration.isPressed ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Duo Card
struct DuoCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(DuoColors.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - Bounce Animation
struct BounceModifier: ViewModifier {
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(trigger ? 1.05 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 10), value: trigger)
    }
}

extension View {
    func bounceEffect(trigger: Bool) -> some View {
        modifier(BounceModifier(trigger: trigger))
    }
}

// MARK: - Slide In Animation
struct SlideInModifier: ViewModifier {
    let show: Bool
    let direction: Edge
    
    func body(content: Content) -> some View {
        content
            .offset(y: show ? 0 : (direction == .bottom ? 100 : -100))
            .opacity(show ? 1 : 0)
            .animation(.interpolatingSpring(stiffness: 200, damping: 15), value: show)
    }
}

extension View {
    func slideIn(show: Bool, from direction: Edge = .bottom) -> some View {
        modifier(SlideInModifier(show: show, direction: direction))
    }
}

// MARK: - Success Checkmark
struct SuccessCheckmark: View {
    let show: Bool
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DuoColors.green)
                .frame(width: 80, height: 80)
            
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onChange(of: show) { newValue in
            if newValue {
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 10)) {
                    scale = 1.0
                    opacity = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = 0
                    opacity = 0
                }
            }
        }
    }
}

// MARK: - Progress Bar
struct DuoProgressBar: View {
    let progress: Double
    let color: Color
    
    init(progress: Double, color: Color = DuoColors.green) {
        self.progress = progress
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DuoColors.grayLight)
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(progress, 1.0), height: 16)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Tab Bar Item
struct DuoTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? color : DuoColors.gray)
            
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? color : DuoColors.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
