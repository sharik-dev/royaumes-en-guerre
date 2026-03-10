// GameModels.swift — Royaumes en Guerre: Conquête Mondiale
// Modèles Risk/Civ avec carte Mapbox

import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Enums

enum Faction: String, CaseIterable, Equatable, Sendable {
    case joueur = "Chevaliers"
    case bot1   = "Gobelins"
    case bot2   = "Orques"
    case neutre = "Neutre"

    var couleur: Color {
        switch self {
        case .joueur: return Color(red: 0.20, green: 0.45, blue: 0.95)
        case .bot1:   return Color(red: 0.85, green: 0.18, blue: 0.18)
        case .bot2:   return Color(red: 0.90, green: 0.52, blue: 0.08)
        case .neutre: return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }

    var couleurUI: UIColor {
        switch self {
        case .joueur: return UIColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1)
        case .bot1:   return UIColor(red: 0.85, green: 0.18, blue: 0.18, alpha: 1)
        case .bot2:   return UIColor(red: 0.90, green: 0.52, blue: 0.08, alpha: 1)
        case .neutre: return UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
        }
    }

    var hexColor: String {
        switch self {
        case .joueur: return "#3373F5"
        case .bot1:   return "#D92E2E"
        case .bot2:   return "#E68514"
        case .neutre: return "#737373"
        }
    }

    var nomAffichage: String { rawValue }

    var nomImage: String {
        switch self {
        case .joueur: return "Warrior_Blue"
        case .bot1:   return "Torch_Red"
        case .bot2:   return "TNT_Red"
        case .neutre: return "GoldMine_Active"
        }
    }
}

enum Difficulte: String, CaseIterable {
    case facile    = "Facile"
    case moyen     = "Moyen"
    case difficile = "Difficile"

    var etoiles: String {
        switch self {
        case .facile:    return "★☆☆"
        case .moyen:     return "★★☆"
        case .difficile: return "★★★"
        }
    }

    var maxAttaquesParTour: Int {
        switch self {
        case .facile:    return 1
        case .moyen:     return 3
        case .difficile: return 8
        }
    }
}

enum PhaseJoueur {
    case recrutement
    case attaque
}

enum EtatJeu: Equatable {
    case menu
    case enCours
    case finPartie(gagnant: Faction)
}

// MARK: - World Data

struct Continent: Identifiable {
    let id: String
    let nom: String
    let bonus: Int
}

struct Territoire: Identifiable, Equatable {
    let id: String
    let nom: String
    let continentId: String
    let centre: [Double]          // [longitude, latitude]
    let voisins: [String]
    let polygone: [[Double]]      // [[lon, lat], ...] open ring

    var proprietaire: Faction
    var armees: Int

    static func == (lhs: Territoire, rhs: Territoire) -> Bool { lhs.id == rhs.id }
}

// MARK: - Combat

struct ResultatCombat {
    let pertesAttaquant: Int
    let pertesDefenseur: Int
    let conquis: Bool
}

func lancerDes(_ n: Int) -> [Int] {
    (0..<n).map { _ in Int.random(in: 1...6) }.sorted(by: >)
}

func resoudreCombat(attaque: Int, defense: Int) -> ResultatCombat {
    let nA = max(0, min(3, attaque - 1))
    let nD = max(0, min(2, defense))
    guard nA > 0 else { return ResultatCombat(pertesAttaquant: 0, pertesDefenseur: 0, conquis: false) }
    let dA = lancerDes(nA)
    let dD = lancerDes(nD)
    var pA = 0, pD = 0
    for i in 0..<min(dA.count, dD.count) {
        if dA[i] > dD[i] { pD += 1 } else { pA += 1 }
    }
    return ResultatCombat(pertesAttaquant: pA, pertesDefenseur: pD, conquis: (defense - pD) <= 0)
}

// MARK: - World Builder

struct MondeJeu {
    static let continents: [Continent] = [
        Continent(id: "namerique", nom: "Amérique du Nord", bonus: 5),
        Continent(id: "samerique", nom: "Amérique du Sud",  bonus: 2),
        Continent(id: "europe",    nom: "Europe",            bonus: 5),
        Continent(id: "afrique",   nom: "Afrique",           bonus: 3),
        Continent(id: "asie",      nom: "Asie",              bonus: 7),
        Continent(id: "oceanie",   nom: "Océanie",           bonus: 2),
    ]

    // (id, nom, continent, centre[lon,lat], voisins, polygone[[lon,lat]])
    static func creerTerritoires() -> [String: Territoire] {
        let data: [(String, String, String, [Double], [String], [[Double]])] = [
            // ── Amérique du Nord ────────────────────────────────────────
            ("alaska",       "Alaska",             "namerique", [-153,  64],
             ["canada_ouest","russie"],
             [[-168,72],[-141,72],[-141,55],[-168,55]]),

            ("canada_ouest", "Canada Ouest",        "namerique", [-110,  58],
             ["alaska","canada_est","usa_ouest"],
             [[-141,72],[-90,72],[-90,49],[-141,49]]),

            ("canada_est",   "Canada Est",          "namerique", [ -70,  58],
             ["canada_ouest","usa_est"],
             [[-90,72],[-53,72],[-53,45],[-90,45]]),

            ("usa_ouest",    "États-Unis Ouest",    "namerique", [-112,  38],
             ["canada_ouest","usa_est","mexique"],
             [[-125,49],[-95,49],[-95,25],[-117,25]]),

            ("usa_est",      "États-Unis Est",      "namerique", [ -78,  38],
             ["canada_est","usa_ouest"],
             [[-95,49],[-67,49],[-67,25],[-95,25]]),

            ("mexique",      "Mexique",             "namerique", [ -96,  20],
             ["usa_ouest","colombie"],
             [[-117,25],[-77,25],[-77,8],[-100,8]]),

            // ── Amérique du Sud ──────────────────────────────────────────
            ("colombie",     "Colombie",            "samerique", [ -68,   5],
             ["mexique","bresil"],
             [[-77,12],[-57,12],[-57,-2],[-77,-2]]),

            ("bresil",       "Brésil",              "samerique", [ -50, -12],
             ["colombie","argentine"],
             [[-73,4],[-35,4],[-35,-22],[-73,-22]]),

            ("argentine",    "Argentine",           "samerique", [ -64, -38],
             ["bresil"],
             [[-75,-22],[-53,-22],[-53,-55],[-75,-55]]),

            // ── Europe ───────────────────────────────────────────────────
            ("royaume_uni",  "Royaume-Uni",         "europe",    [  -2,  54],
             ["europe_ouest","scandinavie"],
             [[-10,62],[-10,50],[5,50],[5,62]]),

            ("scandinavie",  "Scandinavie",         "europe",    [  15,  65],
             ["royaume_uni","europe_ouest","europe_est","russie"],
             [[5,72],[32,72],[32,55],[5,55]]),

            ("europe_ouest", "Europe Ouest",        "europe",    [   2,  46],
             ["royaume_uni","scandinavie","europe_est","afrique_nord"],
             [[-10,55],[15,55],[15,36],[-10,36]]),

            ("europe_est",   "Europe Est",          "europe",    [  28,  50],
             ["scandinavie","europe_ouest","russie","moyen_orient"],
             [[15,60],[40,60],[40,36],[15,36]]),

            // ── Afrique ───────────────────────────────────────────────────
            ("afrique_nord", "Afrique du Nord",     "afrique",   [  10,  26],
             ["europe_ouest","afrique_ouest","afrique_est","moyen_orient"],
             [[-17,37],[40,37],[40,14],[-17,14]]),

            ("afrique_ouest","Afrique Ouest",       "afrique",   [   5,   7],
             ["afrique_nord","afrique_sud"],
             [[-17,14],[20,14],[20,-5],[-17,-5]]),

            ("afrique_est",  "Afrique Est",         "afrique",   [  38,   2],
             ["afrique_nord","afrique_sud","moyen_orient","inde"],
             [[20,15],[52,15],[52,-12],[20,-12]]),

            ("afrique_sud",  "Afrique du Sud",      "afrique",   [  24, -28],
             ["afrique_ouest","afrique_est"],
             [[14,-5],[45,-5],[45,-35],[14,-35]]),

            // ── Asie ─────────────────────────────────────────────────────
            ("moyen_orient", "Moyen-Orient",        "asie",      [  42,  28],
             ["europe_est","afrique_nord","afrique_est","russie","asie_centrale","inde"],
             [[25,42],[62,42],[62,12],[25,12]]),

            ("russie",       "Russie",              "asie",      [  80,  62],
             ["alaska","scandinavie","europe_est","moyen_orient","asie_centrale","chine"],
             [[32,72],[135,72],[135,50],[32,55]]),

            ("asie_centrale","Asie Centrale",       "asie",      [  65,  44],
             ["russie","moyen_orient","inde","chine"],
             [[40,55],[90,55],[90,30],[40,30]]),

            ("inde",         "Inde",                "asie",      [  78,  22],
             ["moyen_orient","asie_centrale","chine","asie_sud_est","afrique_est"],
             [[62,35],[92,35],[92,5],[62,5]]),

            ("chine",        "Chine",               "asie",      [ 108,  35],
             ["russie","asie_centrale","inde","asie_sud_est"],
             [[90,52],[145,52],[145,20],[90,20]]),

            ("asie_sud_est", "Asie du Sud-Est",     "asie",      [ 112,   5],
             ["inde","chine","australie"],
             [[88,22],[142,22],[142,-10],[88,-10]]),

            // ── Océanie ───────────────────────────────────────────────────
            ("australie",    "Australie",           "oceanie",   [ 134, -28],
             ["asie_sud_est"],
             [[112,-10],[154,-10],[154,-44],[112,-44]]),
        ]

        var result: [String: Territoire] = [:]
        for (id, nom, cont, centre, voisins, poly) in data {
            result[id] = Territoire(
                id: id, nom: nom, continentId: cont,
                centre: centre, voisins: voisins, polygone: poly,
                proprietaire: .neutre, armees: 1
            )
        }
        return result
    }
}

// MARK: - Game State

@MainActor
final class EtatPartie: ObservableObject {
    static let shared = EtatPartie()

    @Published var etatJeu:               EtatJeu      = .menu
    @Published var territoires:           [String: Territoire] = [:]
    @Published var tourActuel:            Faction      = .joueur
    @Published var phase:                 PhaseJoueur  = .recrutement
    @Published var armeesADeployer:       Int          = 0
    @Published var territoireSelectionne: String?      = nil
    @Published var territoireSource:      String?      = nil
    @Published var message:               String       = ""
    @Published var difficulte:            Difficulte   = .moyen
    @Published var refreshMap:            Bool         = false

    var factionsActives: [Faction] = [.joueur, .bot1]
    private(set) var indexTour: Int = 0

    private init() {}

    // MARK: Init partie

    func initialiserPartie(difficulte: Difficulte, nombreBots: Int) {
        self.difficulte    = difficulte
        factionsActives    = [.joueur] + [Faction.bot1, .bot2].prefix(nombreBots)

        var ts = MondeJeu.creerTerritoires()
        let allIds = ts.keys.shuffled()
        for (i, id) in allIds.enumerated() {
            let faction = factionsActives[i % factionsActives.count]
            ts[id]?.proprietaire = faction
            ts[id]?.armees = Int.random(in: 1...3)
        }
        if let first = ts.values.filter({ $0.proprietaire == .joueur }).first {
            ts[first.id]?.armees = 5
        }

        territoires           = ts
        indexTour             = 0
        tourActuel            = .joueur
        phase                 = .recrutement
        armeesADeployer       = calculerRenforts(faction: .joueur)
        territoireSelectionne = nil
        territoireSource      = nil
        message = "Placez vos \(armeesADeployer) armées sur vos territoires"
        etatJeu = .enCours
        refreshMap.toggle()
    }

    // MARK: Renforts

    func calculerRenforts(faction: Faction) -> Int {
        let owned = territoires.values.filter { $0.proprietaire == faction }.count
        var bonus = max(3, owned / 3)
        for c in MondeJeu.continents {
            let ids = territoires.values.filter { $0.continentId == c.id }
            if !ids.isEmpty && ids.allSatisfy({ $0.proprietaire == faction }) {
                bonus += c.bonus
            }
        }
        return bonus
    }

    // MARK: Déploiement

    func deployerArmee(surTerritoire id: String) {
        guard phase == .recrutement,
              armeesADeployer > 0,
              territoires[id]?.proprietaire == .joueur else { return }
        territoires[id]?.armees += 1
        armeesADeployer -= 1
        if armeesADeployer == 0 {
            phase = .attaque
            message = "Sélectionnez un territoire pour attaquer"
        } else {
            message = "Encore \(armeesADeployer) armée(s) à placer"
        }
        refreshMap.toggle()
    }

    func passerRecrutement() {
        let owned = territoires.values.filter { $0.proprietaire == .joueur }.map { $0.id }
        while armeesADeployer > 0, let id = owned.randomElement() {
            territoires[id]?.armees += 1
            armeesADeployer -= 1
        }
        phase = .attaque
        message = "Sélectionnez un territoire pour attaquer"
        refreshMap.toggle()
    }

    // MARK: Attaque

    func selectionnerTerritoirePourAttaque(id: String) {
        guard phase == .attaque, tourActuel == .joueur else { return }
        guard let t = territoires[id] else { return }

        if let src = territoireSource {
            if id == src {
                territoireSource      = nil
                territoireSelectionne = nil
                message = "Sélectionnez un territoire pour attaquer"
            } else if t.proprietaire == .joueur {
                guard t.armees > 1 else {
                    message = "\(t.nom): au moins 2 armées nécessaires"
                    refreshMap.toggle(); return
                }
                territoireSource      = id
                territoireSelectionne = id
                message = "Attaque depuis \(t.nom) → choisissez une cible"
            } else if let srcT = territoires[src], srcT.voisins.contains(id) && srcT.armees > 1 {
                attaquer(sourceId: src, cibleId: id)
                if let updSrc = territoires[src], updSrc.armees > 1 {
                    message = "Continuez depuis \(updSrc.nom) ou choisissez une autre source"
                } else {
                    territoireSource      = nil
                    territoireSelectionne = nil
                    message = "Sélectionnez un territoire pour attaquer"
                }
                return
            } else {
                message = "\(t.nom) n'est pas adjacent à votre sélection"
            }
        } else {
            guard t.proprietaire == .joueur else {
                message = "Sélectionnez un de vos territoires"
                refreshMap.toggle(); return
            }
            guard t.armees > 1 else {
                message = "\(t.nom): il faut au moins 2 armées"
                refreshMap.toggle(); return
            }
            territoireSource      = id
            territoireSelectionne = id
            message = "Attaque depuis \(t.nom) → choisissez une cible ennemie adjacente"
        }
        refreshMap.toggle()
    }

    func attaquer(sourceId: String, cibleId: String) {
        guard var src = territoires[sourceId],
              var cib = territoires[cibleId] else { return }
        let r = resoudreCombat(attaque: src.armees, defense: cib.armees)
        src.armees -= r.pertesAttaquant
        cib.armees -= r.pertesDefenseur
        if r.conquis {
            let mvt = max(1, src.armees - 1)
            cib.armees      = mvt
            cib.proprietaire = .joueur
            src.armees      -= mvt
            message = "Victoire ! \(cib.nom) est conquis !"
        } else {
            message = "Combat : -\(r.pertesAttaquant) vous, -\(r.pertesDefenseur) ennemi"
        }
        territoires[sourceId] = src
        territoires[cibleId]  = cib
        verifierVictoire()
        refreshMap.toggle()
    }

    func terminerTourJoueur() {
        territoireSource      = nil
        territoireSelectionne = nil
        passerAuTourSuivant()
    }

    // MARK: Gestion des tours

    func passerAuTourSuivant() {
        factionsActives = factionsActives.filter { f in
            territoires.values.contains { $0.proprietaire == f }
        }
        guard factionsActives.count > 1 else { verifierVictoire(); return }

        indexTour  = (indexTour + 1) % factionsActives.count
        tourActuel = factionsActives[indexTour]

        if tourActuel == .joueur {
            phase           = .recrutement
            armeesADeployer = calculerRenforts(faction: .joueur)
            message = "Votre tour — Placez \(armeesADeployer) armée(s)"
            territoireSource      = nil
            territoireSelectionne = nil
        } else {
            phase   = .recrutement
            message = "\(tourActuel.nomAffichage) réfléchissent…"
            let faction = tourActuel
            let diff    = difficulte
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                BotAI.jouerTour(faction: faction, difficulte: diff, etat: self)
            }
        }
        refreshMap.toggle()
    }

    // MARK: Victoire

    func verifierVictoire() {
        guard case .enCours = etatJeu else { return }
        if territoires.values.allSatisfy({ $0.proprietaire == .joueur }) {
            etatJeu = .finPartie(gagnant: .joueur); return
        }
        if territoires.values.filter({ $0.proprietaire == .joueur }).isEmpty {
            let winner = factionsActives.first(where: { $0 != .joueur }) ?? .bot1
            etatJeu = .finPartie(gagnant: winner)
        }
    }
}
