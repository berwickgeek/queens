import SwiftUI

/// The walk to the next stop, laid over a province sheet once after a solve. The sheet under it
/// leaves out the leg's road and both its stops (`ProvinceSheet.live(travelling:)`); this draws
/// them from `ProvinceSheet.pieces` and moves them on one clock, so its last frame matches the
/// sheet drawn without the leg. Mounted with trigger 0 and bumped a frame later, per the
/// Coronation rule. Times are from `Travel` in `Model/SolveTiming.swift`.
struct TravelOverlay: View {
    let pieces: ProvinceSheet.TravelPieces
    let trigger: Int
    let height: CGFloat

    private typealias T = Travel

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / Journey.Layout.width
            Color.clear
                .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, t in
                    frame(t, k: k)
                } keyframes: { _ in
                    LinearKeyframe(T.total, duration: T.total)
                }
        }
        .aspectRatio(Journey.Layout.width / height, contentMode: .fit)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func frame(_ t: Double, k: CGFloat) -> some View {
        let walked = T.easeInOut(T.progress(t, T.walk))
        let landed = t >= T.land.lowerBound
        let settle = 1.18 - 0.18 * T.easeOut(T.progress(t, T.land))
        ZStack(alignment: .topLeading) {
            if let from = pieces.from {
                let bloom = T.easeOut(T.progress(t, T.bloom))
                sheet(pieces.solved)
                    .opacity(bloom)
                    .scaleEffect(0.6 + 0.4 * bloom, anchor: anchor(from))
                sheet(pieces.sealName).opacity(1 - T.easeOut(T.progress(t, T.oldNameOut)))
                sheet(pieces.solvedName).opacity(T.easeOut(T.progress(t, T.oldNameIn)))
                sheet(pieces.road)
                    .mask(alignment: .topLeading) {
                        Path.polyline(pieces.path.map { CGPoint(x: $0.x * k, y: $0.y * k) })
                            .trimmedPath(from: 0, to: walked)
                            .stroke(.black, style: StrokeStyle(lineWidth: 12 * k, lineCap: .round, lineJoin: .round))
                    }
            }
            if let to = pieces.to {
                sheet(pieces.ahead).opacity(1 - T.easeOut(T.progress(t, T.uncharted)))
                sheet(pieces.arrived)
                    .opacity(landed ? 1 : 0)
                    .scaleEffect(settle, anchor: anchor(to))
                let written = T.easeOut(T.progress(t, T.name))
                let box = pieces.nameBox
                sheet(pieces.arrivedName)
                    .mask(alignment: .topLeading) {
                        Rectangle()
                            .frame(width: written < 1 ? box.width * written * k : 10_000, height: box.height * k)
                            .offset(x: box.minX * k, y: box.minY * k)
                    }
            } else if let castle = pieces.castle, let c = pieces.path.last {
                sheet(castle)
                    .opacity(landed ? 1 : 0)
                    .scaleEffect(settle, anchor: anchor(c))
            }
            if let from = pieces.from, !landed {
                let at = point(pieces.path, at: walked)
                sheet(pieces.seal).offset(x: (at.x - from.x) * k, y: (at.y - from.y) * k)
            }
        }
    }

    private func sheet(_ drawing: AtlasDrawing) -> some View {
        AtlasCanvas(drawing: drawing, height: height)
    }

    private func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: p.x / Journey.Layout.width, y: p.y / height)
    }

    /// The point `f` of the way along a polyline, counted in points as the mockup does.
    private func point(_ p: [CGPoint], at f: Double) -> CGPoint {
        guard p.count > 1 else { return p.first ?? .zero }
        let x = CGFloat(f) * CGFloat(p.count - 1)
        let i = min(p.count - 2, Int(x))
        let r = x - CGFloat(i)
        return CGPoint(x: p[i].x + (p[i + 1].x - p[i].x) * r, y: p[i].y + (p[i + 1].y - p[i].y) * r)
    }
}
