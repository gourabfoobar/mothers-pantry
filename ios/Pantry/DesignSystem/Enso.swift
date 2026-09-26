import SwiftUI

/// The hand-drawn ensō (circle) motif from the canvas, redrawn as vector
/// paths (originally an inline SVG, viewBox 0 0 160 160) rather than a raster
/// image so it scales and recolors cleanly. Appears on Welcome, Connected,
/// Matching and Placed.
struct Enso: Shape {
    func path(in rect: CGRect) -> Path {
        Enso.mainPath(in: rect)
    }

    static func mainPath(in rect: CGRect) -> Path {
        let scale = rect.width / 160
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.move(to: p(118, 34))
        path.addCurve(to: p(30, 46), control1: p(96, 14), control2: p(50, 16))
        path.addCurve(to: p(66, 136), control1: p(10, 78), control2: p(26, 124))
        path.addCurve(to: p(142, 84), control1: p(104, 148), control2: p(140, 122))
        path.addCurve(to: p(126, 42), control1: p(143, 66), control2: p(136, 52))
        return path
    }

    static func accentPath(in rect: CGRect) -> Path {
        let scale = rect.width / 160
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.move(to: p(122, 38))
        path.addCurve(to: p(38, 48), control1: p(100, 20), control2: p(58, 22))
        return path
    }
}

struct EnsoMotif: View {
    var color: Color = Theme.ink
    var lineWidth: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                Enso.accentPath(in: rect)
                    .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth * (2.5 / 7), lineCap: .round))
                Enso.mainPath(in: rect)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}

#Preview {
    EnsoMotif()
        .frame(width: 200, height: 200)
        .padding()
        .background(Theme.background)
}
