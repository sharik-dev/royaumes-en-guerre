// ContentView.swift — Royaumes en Guerre: Conquête Mondiale
// Menu principal + HUD de jeu

import SwiftUI

// MARK: - Router principal

struct ContentView: View {
    @StateObject private var etat = EtatPartie.shared

    var body: some View {
        Group {
            switch etat.etatJeu {
            case .menu:
                MenuPrincipalView()
            case .enCours:
                GameView()
            case .finPartie(let gagnant):
                FinPartieView(gagnant: gagnant)
            }
        }
        .environmentObject(etat)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Menu principal

struct MenuPrincipalView: View {
    @EnvironmentObject var etat: EtatPartie
    @State private var difficulte: Difficulte = .moyen
    @State private var nombreBots: Int = 1

    var body: some View {
        ZStack {
            // Fond
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.18),
                         Color(red: 0.10, green: 0.18, blue: 0.35)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Titre
                VStack(spacing: 8) {
                    Text("ROYAUMES EN GUERRE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Conquête Mondiale")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.horizontal)

                // Configuration
                VStack(spacing: 20) {
                    // Difficulté
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Difficulté de l'IA", systemImage: "brain")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.8))

                        HStack(spacing: 10) {
                            ForEach(Difficulte.allCases, id: \.rawValue) { d in
                                DifficulteButton(
                                    difficulte: d,
                                    selected: difficulte == d
                                ) { difficulte = d }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Nombre de bots
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Adversaires", systemImage: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.8))

                        HStack(spacing: 12) {
                            ForEach([1, 2], id: \.self) { n in
                                Button {
                                    nombreBots = n
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: n == 1 ? "person.fill" : "person.2.fill")
                                        Text(n == 1 ? "1 Bot" : "2 Bots")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(nombreBots == n
                                        ? Color.blue.opacity(0.8)
                                        : Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Légende factions
                    HStack(spacing: 16) {
                        FactionBadge(faction: .joueur, label: "Vous")
                        FactionBadge(faction: .bot1,   label: "Gobelins")
                        if nombreBots == 2 {
                            FactionBadge(faction: .bot2, label: "Orques")
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)

                // Bouton Jouer
                Button {
                    etat.initialiserPartie(difficulte: difficulte, nombreBots: nombreBots)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("CONQUÉRIR LE MONDE")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                     Color(red: 0.1, green: 0.3, blue: 0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.blue.opacity(0.5), radius: 12, y: 4)
                }

                Spacer()

                // Note Mapbox token
                if MAPBOX_ACCESS_TOKEN == "VOTRE_TOKEN_ICI" {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Token Mapbox manquant — voir MapGameView.swift")
                            .font(.caption)
                            .foregroundColor(.yellow.opacity(0.9))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Vue Jeu (map + HUD)

struct GameView: View {
    @EnvironmentObject var etat: EtatPartie

    var body: some View {
        ZStack(alignment: .top) {
            // Carte Mapbox en fond
            MapGameView(etat: etat)
                .ignoresSafeArea()

            // HUD
            VStack(spacing: 0) {
                TopBarView()
                Spacer()
                BottomPanelView()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Barre supérieure

struct TopBarView: View {
    @EnvironmentObject var etat: EtatPartie

    var body: some View {
        HStack(spacing: 0) {
            // Tour actuel
            HStack(spacing: 8) {
                Circle()
                    .fill(etat.tourActuel.couleur)
                    .frame(width: 12, height: 12)
                Text(etat.tourActuel == .joueur ? "Votre tour" : etat.tourActuel.nomAffichage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Phase
            PhaseChip(phase: etat.phase)

            Spacer()

            // Score (territoires)
            ScoreChip()
        }
        .padding(.horizontal, 12)
        .padding(.top, 56) // safe area
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

struct PhaseChip: View {
    let phase: PhaseJoueur

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: phase == .recrutement ? "plus.circle.fill" : "scope")
                .font(.system(size: 12))
            Text(phase == .recrutement ? "Recrutement" : "Attaque")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(phase == .recrutement ? .green : .orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ScoreChip: View {
    @EnvironmentObject var etat: EtatPartie
    let factions: [Faction] = [.joueur, .bot1, .bot2]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(etat.factionsActives, id: \.rawValue) { f in
                let count = etat.territoires.values.filter { $0.proprietaire == f }.count
                HStack(spacing: 3) {
                    Circle().fill(f.couleur).frame(width: 8, height: 8)
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Panel inférieur

struct BottomPanelView: View {
    @EnvironmentObject var etat: EtatPartie

    var body: some View {
        VStack(spacing: 10) {
            // Message
            if !etat.message.isEmpty {
                Text(etat.message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }

            // Boutons d'action
            if etat.tourActuel == .joueur {
                HStack(spacing: 12) {
                    // Recrutement: passer le déploiement
                    if etat.phase == .recrutement && etat.armeesADeployer > 0 {
                        ActionButton(
                            label: "Déployer (\(etat.armeesADeployer))",
                            icon: "plus.circle",
                            color: .green
                        ) { etat.passerRecrutement() }
                    }

                    // Attaque: désélectionner
                    if etat.phase == .attaque && etat.territoireSource != nil {
                        ActionButton(
                            label: "Désélectionner",
                            icon: "xmark.circle",
                            color: .gray
                        ) {
                            etat.territoireSource      = nil
                            etat.territoireSelectionne = nil
                            etat.message = "Sélectionnez un territoire pour attaquer"
                            etat.refreshMap.toggle()
                        }
                    }

                    // Fin de tour
                    if etat.phase == .attaque {
                        ActionButton(
                            label: "Fin du tour",
                            icon: "arrow.clockwise",
                            color: .blue
                        ) { etat.terminerTourJoueur() }
                    }
                }
                .padding(.horizontal)
            } else {
                // Tour du bot
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8).tint(.white)
                    Text(etat.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            // Légende continents bonus
            ContinentLegendView()
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct ContinentLegendView: View {
    @EnvironmentObject var etat: EtatPartie

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MondeJeu.continents) { cont in
                    let terrs   = etat.territoires.values.filter { $0.continentId == cont.id }
                    let joueur  = terrs.filter { $0.proprietaire == .joueur }.count
                    let isOwned = !terrs.isEmpty && terrs.allSatisfy { $0.proprietaire == .joueur }

                    HStack(spacing: 4) {
                        Text(cont.nom)
                            .font(.system(size: 10, weight: .medium))
                        Text("+\(cont.bonus)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isOwned ? .yellow : .white.opacity(0.6))
                        Text("\(joueur)/\(terrs.count)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isOwned
                        ? Color.yellow.opacity(0.25)
                        : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isOwned ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Fin de partie

struct FinPartieView: View {
    @EnvironmentObject var etat: EtatPartie
    let gagnant: Faction

    var victoire: Bool { gagnant == .joueur }

    var body: some View {
        ZStack {
            (victoire
                ? LinearGradient(colors: [Color(red:0.05,green:0.25,blue:0.05), Color(red:0.1,green:0.5,blue:0.15)],
                                 startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Color(red:0.25,green:0.05,blue:0.05), Color(red:0.5,green:0.1,blue:0.1)],
                                 startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icône
                Image(systemName: victoire ? "crown.fill" : "flag.fill")
                    .font(.system(size: 64))
                    .foregroundColor(victoire ? .yellow : .red)

                // Titre
                VStack(spacing: 10) {
                    Text(victoire ? "VICTOIRE !" : "DÉFAITE")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(victoire
                        ? "Le monde entier se prosterne devant les \(Faction.joueur.nomAffichage) !"
                        : "Les \(gagnant.nomAffichage) ont conquis le monde."
                    )
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                // Stats
                StatsView()
                    .padding(.horizontal)

                Spacer()

                // Boutons
                VStack(spacing: 14) {
                    Button {
                        etat.initialiserPartie(difficulte: etat.difficulte, nombreBots: etat.factionsActives.count - 1)
                    } label: {
                        Label("Rejouer", systemImage: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        etat.etatJeu = .menu
                    } label: {
                        Text("Menu Principal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var etat: EtatPartie

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Faction.allCases.filter { $0 != .neutre }, id: \.rawValue) { f in
                let count = etat.territoires.values.filter { $0.proprietaire == f }.count
                if count > 0 || etat.factionsActives.contains(f) {
                    HStack {
                        Circle().fill(f.couleur).frame(width: 10, height: 10)
                        Text(f.nomAffichage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(count) territoire(s)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: - Composants réutilisables

struct DifficulteButton: View {
    let difficulte: Difficulte
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(difficulte.etoiles)
                    .font(.system(size: 13))
                Text(difficulte.rawValue)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.blue.opacity(0.7) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct FactionBadge: View {
    let faction: Faction
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(faction.couleur)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(faction.couleur.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
