import Foundation

/// Storybook names for realms (board sizes) and puzzles.
enum Naming {
    struct Realm { let name: String; let subtitle: String }

    static func realm(_ size: Int) -> Realm {
        switch size {
        case 7: Realm(name: "The Hamlets", subtitle: "Seven by seven")
        case 8: Realm(name: "The Shires", subtitle: "Eight by eight")
        case 9: Realm(name: "The Duchies", subtitle: "Nine by nine")
        case 10: Realm(name: "The Kingdoms", subtitle: "Ten by ten")
        default: Realm(name: "The Empire", subtitle: "Eleven by eleven")
        }
    }

    private static let adjectives = [
        "Amber", "Bramble", "Clover", "Drowsy", "Ember", "Fernlit", "Gilded", "Hushed",
        "Ivy", "Juniper", "Lantern", "Mossy", "Nettle", "Owl's", "Pebble", "Quince",
        "Rosehip", "Saffron", "Thistle", "Umber", "Velvet", "Willow", "Wren's", "Yarrow",
    ]
    private static let places = [
        "Marsh", "Fen", "Vale", "Hollow", "Moor", "Glen", "Downs", "Weald", "Heath",
        "Reach", "Isles", "Wold", "Combe", "Dale", "Thicket", "Brook", "Fells", "Strand",
        "Orchard", "Meadow", "Barrow", "Tarn", "Coppice", "Marches", "Firth",
    ]

    /// Places for the second set (puzzles 121 to 240), so its names never repeat the first set's.
    private static let farPlaces = [
        "Steading", "Spinney", "Mere", "Holt", "Shaw", "Garth", "Ford", "Knoll", "Lea",
        "Scar", "Clough", "Carr", "Rise", "Ness", "Grange", "Hythe", "Dell", "Brake",
        "Tor", "Cleave", "Haven", "Burn", "Pike", "Wick", "Croft",
    ]

    /// 24 adjectives x 25 places give 600 distinct pairs (coprime counts); the
    /// multiplier scatters them so neighbouring puzzles do not read alphabetically.
    static func puzzleName(size: Int, number: Int) -> String {
        let set = (number - 1) / 120
        let g = ((size - 7) * 120 + (number - 1) % 120) * 367 % 600
        let place = set == 0 ? places[g % places.count] : farPlaces[g % farPlaces.count]
        return "The \(adjectives[g % adjectives.count]) \(place)"
    }
}
