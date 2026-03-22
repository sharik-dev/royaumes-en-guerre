import SwiftUI
#if canImport(MapboxMaps)
import MapboxMaps
#endif

@main
struct walkingGameApp: App {
    init() {
#if canImport(MapboxMaps)
        // Replace with your Mapbox token from account.mapbox.com
        MapboxOptions.accessToken = "YOUR_MAPBOX_TOKEN_HERE"
#else
        // MapboxMaps package is not available. Add the dependency via SPM to enable Mapbox features.
        print("[walkingGameApp] MapboxMaps not available. Add the Mapbox SDK via Swift Package Manager to enable maps.")
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
