import Foundation
import SwiftUI
import Combine

// MARK: - Enumerations

enum Faction {
    case chevaliers, gobelins
    var nom: String { self == .chevaliers ? "Chevaliers" : "Gobelins" }
}

enum TypeUnite: Hashable {
    case guerrier, archer, pion

    var nom: String {
        switch self {
        case .guerrier: return "Guerrier"
        case .archer:   return "Archer"
        case .pion:     return "Ouvrier"
        }
    }
    var pvMax: Int      { switch self { case .guerrier: return 6; case .archer: return 4; case .pion: return 3 } }
    var attaque: Int    { switch self { case .guerrier: return 3; case .archer: return 2; case .pion: return 1 } }
    var deplacement: Int{ switch self { case .guerrier: return 2; case .archer: return 3; case .pion: return 2 } }
    var portee: Int     { switch self { case .guerrier: return 1; case .archer: return 2; case .pion: return 1 } }
    var coutOr: Int     { switch self { case .guerrier: return 3; case .archer: return 2; case .pion: return 1 } }
    var coutBois: Int   { switch self { case .guerrier: return 0; case .archer: return 1; case .pion: return 1 } }
}

enum TypeBatiment: Equatable {
    case chateau, caserne, tour, maison, mineOr

    var nom: String {
        switch self {
        case .chateau:  return "Château"
        case .caserne:  return "Caserne"
        case .tour:     return "Tour"
        case .maison:   return "Maison"
        case .mineOr:   return "Mine d'Or"
        }
    }
    var pvMax: Int   { switch self { case .chateau: return 20; case .caserne: return 10; case .tour: return 8; case .maison: return 6; case .mineOr: return 5 } }
    var coutOr: Int  { switch self { case .chateau: return 0;  case .caserne: return 4;  case .tour: return 3; case .maison: return 2; case .mineOr: return 0 } }
    var coutBois: Int{ switch self { case .chateau: return 0;  case .caserne: return 2;  case .tour: return 1; case .maison: return 1; case .mineOr: return 0 } }
    var prodOr: Int  { self == .mineOr ? 2 : (self == .maison ? 1 : 0) }
}

// MARK: - Position

struct Position: Hashable, Equatable {
    var col: Int
    var row: Int

    func distance(to other: Position) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }

    func voisins(cols: Int, rows: Int) -> [Position] {
        [Position(col: col-1, row: row), Position(col: col+1, row: row),
         Position(col: col, row: row-1), Position(col: col, row: row+1)]
            .filter { $0.col >= 0 && $0.col < cols && $0.row >= 0 && $0.row < rows }
    }
}

// MARK: - Unite

class Unite: Identifiable, ObservableObject {
    let id = UUID()
    let type: TypeUnite
    let faction: Faction
    @Published var position: Position
    @Published var pvActuels: Int
    @Published var aAgit: Bool = false

    init(type: TypeUnite, faction: Faction, position: Position) {
        self.type = type
        self.faction = faction
        self.position = position
        self.pvActuels = type.pvMax
    }

    var estVivant: Bool { pvActuels > 0 }

    var nomImage: String {
        let c = faction == .chevaliers ? "Blue" : "Red"
        switch type {
        case .guerrier: return faction == .chevaliers ? "Warrior_\(c)" : "Barrel_\(c)"
        case .archer:   return faction == .chevaliers ? "Archer_\(c)" : "Torch_\(c)"
        case .pion:     return faction == .chevaliers ? "Pawn_\(c)"   : "TNT_\(c)"
        }
    }
}

// MARK: - Batiment

class Batiment: Identifiable, ObservableObject {
    let id = UUID()
    let type: TypeBatiment
    let faction: Faction
    @Published var position: Position
    @Published var pvActuels: Int

    init(type: TypeBatiment, faction: Faction, position: Position) {
        self.type = type
        self.faction = faction
        self.position = position
        self.pvActuels = type.pvMax
    }

    var estDebout: Bool { pvActuels > 0 }

    var nomImage: String {
        let c = faction == .chevaliers ? "Blue" : "Red"
        switch type {
        case .chateau:  return faction == .chevaliers ? "Castle_\(c)" : "Goblin_House"
        case .caserne:  return faction == .chevaliers ? "Tower_\(c)"  : "Wood_Tower_\(c)"
        case .tour:     return "Tower_\(c)"
        case .maison:   return faction == .chevaliers ? "House_\(c)"  : "Goblin_House"
        case .mineOr:   return "GoldMine_Active"
        }
    }
}

// MARK: - Etat de selection

enum EtatSelection {
    case rien
    case uniteSelectionnee(Unite)
    case batimentSelectionne(Batiment)
}

// MARK: - EtatPartie (source de vérité)

class EtatPartie: ObservableObject {
    static let shared = EtatPartie()

    let cols = 6
    let rows = 8

    @Published var or: Int = 5
    @Published var bois: Int = 3
    @Published var numTour: Int = 1
    @Published var etat: EtatJeu = .tourJoueur
    @Published var selection: EtatSelection = .rien
    @Published var unites: [Unite] = []
    @Published var batiments: [Batiment] = []
    @Published var message: String = "Sélectionnez une unité ou un bâtiment"
    @Published var sceneNeedsRefresh: Bool = false

    var unitesJoueur: [Unite]   { unites.filter { $0.faction == .chevaliers && $0.estVivant } }
    var unitesIA:     [Unite]   { unites.filter { $0.faction == .gobelins   && $0.estVivant } }
    var batiJoueur:   [Batiment]{ batiments.filter { $0.faction == .chevaliers && $0.estDebout } }
    var batiIA:       [Batiment]{ batiments.filter { $0.faction == .gobelins   && $0.estDebout } }

    func uniteEn(_ pos: Position) -> Unite? {
        unites.first { $0.position == pos && $0.estVivant }
    }
    func batimentEn(_ pos: Position) -> Batiment? {
        batiments.first { $0.position == pos && $0.estDebout }
    }
    func estOccupee(_ pos: Position) -> Bool {
        uniteEn(pos) != nil || batimentEn(pos) != nil
    }

    func casesAccessibles(pour unite: Unite) -> [Position] {
        let dep = unite.type.deplacement
        var result: [Position] = []
        for dc in -dep...dep {
            for dr in -dep...dep where abs(dc)+abs(dr) <= dep {
                let p = Position(col: unite.position.col+dc, row: unite.position.row+dr)
                if p != unite.position, p.col >= 0, p.col < cols, p.row >= 0, p.row < rows, uniteEn(p) == nil, batimentEn(p) == nil {
                    result.append(p)
                }
            }
        }
        return result
    }

    func ciblesAttaquables(pour unite: Unite) -> [Position] {
        let portee = unite.type.portee
        var result: [Position] = []
        for dc in -portee...portee {
            for dr in -portee...portee where abs(dc)+abs(dr) <= portee {
                let p = Position(col: unite.position.col+dc, row: unite.position.row+dr)
                guard p.col >= 0, p.col < cols, p.row >= 0, p.row < rows else { continue }
                if let u = uniteEn(p), u.faction != unite.faction { result.append(p) }
                else if let b = batimentEn(p), b.faction != unite.faction { result.append(p) }
            }
        }
        return result
    }

    func attaquer(attaquant: Unite, ciblePos: Position) {
        let degats = attaquant.type.attaque + Int.random(in: 0...2)
        if let ennemi = uniteEn(ciblePos) {
            ennemi.pvActuels = max(0, ennemi.pvActuels - degats)
            if !ennemi.estVivant {
                unites.removeAll { $0.id == ennemi.id }
                message = "\(ennemi.type.nom) éliminé !"
            } else {
                message = "-\(degats) PV à \(ennemi.type.nom)"
            }
        } else if let bat = batimentEn(ciblePos) {
            bat.pvActuels = max(0, bat.pvActuels - degats)
            if !bat.estDebout {
                batiments.removeAll { $0.id == bat.id }
                message = "\(bat.type.nom) détruit !"
                verifierVictoire()
            } else {
                message = "-\(degats) PV à \(bat.type.nom)"
            }
        }
        attaquant.aAgit = true
        sceneNeedsRefresh.toggle()
    }

    func verifierVictoire() {
        if batiIA.first(where: { $0.type == .chateau }) == nil {
            etat = .victoireJoueur
            message = "Château ennemi détruit ! Victoire !"
        } else if batiJoueur.first(where: { $0.type == .chateau }) == nil {
            etat = .victoireIA
            message = "Votre château est tombé ! Défaite..."
        }
    }

    func finDuTour() {
        guard etat == .tourJoueur else { return }
        selection = .rien
        etat = .tourIA
        message = "Les Gobelins réfléchissent..."
        // Collecte ressources joueur
        var gainOr = 1
        for b in batiJoueur { gainOr += b.type.prodOr }
        or += gainOr
        bois += 2
        numTour += 1
        for u in unitesJoueur { u.aAgit = false }
        sceneNeedsRefresh.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.jouerTourIA()
        }
    }

    func jouerTourIA() {
        for unite in unitesIA {
            // Attaquer si possible
            if let cible = ciblesAttaquables(pour: unite).first {
                attaquer(attaquant: unite, ciblePos: cible)
                continue
            }
            // Se déplacer vers cible la plus proche
            let dests = casesAccessibles(pour: unite)
            var meilleureDest: Position? = nil
            var minDist = Int.max
            let ciblesJoueur = (unitesJoueur.map { $0.position } + batiJoueur.map { $0.position })
            for dest in dests {
                for cible in ciblesJoueur {
                    let d = dest.distance(to: cible)
                    if d < minDist { minDist = d; meilleureDest = dest }
                }
            }
            if let dest = meilleureDest { unite.position = dest }
            // Attaquer après déplacement
            if let cible = ciblesAttaquables(pour: unite).first {
                attaquer(attaquant: unite, ciblePos: cible)
            }
        }

        // IA recrute si possible
        if let caserne = batiIA.first(where: { $0.type == .chateau || $0.type == .caserne }) {
            let voisins = caserne.position.voisins(cols: cols, rows: rows)
            if let spawn = voisins.first(where: { !estOccupee($0) }), unitesIA.count < 5 {
                let type: TypeUnite = unitesIA.count % 2 == 0 ? .guerrier : .archer
                let n = Unite(type: type, faction: .gobelins, position: spawn)
                n.aAgit = true
                unites.append(n)
            }
        }

        verifierVictoire()
        if etat == .tourIA {
            etat = .tourJoueur
            message = "Tour \(numTour) — À vous de jouer !"
        }
        sceneNeedsRefresh.toggle()
    }

    func recruterUnite(_ type: TypeUnite, depuis batiment: Batiment) {
        guard etat == .tourJoueur else { return }
        guard or >= type.coutOr, bois >= type.coutBois else {
            message = "Ressources insuffisantes ! (Or:\(type.coutOr) Bois:\(type.coutBois))"
            return
        }
        let voisins = batiment.position.voisins(cols: cols, rows: rows)
        guard let spawn = voisins.first(where: { !estOccupee($0) }) else {
            message = "Pas de place autour du bâtiment !"
            return
        }
        or -= type.coutOr
        bois -= type.coutBois
        let u = Unite(type: type, faction: .chevaliers, position: spawn)
        u.aAgit = true
        unites.append(u)
        message = "\(type.nom) recruté !"
        sceneNeedsRefresh.toggle()
    }

    func initialiserPartie() {
        unites = []
        batiments = []
        or = 5; bois = 3; numTour = 1
        etat = .tourJoueur
        selection = .rien

        // Joueur (bas de carte)
        batiments.append(Batiment(type: .chateau,  faction: .chevaliers, position: Position(col: 1, row: 6)))
        batiments.append(Batiment(type: .maison,   faction: .chevaliers, position: Position(col: 0, row: 5)))
        batiments.append(Batiment(type: .mineOr,   faction: .chevaliers, position: Position(col: 2, row: 7)))
        unites.append(Unite(type: .guerrier, faction: .chevaliers, position: Position(col: 2, row: 6)))
        unites.append(Unite(type: .archer,   faction: .chevaliers, position: Position(col: 1, row: 5)))

        // IA Gobelins (haut de carte)
        batiments.append(Batiment(type: .chateau,  faction: .gobelins, position: Position(col: 4, row: 1)))
        batiments.append(Batiment(type: .caserne,  faction: .gobelins, position: Position(col: 5, row: 2)))
        unites.append(Unite(type: .guerrier, faction: .gobelins, position: Position(col: 3, row: 2)))
        unites.append(Unite(type: .archer,   faction: .gobelins, position: Position(col: 4, row: 2)))

        message = "Tour 1 — Sélectionnez une unité ou un bâtiment"
        sceneNeedsRefresh.toggle()
    }
}

enum EtatJeu: Equatable {
    case tourJoueur, tourIA, victoireJoueur, victoireIA
}
