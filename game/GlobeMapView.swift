#if canImport(MapboxMaps)
import SwiftUI
import MapboxMaps
import CoreLocation

struct GlobeMapView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var location = LocationService()

    private static let paris = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

    var body: some View {
        ZStack(alignment: .bottom) {
            MapboxGlobeWrapper(
                playerCoordinate: appState.playerCoordinate,
                trail: appState.trail,
                checkpoints: WorldRoute.shared.checkpoints
            )
            .ignoresSafeArea()

            globeOverlay
        }
        .onAppear {
            location.requestPermission()
        }
        .onChange(of: location.location) {
            // First GPS fix: set as start coordinate (overrides Paris default)
            guard let loc = location.location,
                  !appState.isSetupComplete else { return }
            appState.setStartCoordinate(loc.coordinate)
        }
        .onChange(of: location.status) {
            // GPS denied or restricted → use Paris as default
            let denied = location.status == .denied || location.status == .restricted
            if denied && !appState.isSetupComplete {
                appState.setStartCoordinate(Self.paris)
            }
        }
    }

    private var globeOverlay: some View {
        HStack {
            if let next = appState.nextCheckpoint {
                HStack(spacing: 6) {
                    Image(systemName: "mappin").foregroundColor(.orange)
                    Text("\(next.emoji) \(next.name)")
                        .font(.caption).foregroundColor(.white)
                }
            }
            Spacer()
            Text(String(format: "%.3f %%", appState.worldProgress * 100))
                .font(.caption).fontWeight(.bold).foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

// MARK: - UIViewRepresentable

struct MapboxGlobeWrapper: UIViewRepresentable {
    let playerCoordinate: CLLocationCoordinate2D
    let trail: [CLLocationCoordinate2D]
    let checkpoints: [Checkpoint]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MapView {
        let opts = MapInitOptions(
            cameraOptions: CameraOptions(center: playerCoordinate, zoom: 2.5),
            styleURI: .outdoors
        )
        let mapView = MapView(frame: .zero, mapInitOptions: opts)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.ornaments.options.scaleBar.visibility = .hidden

        mapView.mapboxMap.onNext(event: .styleLoaded) { _ in
            try? mapView.mapboxMap.setProjection(StyleProjection(name: .globe))
            context.coordinator.setup(mapView: mapView, checkpoints: checkpoints)
            context.coordinator.updateTrail(trail, on: mapView)
            context.coordinator.updatePlayer(playerCoordinate, on: mapView)
        }

        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.updatePlayer(playerCoordinate, on: mapView)
        context.coordinator.updateTrail(trail, on: mapView)

        let camera = CameraOptions(center: playerCoordinate, zoom: 3)
        mapView.camera.fly(to: camera, duration: 1.2)
    }

    // MARK: - Coordinator

    final class Coordinator {
        weak var mapView: MapView?
        var pointManager: PointAnnotationManager?
        var polylineManager: PolylineAnnotationManager?
        var checkpointManager: PointAnnotationManager?

        func setup(mapView: MapView, checkpoints: [Checkpoint]) {
            polylineManager   = mapView.annotations.makePolylineAnnotationManager()
            pointManager      = mapView.annotations.makePointAnnotationManager()
            checkpointManager = mapView.annotations.makePointAnnotationManager()

            let pins: [PointAnnotation] = checkpoints.map { cp in
                var ann = PointAnnotation(coordinate: cp.coordinate)
                ann.textField = cp.emoji
                ann.textSize = 20
                return ann
            }
            checkpointManager?.annotations = pins
        }

        func updatePlayer(_ coord: CLLocationCoordinate2D, on mapView: MapView) {
            guard pointManager != nil else { return }
            var ann = PointAnnotation(coordinate: coord)
            ann.image = .init(image: playerDot(), name: "player-dot")
            ann.iconSize = 1.0
            pointManager?.annotations = [ann]
        }

        func updateTrail(_ trail: [CLLocationCoordinate2D], on mapView: MapView) {
            guard polylineManager != nil, trail.count >= 2 else { return }
            var line = PolylineAnnotation(lineCoordinates: trail)
            line.lineColor   = StyleColor(.orange)
            line.lineWidth   = 3
            line.lineOpacity = 0.8
            polylineManager?.annotations = [line]
        }

        private func playerDot() -> UIImage {
            let sz: CGFloat = 36
            return UIGraphicsImageRenderer(size: CGSize(width: sz, height: sz)).image { ctx in
                UIColor.orange.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: sz, height: sz))
                UIColor.white.setFill()
                let inner: CGFloat = 12
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: (sz - inner) / 2, y: (sz - inner) / 2,
                    width: inner, height: inner))
            }
        }
    }
}

#else
// MapboxMaps SDK not yet added — shows a placeholder.
import SwiftUI

struct GlobeMapView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.10, blue: 0.20).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.orange)
                Text("Carte Globe")
                    .font(.custom("Georgia", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Ajoutez MapboxMaps via\nFile → Add Package Dependencies\n\ngithub.com/mapbox/mapbox-maps-ios")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
    }
}
#endif
