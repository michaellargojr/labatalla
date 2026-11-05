import SwiftUI

/// The lone star: five points, fitted into the frame.
struct StarShape: Shape {
    var points: Int = 5

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.382
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let r = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

/// The app's mark: the flag's triangle, pointing forward, with the star cut out of it, and two
/// stripes trailing. Drawn in one color on whatever sits behind it.
struct BattleMark: View {
    var color: Color = .white

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let s = min(w, h)
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.14))
                    p.addLine(to: CGPoint(x: 0, y: h * 0.86))
                    p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.5))
                    p.closeSubpath()
                }
                .fill(color)
                StarShape()
                    .fill(.black)
                    .frame(width: s * 0.3, height: s * 0.3)
                    .offset(x: w * 0.09, y: h * 0.35)
                    .blendMode(.destinationOut)
                ForEach(0..<2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: h * 0.05, style: .continuous)
                        .fill(color)
                        .frame(width: w * 0.36, height: h * 0.1)
                        .offset(x: w * 0.64, y: h * (i == 0 ? 0.3 : 0.6))
                }
            }
            .compositingGroup()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
