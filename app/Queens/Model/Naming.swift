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

    /// Twelve provinces per chart: six on the near shore, then six across the sea. The last of
    /// each shore is a scatter of islands. The Hamlets, Shires and Duchies have a second chart.
    private static let provinces: [Int: [String]] = [
        7: ["Thornwick", "Brackenmere", "Saltreach", "Hollowdeep", "Emberfell", "The Crown Isles",
            "Larkspur", "Mistlecombe", "Gullhaven", "Cindermoor", "Briarwatch", "The Lantern Isles",
            "Hazelwick", "Puddlecombe", "Marigold Vale", "Tanglewood", "Crookback", "The Sparrow Isles",
            "Dewbury", "Brindlemoor", "Chalkhythe", "Wolfsbane", "Kingsbarrow", "The Candle Isles"],
        8: ["Oakhurst", "Fernhollow", "Kestrel Down", "Ashbourne", "Wyrmwood", "The Gilded Isles",
            "Pennywhistle", "Rookmere", "Harrowgate", "Dunmarrow", "Stormholt", "The Amber Isles",
            "Bramblecote", "Hartsford", "Little Sorrow", "Elderholt", "Grimstone", "The Coral Isles",
            "Merrivale", "Shiverstone", "Badgerhame", "Blackwater", "Thunderhold", "The Silver Isles"],
        9: ["Willowmere", "Copperleigh", "Ravenscar", "Mossgarth", "Highcrag", "The Thistle Isles",
            "Bellbrook", "Foxglove", "Sablewood", "Greywater", "Wintermarch", "The Pearl Isles",
            "Quillfeather", "Rushmere", "Hollyhock", "Ashenvale", "Ironridge", "The Moonlit Isles",
            "Cobblestone", "Wrenwood", "Saltmarsh", "Duskhallow", "Eaglecrown", "The Ivory Isles"],
        10: ["Applecross", "Heronsford", "Blackthorn", "Duskmoor", "Ironhelm", "The Velvet Isles",
             "Primrose", "Starling Fen", "Coldharbour", "Mirefield", "Frostpeak", "The Quiet Isles"],
        11: ["Honeydew", "Swallowtail", "Cragmere", "Nightvale", "Sunspire", "The Far Isles",
             "Goldenrod", "Owlcastle", "Tidewrack", "Hallowmere", "Dragonsreach", "The Last Isles"],
    ]

    static func province(size: Int, index: Int) -> String {
        let names = provinces[size] ?? provinces[11]!
        return names[index % names.count]
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

    /// Adjectives for the second chart (puzzles 241 to 480), none shared with `adjectives`, so
    /// its names never repeat the first chart's.
    private static let farAdjectives = [
        "Ashen", "Briny", "Copper", "Dappled", "Elder", "Foxed", "Golden", "Hazel",
        "Iron", "Jackdaw's", "Kestrel's", "Linden", "Misty", "Nightjar's", "Oaken", "Primrose",
        "Quiet", "Rowan", "Silver", "Tawny", "Unicorn's", "Vesper", "Wistful", "Yew",
    ]

    /// 24 adjectives x 25 places give 600 distinct pairs (coprime counts); the
    /// multiplier scatters them so neighbouring puzzles do not read alphabetically.
    static func puzzleName(size: Int, number: Int) -> String {
        let set = (number - 1) / 120
        let g = ((size - 7) * 120 + (number - 1) % 120) * 367 % 600
        let place = set % 2 == 0 ? places[g % places.count] : farPlaces[g % farPlaces.count]
        let adjective = set < 2 ? adjectives[g % adjectives.count] : farAdjectives[g % farAdjectives.count]
        return "The \(adjective) \(place)"
    }

    /// The realm cartouche's subtitle when a realm has more than one chart.
    static func chart(_ chart: Int, of count: Int) -> String {
        let words = ["one", "two", "three", "four"]
        return "chart \(words[min(chart, 3)]) of \(words[min(count - 1, 3)])"
    }
}
