// BotAI.swift (in GameScene.swift) — Intelligence artificielle
// Difficulté: Facile / Moyen / Difficile

import Foundation

@MainActor
struct BotAI {

    // MARK: - Point d'entrée

    static func jouerTour(faction: Faction, difficulte: Difficulte, etat: EtatPartie) {
        // 1. Recrutement
        let renforts = etat.calculerRenforts(faction: faction)
        deployer(faction: faction, nombre: renforts, difficulte: difficulte, etat: etat)

        // 2. Attaques (avec délai pour l'effet visuel)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            attaquer(faction: faction, difficulte: difficulte, etat: etat)

            // 3. Fin du tour
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                etat.passerAuTourSuivant()
            }
        }
    }

    // MARK: - Déploiement

    private static func deployer(faction: Faction, nombre: Int, difficulte: Difficulte, etat: EtatPartie) {
        let owned = etat.territoires.values.filter { $0.proprietaire == faction }.map { $0.id }
        guard !owned.isEmpty else { return }

        var remaining = nombre
        while remaining > 0 {
            let targetId: String
            switch difficulte {
            case .facile:
                // Territoire aléatoire
                targetId = owned.randomElement()!

            case .moyen:
                // Préfère les territoires frontaliers
                let borders = owned.filter { id in
                    etat.territoires[id]?.voisins.contains(where: {
                        etat.territoires[$0]?.proprietaire != faction
                    }) ?? false
                }
                targetId = borders.randomElement() ?? owned.randomElement()!

            case .difficile:
                // Renforce le territoire frontalier le plus exposé (ratio armées/voisins ennemis)
                let scored = owned.compactMap { id -> (String, Double)? in
                    guard let t = etat.territoires[id] else { return nil }
                    let enemyCount = t.voisins.filter {
                        etat.territoires[$0]?.proprietaire != faction
                    }.count
                    guard enemyCount > 0 else { return nil }
                    let score = Double(enemyCount) / Double(t.armees)
                    return (id, score)
                }.sorted { $0.1 > $1.1 }
                targetId = scored.first?.0 ?? owned.randomElement()!
            }
            etat.territoires[targetId]?.armees += 1
            remaining -= 1
        }
        etat.refreshMap.toggle()
    }

    // MARK: - Attaque

    private static func attaquer(faction: Faction, difficulte: Difficulte, etat: EtatPartie) {
        let maxAttaques = difficulte.maxAttaquesParTour
        var count = 0

        while count < maxAttaques {
            guard let (srcId, tgtId) = meilleureAttaque(faction: faction, difficulte: difficulte, etat: etat) else { break }

            guard var src = etat.territoires[srcId],
                  var tgt = etat.territoires[tgtId],
                  src.armees > 1 else { break }

            let r = resoudreCombat(attaque: src.armees, defense: tgt.armees)
            src.armees -= r.pertesAttaquant
            tgt.armees -= r.pertesDefenseur

            if r.conquis {
                let mvt = max(1, src.armees - 1)
                tgt.armees       = mvt
                tgt.proprietaire = faction
                src.armees      -= mvt
                etat.message = "\(faction.nomAffichage) conquiert \(tgt.nom) !"
            }
            etat.territoires[srcId] = src
            etat.territoires[tgtId] = tgt
            count += 1
        }

        etat.verifierVictoire()
        etat.refreshMap.toggle()
    }

    // MARK: - Sélection de la meilleure attaque

    private static func meilleureAttaque(
        faction: Faction,
        difficulte: Difficulte,
        etat: EtatPartie
    ) -> (String, String)? {
        // Collecte tous les paires (source, cible) possibles avec leur ratio d'armées
        var candidates: [(String, String, Double)] = []

        for (srcId, src) in etat.territoires where src.proprietaire == faction && src.armees > 1 {
            for tgtId in src.voisins {
                guard let tgt = etat.territoires[tgtId], tgt.proprietaire != faction else { continue }
                let ratio = Double(src.armees) / Double(max(1, tgt.armees))
                candidates.append((srcId, tgtId, ratio))
            }
        }

        guard !candidates.isEmpty else { return nil }

        switch difficulte {
        case .facile:
            // Attaque aléatoire, même défavorable
            return candidates.randomElement().map { ($0.0, $0.1) }

        case .moyen:
            // N'attaque que si ratio > 1.4
            let favorable = candidates.filter { $0.2 > 1.4 }
            if favorable.isEmpty { return nil }
            return favorable.randomElement().map { ($0.0, $0.1) }

        case .difficile:
            // Choisit le meilleur ratio (>1.2), préfère conquérir un continent
            let viable = candidates.filter { $0.2 > 1.2 }.sorted { $0.2 > $1.2 }
            // Priorité aux territoires qui complètent un continent
            if let continentPriority = viable.first(where: { srcId, tgtId, _ in
                continentBonusAttack(faction: faction, tgtId: tgtId, etat: etat)
            }) {
                return (continentPriority.0, continentPriority.1)
            }
            return viable.first.map { ($0.0, $0.1) }
        }
    }

    /// Vérifie si conquérir `tgtId` complèterait un continent pour `faction`
    private static func continentBonusAttack(faction: Faction, tgtId: String, etat: EtatPartie) -> Bool {
        guard let tgt = etat.territoires[tgtId] else { return false }
        let contId = tgt.continentId
        let contTerrs = etat.territoires.values.filter { $0.continentId == contId }
        let owned = contTerrs.filter { $0.proprietaire == faction || $0.id == tgtId }
        return owned.count == contTerrs.count
    }
}
