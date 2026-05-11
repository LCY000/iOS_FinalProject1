import SwiftUI

struct ConfettiLayer: View {
    private let pieces = 60
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieces, id: \.self) { i in
                    ConfettiPiece(
                        maxX: geo.size.width,
                        endY: geo.size.height + 50,
                        delay: Double(i) * 0.02,
                        animate: animate
                    )
                }
            }
        }
        .ignoresSafeArea()
        .task {
            // 讓 GeometryReader 完成第一次 layout 再觸發落下
            try? await Task.sleep(for: .milliseconds(50))
            animate = true
        }
    }
}

private struct ConfettiPiece: View {
    let maxX: CGFloat
    let endY: CGFloat
    let delay: Double
    let animate: Bool

    private let allColors: [Color] = [.red, .blue, .green, .yellow, .orange, .pink, .purple]

    // 所有隨機值存在 @State，onAppear 只設定一次，避免 body 重算時跳變
    @State private var color: Color = .red
    @State private var rotation = 0.0
    @State private var duration = 3.5
    @State private var startX: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 12)
            .rotationEffect(.degrees(rotation))
            .offset(x: startX, y: animate ? endY : -50)
            .animation(.linear(duration: duration).delay(delay), value: animate)
            .onAppear {
                startX = CGFloat.random(in: -4...(max(maxX, 1) - 4))
                color = allColors.randomElement()!
                duration = Double.random(in: 2.5...4.5)
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
