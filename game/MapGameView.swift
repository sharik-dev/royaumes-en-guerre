// MapGameView.swift — Vue Mapbox pour Royaumes en Guerre
//
// ⚠️ SETUP REQUIS AVANT COMPILATION:
// 1. Dans Xcode: File → Add Package Dependencies
//    URL: https://github.com/mapbox/mapbox-maps-ios.git
//    Version: >= 11.0.0
// 2. Remplacez VOTRE_TOKEN_ICI par votre token Mapbox (mapbox.com → Account)
// 3. Ou ajoutez la clé MBXAccessToken dans Info.plist

import SwiftUI
import MapboxMaps
import CoreLocation

// MARK: - Token Mapbox (à modifier)

let MAPBOX_ACCESS_TOKEN = "VOTRE_TOKEN_MAPBOX_ICI"

// MARK: - MapGameView

struct MapGameView: UIViewRepresentable {
    @ObservedObject var etat: EtatPartie

    private static let polygonSourceId  = "territories-polygons"
    private static let labelSourceId    = "territories-labels-src"
    private static let fillLayerId      = "territories-fill"
    private static let fillSelId        = "territories-fill-selected"
    private static let lineLayerId      = "territories-line"
    private static let labelsLayerId    = "territories-labels"

    func makeUIView(context: Context) -> MapView {
        MapboxOptions.accessToken = MAPBOX_ACCESS_TOKEN

        let opts    = MapInitOptions(styleURI: .outdoors)
        let mapView = MapView(frame: .zero, mapInitOptions: opts)

        let camera  = CameraOptions(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            zoom: 1.3
        )
        mapView.mapboxMap.setCamera(to: camera)

        // Masquer les ornements inutiles
        mapView.ornaments.options.scaleBar.visibility    = .hidden
        mapView.ornaments.options.compass.visibility     = .hidden
        mapView.location.options.puckType                = nil

        // Désactiver le zoom double-tap (conflit avec sélection)
        mapView.gestures.options.doubleTapToZoomInEnabled = false

        context.coordinator.mapView = mapView
        context.coordinator.setupStyleObserver()

        // Gestionnaire de tap
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MapView, context: Context) {
        context.coordinator.updateIfReady()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(etat: etat)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var etat: EtatPartie
        weak var mapView: MapView?
        private var styleObserver: (any MapboxMaps.Cancelable)?
        private(set) var styleLoaded = false

        init(etat: EtatPartie) { self.etat = etat }

        // MARK: Style Observer

        func setupStyleObserver() {
            guard let mv = mapView else { return }
            styleObserver = mv.mapboxMap.onStyleLoaded.observeNext { [weak self] _ in
                self?.styleLoaded = true
                self?.setupLayers()
            }
        }

        func updateIfReady() {
            guard styleLoaded else { return }
            updateSources()
        }

        // MARK: Layer Setup

        func setupLayers() {
            guard let mv = mapView else { return }

            do {
                // ── Source polygones ──────────────────────────────────────
                var polySource = GeoJSONSource(id: MapGameView.polygonSourceId)
                polySource.data = .featureCollection(buildPolygonCollection())
                try mv.mapboxMap.addSource(polySource)

                // ── Source points (labels) ────────────────────────────────
                var ptSource = GeoJSONSource(id: MapGameView.labelSourceId)
                ptSource.data = .featureCollection(buildLabelCollection())
                try mv.mapboxMap.addSource(ptSource)

                // ── Couche fill (couleur faction) ─────────────────────────
                var fill = FillLayer(id: MapGameView.fillLayerId, source: MapGameView.polygonSourceId)
                fill.fillColor = .expression(
                    Exp(.match) {
                        Exp(.get) { "owner" }
                        "Chevaliers"; "#3373F5"
                        "Gobelins";   "#D92E2E"
                        "Orques";     "#E68514"
                        "#737373"
                    }
                )
                fill.fillOpacity = .constant(0.55)
                try mv.mapboxMap.addLayer(fill)

                // ── Couche fill sélectionné ───────────────────────────────
                var fillSel = FillLayer(id: MapGameView.fillSelId, source: MapGameView.polygonSourceId)
                fillSel.fillColor   = .constant(StyleColor(UIColor.yellow))
                fillSel.fillOpacity = .expression(
                    Exp(.switchCase) {
                        Exp(.get) { "selected" }
                        0.40
                        0.0
                    }
                )
                try mv.mapboxMap.addLayer(fillSel)

                // ── Couche bordures ───────────────────────────────────────
                var lines = LineLayer(id: MapGameView.lineLayerId, source: MapGameView.polygonSourceId)
                lines.lineColor   = .constant(StyleColor(UIColor.white))
                lines.lineWidth   = .constant(1.5)
                lines.lineOpacity = .constant(0.8)
                try mv.mapboxMap.addLayer(lines)

                // ── Couche labels (nom + armées) ──────────────────────────
                var labels = SymbolLayer(id: MapGameView.labelsLayerId, source: MapGameView.labelSourceId)
                labels.textField        = .expression(Exp(.get) { "label" })
                labels.textSize         = .constant(11)
                labels.textColor        = .constant(StyleColor(UIColor.white))
                labels.textHaloColor    = .constant(StyleColor(UIColor.black))
                labels.textHaloWidth    = .constant(1.5)
                labels.textMaxWidth     = .constant(8)
                labels.textAllowOverlap = .constant(false)
                labels.textIgnorePlacement = .constant(false)
                try mv.mapboxMap.addLayer(labels)

            } catch {
                print("[MapGameView] Erreur layers: \(error)")
            }
        }

        // MARK: Source Update

        func updateSources() {
            guard let mv = mapView else { return }
            let polyFC  = buildPolygonCollection()
            let labelFC = buildLabelCollection()
            try? mv.mapboxMap.updateGeoJSONSource(withId: MapGameView.polygonSourceId, geoJSON: .featureCollection(polyFC))
            try? mv.mapboxMap.updateGeoJSONSource(withId: MapGameView.labelSourceId,   geoJSON: .featureCollection(labelFC))
        }

        // MARK: GeoJSON Builders

        func buildPolygonCollection() -> FeatureCollection {
            var features: [Feature] = []
            for (_, t) in etat.territoires {
                var coords = t.polygone.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                if let first = coords.first { coords.append(first) }  // fermer le ring

                let isSelected = (t.id == etat.territoireSelectionne || t.id == etat.territoireSource)

                var f = Feature(geometry: .polygon(Polygon([coords])))
                f.properties = [
                    "id":       .string(t.id),
                    "owner":    .string(t.proprietaire.rawValue),
                    "armies":   .number(Double(t.armees)),
                    "selected": .boolean(isSelected),
                ]
                features.append(f)
            }
            return FeatureCollection(features: features)
        }

        func buildLabelCollection() -> FeatureCollection {
            var features: [Feature] = []
            for (_, t) in etat.territoires {
                let coord = CLLocationCoordinate2D(latitude: t.centre[1], longitude: t.centre[0])
                var f = Feature(geometry: .point(Point(coord)))
                f.properties = [
                    "id":    .string(t.id),
                    "label": .string("\(t.nom)\n⚔️ \(t.armees)"),
                    "owner": .string(t.proprietaire.rawValue),
                ]
                features.append(f)
            }
            return FeatureCollection(features: features)
        }

        // MARK: Tap Handling

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mv = mapView, styleLoaded else { return }
            let screenPoint = gesture.location(in: mv)
            let opts = RenderedQueryOptions(layerIds: [MapGameView.fillLayerId], filter: nil)

            mv.mapboxMap.queryRenderedFeatures(with: screenPoint, options: opts) { [weak self] result in
                switch result {
                case .success(let features):
                    guard let self,
                          let queriedFeature = features.first,
                          let featureProps = queriedFeature.queriedFeature.feature.properties,
                          case .string(let tid) = featureProps["id"] else { return }
                    DispatchQueue.main.async {
                        self.handleTerritoireTapped(id: tid)
                    }
                case .failure:
                    break
                }
            }
        }

        func handleTerritoireTapped(id: String) {
            guard case .enCours = etat.etatJeu, etat.tourActuel == .joueur else { return }
            switch etat.phase {
            case .recrutement:
                etat.deployerArmee(surTerritoire: id)
            case .attaque:
                etat.selectionnerTerritoirePourAttaque(id: id)
            }
        }
    }
}
