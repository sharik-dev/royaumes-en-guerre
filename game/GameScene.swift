import SpriteKit

class GameScene: SKScene {

    let etat = EtatPartie.shared

    // Computed tile size from screen dimensions
    var tailleCase: CGFloat = 56

    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0

    // Sprite layers
    var coucheGrille    = SKNode()
    var coucheBatiments = SKNode()
    var coucheUnites    = SKNode()
    var coucheSurligne  = SKNode()

    // Stored sprites by id for update without full redraw
    var spritesBatiments: [UUID: SKNode] = [:]
    var spritesUnites:    [UUID: SKNode] = [:]

    private var rafraichirToken: Any?

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.38, green: 0.62, blue: 0.28, alpha: 1)
        calculerLayout()

        coucheGrille.zPosition    = 0
        coucheSurligne.zPosition  = 1
        coucheBatiments.zPosition = 2
        coucheUnites.zPosition    = 3
        addChild(coucheGrille)
        addChild(coucheSurligne)
        addChild(coucheBatiments)
        addChild(coucheUnites)

        dessinerGrille()
        rafraichirTout()

        // Observe state changes triggered by EtatPartie
        rafraichirToken = NotificationCenter.default.addObserver(
            forName: .jeuRafraichir, object: nil, queue: .main
        ) { [weak self] _ in
            self?.rafraichirTout()
        }
    }

    deinit {
        if let t = rafraichirToken { NotificationCenter.default.removeObserver(t) }
    }

    func calculerLayout() {
        let margin: CGFloat = 12
        let disponibleW = size.width  - margin * 2
        let disponibleH = size.height - 220 // reserve pour HUD haut+bas
        let tileParW = disponibleW / CGFloat(etat.cols)
        let tileParH = disponibleH / CGFloat(etat.rows)
        tailleCase = min(tileParW, tileParH)
        let largeurGrille = tailleCase * CGFloat(etat.cols)
        offsetX = (size.width  - largeurGrille) / 2
        offsetY = 110 // espace pour le panel du bas (SafeArea + boutons)
    }

    // MARK: - Coordinate helpers

    func posScene(_ pos: Position) -> CGPoint {
        CGPoint(
            x: offsetX + CGFloat(pos.col) * tailleCase + tailleCase / 2,
            y: offsetY + CGFloat(etat.rows - 1 - pos.row) * tailleCase + tailleCase / 2
        )
    }

    func posGrille(_ point: CGPoint) -> Position? {
        let col = Int((point.x - offsetX) / tailleCase)
        let rowInv = Int((point.y - offsetY) / tailleCase)
        let row = etat.rows - 1 - rowInv
        guard col >= 0, col < etat.cols, row >= 0, row < etat.rows else { return nil }
        return Position(col: col, row: row)
    }

    // MARK: - Grid drawing

    func dessinerGrille() {
        coucheGrille.removeAllChildren()
        for col in 0..<etat.cols {
            for row in 0..<etat.rows {
                let x = offsetX + CGFloat(col) * tailleCase
                let y = offsetY + CGFloat(etat.rows - 1 - row) * tailleCase
                let rect = CGRect(x: x, y: y, width: tailleCase, height: tailleCase)
                let tile = SKShapeNode(rect: rect)
                let clair = (col + row) % 2 == 0
                tile.fillColor   = clair
                    ? SKColor(red: 0.56, green: 0.80, blue: 0.42, alpha: 1)
                    : SKColor(red: 0.46, green: 0.70, blue: 0.34, alpha: 1)
                tile.strokeColor = SKColor(white: 0.25, alpha: 0.35)
                tile.lineWidth   = 0.5
                coucheGrille.addChild(tile)
            }
        }
    }

    // MARK: - Full refresh

    func rafraichirTout() {
        coucheBatiments.removeAllChildren()
        coucheUnites.removeAllChildren()
        spritesBatiments.removeAll()
        spritesUnites.removeAll()
        effacerSurlignage()

        for bat in etat.batiments where bat.estDebout {
            let noeud = creerNoeudEntite(image: bat.nomImage, pv: bat.pvActuels, pvMax: bat.type.pvMax, grise: false)
            noeud.position = posScene(bat.position)
            coucheBatiments.addChild(noeud)
            spritesBatiments[bat.id] = noeud
        }

        for unite in etat.unites where unite.estVivant {
            let noeud = creerNoeudEntite(image: unite.nomImage, pv: unite.pvActuels, pvMax: unite.type.pvMax, grise: unite.aAgit)
            noeud.position = posScene(unite.position)
            coucheUnites.addChild(noeud)
            spritesUnites[unite.id] = noeud
        }

        rafraichirSurlignage()
    }

    // MARK: - Entity node

    func creerNoeudEntite(image: String, pv: Int, pvMax: Int, grise: Bool) -> SKNode {
        let container = SKNode()
        let t = tailleCase * 0.82

        if UIImage(named: image) != nil {
            let sprite = SKSpriteNode(imageNamed: image)
            sprite.size = CGSize(width: t, height: t)
            sprite.alpha = grise ? 0.45 : 1.0
            container.addChild(sprite)
        } else {
            // Fallback: forme colorée avec initiale
            let shape = SKShapeNode(rectOf: CGSize(width: t * 0.85, height: t * 0.85), cornerRadius: 6)
            shape.fillColor   = grise ? .darkGray : SKColor(red: 0.9, green: 0.6, blue: 0.1, alpha: 1)
            shape.strokeColor = .white
            shape.lineWidth   = 1.5
            container.addChild(shape)
        }

        // Barre de vie
        let barW: CGFloat = tailleCase * 0.70
        let barH: CGFloat = 5
        let barY: CGFloat = -(t / 2) - 4

        let fond = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 2)
        fond.fillColor   = SKColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1)
        fond.strokeColor = .clear
        fond.position    = CGPoint(x: 0, y: barY)
        fond.zPosition   = 1
        container.addChild(fond)

        let ratio  = CGFloat(pv) / CGFloat(max(pvMax, 1))
        let pleinW = barW * ratio
        let plein  = SKShapeNode(rectOf: CGSize(width: pleinW, height: barH), cornerRadius: 2)
        plein.fillColor   = ratio > 0.5 ? SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1) : SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1)
        plein.strokeColor = .clear
        plein.position    = CGPoint(x: -(barW - pleinW) / 2, y: barY)
        plein.zPosition   = 2
        container.addChild(plein)

        return container
    }

    // MARK: - Highlighting

    func rafraichirSurlignage() {
        effacerSurlignage()
        guard case .uniteSelectionnee(let u) = etat.selection else { return }

        // Case de l'unité sélectionnée
        surligner([u.position], couleur: SKColor.white.withAlphaComponent(0.5))
        // Cases de déplacement
        if !u.aAgit {
            surligner(etat.casesAccessibles(pour: u), couleur: SKColor.cyan.withAlphaComponent(0.38))
            surligner(etat.ciblesAttaquables(pour: u), couleur: SKColor.red.withAlphaComponent(0.48))
        }
    }

    func surligner(_ cases: [Position], couleur: SKColor) {
        for pos in cases {
            let rect = CGRect(x: -tailleCase/2, y: -tailleCase/2, width: tailleCase, height: tailleCase)
            let shape = SKShapeNode(rect: rect, cornerRadius: 4)
            shape.fillColor   = couleur
            shape.strokeColor = couleur.withAlphaComponent(0.85)
            shape.lineWidth   = 2
            shape.position    = posScene(pos)
            coucheSurligne.addChild(shape)
        }
    }

    func effacerSurlignage() {
        coucheSurligne.removeAllChildren()
    }

    // MARK: - Touch handling

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard etat.etat == .tourJoueur else { return }

        let location = touch.location(in: self)
        guard let pos = posGrille(location) else {
            etat.selection = .rien
            effacerSurlignage()
            return
        }

        switch etat.selection {

        case .rien:
            selectionnerCellule(pos)

        case .uniteSelectionnee(let unite):
            if unite.aAgit {
                // Tenter de re-sélectionner autre unité
                if let autre = etat.uniteEn(pos), autre.faction == .chevaliers, autre.id != unite.id {
                    etat.selection = .uniteSelectionnee(autre)
                    etat.message  = "\(autre.type.nom) — PV \(autre.pvActuels)/\(autre.type.pvMax)"
                    rafraichirSurlignage()
                } else {
                    etat.selection = .rien
                    effacerSurlignage()
                    etat.message  = "Cette unité a déjà agi."
                }
                return
            }

            // Attaque ?
            let cibles = etat.ciblesAttaquables(pour: unite)
            if cibles.contains(pos) {
                etat.attaquer(attaquant: unite, ciblePos: pos)
                etat.selection = .rien
                rafraichirTout()
                return
            }

            // Déplacement ?
            let accessibles = etat.casesAccessibles(pour: unite)
            if accessibles.contains(pos) {
                let anciennePos = unite.position
                unite.position = pos
                unite.aAgit   = true
                etat.message  = "\(unite.type.nom) déplacé"
                animerDeplacement(uniteId: unite.id, de: posScene(anciennePos), vers: posScene(pos))
                etat.selection = .rien
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.rafraichirTout()
                    self.etat.sceneNeedsRefresh.toggle()
                }
                return
            }

            // Re-sélection d'une autre entité
            selectionnerCellule(pos)

        case .batimentSelectionne:
            // Tap ailleurs → désélectionner
            etat.selection = .rien
            effacerSurlignage()
            selectionnerCellule(pos)
        }
    }

    func selectionnerCellule(_ pos: Position) {
        if let unite = etat.uniteEn(pos), unite.faction == .chevaliers {
            etat.selection = .uniteSelectionnee(unite)
            etat.message  = "\(unite.type.nom) — PV \(unite.pvActuels)/\(unite.type.pvMax) | Mouv.\(unite.type.deplacement) Portée \(unite.type.portee)"
            rafraichirSurlignage()
        } else if let bat = etat.batimentEn(pos), bat.faction == .chevaliers {
            etat.selection = .batimentSelectionne(bat)
            etat.message  = "\(bat.type.nom) — PV \(bat.pvActuels)/\(bat.type.pvMax). Touchez pour recruter."
            effacerSurlignage()
        } else {
            etat.selection = .rien
            effacerSurlignage()
        }
    }

    // MARK: - Move animation

    func animerDeplacement(uniteId: UUID, de: CGPoint, vers: CGPoint) {
        guard let noeud = spritesUnites[uniteId] else { return }
        noeud.position = de
        noeud.run(.move(to: vers, duration: 0.22))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        calculerLayout()
        dessinerGrille()
        rafraichirTout()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let jeuRafraichir = Notification.Name("jeuRafraichir")
}
