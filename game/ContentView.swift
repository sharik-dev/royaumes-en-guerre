import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        MainTabView()
            .environmentObject(appState)
            .preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            PedometerView()
                .tabItem { Label("Marche", systemImage: "figure.walk") }
            GlobeMapView()
                .tabItem { Label("Globe", systemImage: "globe") }
        }
        .accentColor(.orange)
    }
}

#Preview {
    ContentView()
}
