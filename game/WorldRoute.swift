import CoreLocation

struct Checkpoint: Identifiable, Equatable {
    let id: String
    let name: String
    let country: String
    let emoji: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: Checkpoint, rhs: Checkpoint) -> Bool { lhs.id == rhs.id }
}

struct RouteSegment {
    let from: Checkpoint
    let to: Checkpoint
    let distanceKm: Double
    let isOcean: Bool
}

final class WorldRoute {
    static let shared = WorldRoute()

    let checkpoints: [Checkpoint]
    let segments: [RouteSegment]

    private init() {
        let paris     = Checkpoint(id: "paris",    name: "Paris",          country: "France",       emoji: "🇫🇷", coordinate: .init(latitude: 48.8566,  longitude:   2.3522))
        let london    = Checkpoint(id: "london",   name: "London",         country: "UK",           emoji: "🇬🇧", coordinate: .init(latitude: 51.5074,  longitude:  -0.1278))
        let nyc       = Checkpoint(id: "nyc",      name: "New York",       country: "USA",          emoji: "🇺🇸", coordinate: .init(latitude: 40.7128,  longitude: -74.0060))
        let chicago   = Checkpoint(id: "chicago",  name: "Chicago",        country: "USA",          emoji: "🇺🇸", coordinate: .init(latitude: 41.8781,  longitude: -87.6298))
        let la        = Checkpoint(id: "la",       name: "Los Angeles",    country: "USA",          emoji: "🇺🇸", coordinate: .init(latitude: 34.0522,  longitude:-118.2437))
        let tokyo     = Checkpoint(id: "tokyo",    name: "Tokyo",          country: "Japan",        emoji: "🇯🇵", coordinate: .init(latitude: 35.6762,  longitude: 139.6503))
        let beijing   = Checkpoint(id: "beijing",  name: "Beijing",        country: "China",        emoji: "🇨🇳", coordinate: .init(latitude: 39.9042,  longitude: 116.4074))
        let mumbai    = Checkpoint(id: "mumbai",   name: "Mumbai",         country: "India",        emoji: "🇮🇳", coordinate: .init(latitude: 19.0760,  longitude:  72.8777))
        let dubai     = Checkpoint(id: "dubai",    name: "Dubai",          country: "UAE",          emoji: "🇦🇪", coordinate: .init(latitude: 25.2048,  longitude:  55.2708))
        let cairo     = Checkpoint(id: "cairo",    name: "Cairo",          country: "Egypt",        emoji: "🇪🇬", coordinate: .init(latitude: 30.0444,  longitude:  31.2357))
        let capetown  = Checkpoint(id: "capetown", name: "Cape Town",      country: "South Africa", emoji: "🇿🇦", coordinate: .init(latitude:-33.9249,  longitude:  18.4241))
        let rio       = Checkpoint(id: "rio",      name: "Rio de Janeiro", country: "Brazil",       emoji: "🇧🇷", coordinate: .init(latitude:-22.9068,  longitude: -43.1729))
        let mexico    = Checkpoint(id: "mexico",   name: "Mexico City",    country: "Mexico",       emoji: "🇲🇽", coordinate: .init(latitude: 19.4326,  longitude: -99.1332))

        checkpoints = [paris, london, nyc, chicago, la, tokyo, beijing, mumbai, dubai, cairo, capetown, rio, mexico]

        segments = [
            RouteSegment(from: paris,    to: london,   distanceKm:   341,  isOcean: false),
            RouteSegment(from: london,   to: nyc,      distanceKm:  5570,  isOcean: true),
            RouteSegment(from: nyc,      to: chicago,  distanceKm:  1270,  isOcean: false),
            RouteSegment(from: chicago,  to: la,       distanceKm:  3240,  isOcean: false),
            RouteSegment(from: la,       to: tokyo,    distanceKm:  8815,  isOcean: true),
            RouteSegment(from: tokyo,    to: beijing,  distanceKm:  2100,  isOcean: false),
            RouteSegment(from: beijing,  to: mumbai,   distanceKm:  4700,  isOcean: false),
            RouteSegment(from: mumbai,   to: dubai,    distanceKm:  1900,  isOcean: false),
            RouteSegment(from: dubai,    to: cairo,    distanceKm:  2400,  isOcean: false),
            RouteSegment(from: cairo,    to: capetown, distanceKm:  6700,  isOcean: false),
            RouteSegment(from: capetown, to: rio,      distanceKm:  6700,  isOcean: true),
            RouteSegment(from: rio,      to: mexico,   distanceKm:  7400,  isOcean: false),
            RouteSegment(from: mexico,   to: paris,    distanceKm:  9300,  isOcean: true),
        ]
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
