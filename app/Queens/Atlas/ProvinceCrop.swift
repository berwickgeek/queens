import SwiftUI

/// A small window onto the realm's current province, centred on the traveller: the Home realm
/// card's thumbnail. Draws the province sheet exactly as the province map does (cached terrain,
/// live road and stops) and clips it, so the two never disagree.
struct ProvinceCrop: View {
    let size: Int
    let solved: [Bool]
    @State private var terrain: ProvinceSheet.Terrain?

    private typealias L = Journey.Layout
    /// The window in sheet units.
    static let window = CGSize(width: 150, height: 150)

    var body: some View {
        let realmStates = Journey.stopStates(solved: solved)
        let at = realmStates.firstIndex(of: .current) ?? max(realmStates.count - 1, 0)
        let province = Journey.Province(size: size, index: at / Journey.stopsPerProvince)
        let range = min(realmStates.count, province.numbers.lowerBound - 1) ..< min(realmStates.count, province.numbers.upperBound)
        let states = Array(realmStates[range])
        let origin = origin(province, states: states)
        GeometryReader { geo in
            let k = geo.size.width / Self.window.width
            ZStack {
                if let terrain {
                    AtlasSheet(pencil: terrain.pencil, ink: terrain.ink, height: L.provinceHeight,
                               boundary: ProvinceSheet.boundary(province, states: states))
                } else {
                    AtlasPaper()
                }
                AtlasCanvas(drawing: ProvinceSheet.live(province, states: states), height: L.provinceHeight)
            }
            .frame(width: L.width * k, height: L.provinceHeight * k)
            .offset(x: -origin.x * k, y: -origin.y * k)
        }
        .aspectRatio(Self.window.width / Self.window.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
        .accessibilityHidden(true)
        .task(id: province) { terrain = await ProvinceSheet.terrain(province) }
    }

    /// The window's top left, centred on the current stop (the castle once the province is
    /// finished) and kept on the sheet.
    private func origin(_ province: Journey.Province, states: [Journey.StopState]) -> CGPoint {
        let stops = ProvinceGeometry.stops(province, count: states.count)
        let focus = states.firstIndex(of: .current).map { stops[$0] } ?? ProvinceGeometry.castle(stops)
        let w = Self.window.width, h = Self.window.height
        return CGPoint(x: min(max(focus.x - w / 2, 0), L.width - w),
                       y: min(max(focus.y - h / 2, 0), L.provinceHeight - h))
    }
}
