import SwiftUI

#if DEBUG
/// Every Atlas drawing on one screen, for checking against the mockup screenshots in
/// `~/scratch/mockups/queens-journey/shots`. Launch with `-atlasGallery YES`.
struct AtlasGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sample = AtlasSample.build()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Atlas kit").font(.headlineSm).foregroundStyle(Theme.ink)
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(PillButtonStyle())
                }
                section("Province: Brackenmere, 7x7, No. 21 to 40", detail: sample.timing) {
                    ZStack {
                        AtlasSheet(pencil: sample.pencil, ink: sample.ink, height: Journey.Layout.provinceHeight, boundary: sample.boundary)
                        AtlasCanvas(drawing: sample.live, height: Journey.Layout.provinceHeight)
                    }
                }
                section("Stops: solved, skipped, current, ahead") { strip(sample.stops, height: 110) }
                section("Castles: pencil, inked, each province pigment") { strip(sample.castles, height: 90) }
                section("Terrain") { strip(sample.terrain, height: 150) }
                section("Furniture") { strip(sample.furniture, height: 130) }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(PaperBackground())
    }

    private func section(_ title: String, detail: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.labelMd).foregroundStyle(Theme.ink)
            if let detail { Text(detail).font(.bodySm).foregroundStyle(Theme.muted) }
            content()
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
        }
    }

    private func strip(_ drawing: AtlasDrawing, height: CGFloat) -> some View {
        ZStack {
            AtlasPaper()
            AtlasCanvas(drawing: drawing, height: height)
        }
        .aspectRatio(Journey.Layout.width / height, contentMode: .fit)
    }
}

/// The drawings the gallery shows, built once with their build times.
private struct AtlasSample {
    var pencil = AtlasDrawing(), ink = AtlasDrawing(), live = AtlasDrawing()
    var boundary: CGFloat = 0
    var stops = AtlasDrawing(), castles = AtlasDrawing(), terrain = AtlasDrawing(), furniture = AtlasDrawing()
    var timing = ""

    static func build() -> AtlasSample {
        var s = AtlasSample()
        let clock = ContinuousClock()
        let province = Journey.Province(size: 7, index: 1)
        let points = (0..<Journey.stopsPerProvince).map { Journey.Layout.provinceStop(province, $0) }
        // Puzzles 21 to 40: 36 passed over, 38 is where the traveller stands.
        let states: [Journey.StopState] = province.numbers.map { n in
            switch n {
            case 36: .skipped
            case 38: .current
            case 39...: .ahead
            default: .solved
            }
        }
        let current = states.firstIndex(of: .current)!
        let pigment = Theme.region(province.index)

        let terrainTime = clock.measure {
            s.ink = terrain(seed: 701, pencil: false)
            s.pencil = terrain(seed: 701, pencil: true)
        }
        s.boundary = points[current].y - 14
        let liveTime = clock.measure {
            var live = AtlasSketch(seed: 702)
            let road = AtlasGeometry.road(through: points)
            let split = current * 8 + 1
            live.road(Array(road[..<split]))
            live.pencilRoad(Array(road[(split - 1)...]))
            for (j, p) in points.enumerated() {
                live.stop(states[j], at: p, name: Naming.puzzleName(size: province.size, number: province.numbers.lowerBound + j), pigment: pigment)
            }
            live.castle(at: CGPoint(x: points[19].x, y: points[19].y - 46), scale: 2.2, pigment: pigment, inked: false)
            live.label(province.name, at: CGPoint(x: points[19].x, y: points[19].y - 80), size: 16, anchor: .middle, rotation: -1)
            s.live = live.drawing
        }
        s.timing = "Built in \(ms(terrainTime)) terrain (inked and pencil), \(ms(liveTime)) road and stops"

        var stops = AtlasSketch(seed: 703)
        for (i, state) in [Journey.StopState.solved, .skipped, .current, .ahead].enumerated() {
            stops.stop(state, at: CGPoint(x: 40 + CGFloat(i) * 95, y: 50), name: "The Umber Moor", pigment: pigment)
        }
        s.stops = stops.drawing

        var castles = AtlasSketch(seed: 704)
        castles.castle(at: CGPoint(x: 30, y: 55), scale: 1.6, pigment: pigment, inked: false)
        for i in 0..<6 {
            castles.castle(at: CGPoint(x: 85 + CGFloat(i) * 52, y: 55), scale: 1.6, pigment: Theme.region(i), inked: true, door: i % 2 == 0)
        }
        s.castles = castles.drawing

        var land = AtlasSketch(seed: 705)
        land.coast([CGPoint(x: 300, y: 0), CGPoint(x: 290, y: 50), CGPoint(x: 310, y: 100), CGPoint(x: 296, y: 150)])
        land.mountain(x: 40, y: 70, height: 34)
        land.mountain(x: 72, y: 76, height: 26)
        land.hill(x: 120, y: 70)
        land.hill(x: 140, y: 82)
        for (x, y) in [(30.0, 120.0), (44, 128), (58, 118), (70, 132)] { land.tree(x: x, y: y) }
        land.lake(CGPoint(x: 200, y: 50), rx: 26, ry: 14)
        land.river([CGPoint(x: 200, y: 64), CGPoint(x: 220, y: 100), CGPoint(x: 262, y: 120), CGPoint(x: 292, y: 126)])
        for (i, x) in [110.0, 130, 150].enumerated() { land.marsh(x: x, y: 125, pool: i == 1) }
        land.isle(CGPoint(x: 350, y: 60), radius: 14)
        land.waves(at: CGPoint(x: 345, y: 120))
        s.terrain = land.drawing

        var furniture = AtlasSketch(seed: 706)
        furniture.cartouche(at: CGPoint(x: 100, y: 45), title: "The Hamlets", subtitle: "a realm in twelve provinces")
        furniture.compass(at: CGPoint(x: 245, y: 70))
        furniture.ship(at: CGPoint(x: 330, y: 50))
        furniture.serpent(at: CGPoint(x: 70, y: 110))
        furniture.seal(at: CGPoint(x: 330, y: 105), radius: 9)
        s.furniture = furniture.drawing
        return s
    }

    /// Province terrain: mountains along the top, a forest and hills on the left, a lake with its
    /// river, marsh and the coast down the right edge.
    private static func terrain(seed: Int, pencil: Bool) -> AtlasDrawing {
        var t = AtlasSketch(seed: seed, pencil: pencil)
        let coast = stride(from: CGFloat(0), through: 720, by: 60).map { y in
            CGPoint(x: 330 + 14 * sin(y * 0.02), y: y)
        }
        t.coast(coast, sea: [CGPoint(x: 340, y: 0), CGPoint(x: 400, y: 0), CGPoint(x: 400, y: 720), CGPoint(x: 340, y: 720)])
        for (x, y, h) in [(40.0, 90.0, 34.0), (74, 98, 26), (250, 80, 30), (282, 92, 22)] { t.mountain(x: x, y: y, height: h) }
        for (x, y) in [(36.0, 300.0), (52, 312), (30, 330), (60, 336), (44, 350), (262, 470), (278, 484)] { t.tree(x: x, y: y) }
        for (x, y) in [(60.0, 200.0), (82, 214), (250, 330), (40, 560)] { t.hill(x: x, y: y) }
        t.lake(CGPoint(x: 268, y: 220), rx: 24, ry: 13)
        t.river([CGPoint(x: 276, y: 234), CGPoint(x: 296, y: 270), CGPoint(x: 318, y: 300), CGPoint(x: 336, y: 318)])
        for (i, (x, y)) in [(56.0, 450.0), (74, 462), (40, 470)].enumerated() { t.marsh(x: x, y: y, pool: i == 0) }
        t.waves(at: CGPoint(x: 366, y: 400))
        t.compass(at: CGPoint(x: 350, y: 640))
        return t.drawing
    }

    private static func ms(_ d: Duration) -> String {
        let c = d.components
        return "\(Int((Double(c.seconds) * 1000 + Double(c.attoseconds) / 1e15).rounded())) ms"
    }
}
#endif

extension View {
    /// DEBUG builds open the Atlas gallery when launched with `-atlasGallery YES`.
    func atlasGallery() -> some View {
        #if DEBUG
        modifier(AtlasGalleryLaunch())
        #else
        self
        #endif
    }
}

#if DEBUG
private struct AtlasGalleryLaunch: ViewModifier {
    @State private var show = UserDefaults.standard.bool(forKey: "atlasGallery")

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $show) { AtlasGalleryView() }
    }
}
#endif
