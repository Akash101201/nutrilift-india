import SwiftUI

/// A burst of confetti. Does nothing when Reduce Motion is on.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece: Identifiable {
        let id = UUID()
        let dx = Double.random(in: -0.6...0.6)
        let dy = Double.random(in: 0.35...1.0)
        let rotation = Double.random(in: 180...900)
        let width = CGFloat.random(in: 6...10)
        let height = CGFloat.random(in: 10...16)
        let color = Theme.confettiColors.randomElement() ?? Theme.saffron
        let duration = Double.random(in: 1.3...2.2)
    }

    // @State keeps the same pieces if the view struct is re-created mid-burst.
    @State private var pieces: [Piece] = (0..<40).map { _ in Piece() }
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                Color.clear
            } else {
                ZStack {
                    ForEach(pieces) { piece in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(piece.color)
                            .frame(width: piece.width, height: piece.height)
                            .rotationEffect(.degrees(animate ? piece.rotation : 0))
                            .offset(
                                x: animate ? piece.dx * geo.size.width : 0,
                                y: animate ? piece.dy * geo.size.height : -geo.size.height * 0.1
                            )
                            .opacity(animate ? 0 : 1)
                            .animation(.easeOut(duration: piece.duration), value: animate)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.25)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { animate = true }
    }
}

private struct CelebrateModifier: ViewModifier {
    let trigger: Int
    @State private var showing = false
    @State private var burstID = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if showing {
                    ConfettiView()
                        .id(burstID)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                burstID += 1
                let thisBurst = burstID
                showing = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    // A newer burst has its own timer; don't cut it short.
                    guard burstID == thisBurst else { return }
                    withAnimation { showing = false }
                }
            }
    }
}

extension View {
    /// Shows confetti and a success haptic each time `trigger` changes to a positive number.
    /// Increment a counter to celebrate.
    func celebrate(trigger: Int) -> some View {
        modifier(CelebrateModifier(trigger: trigger))
    }
}
