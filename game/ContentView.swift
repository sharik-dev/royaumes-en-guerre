import SwiftUI
import SpriteKit

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var etat = EtatPartie.shared
    @State private var scene: GameScene?

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Jeu SpriteKit ──────────────────────────────────────────────
            GeometryReader { geo in
                SpriteView(scene: makeScene(taille: geo.size))
                    .ignoresSafeArea()
            }

            // ── Interface ──────────────────────────────────────────────────
            VStack(spacing: 0) {
                barreRessources
                    .padding(.top, 52)
                Spacer()
                messageView
                    .padding(.bottom, 6)
                panneauActions
                    .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .top)

            // ── Fin de partie ──────────────────────────────────────────────
            if etat.etat == .victoireJoueur || etat.etat == .victoireIA {
                ecranFinPartie
            }
        }
        .onAppear { etat.initialiserPartie() }
        // Propager sceneNeedsRefresh → notification pour GameScene
        .onChange(of: etat.sceneNeedsRefresh) {
            NotificationCenter.default.post(name: .jeuRafraichir, object: nil)
        }
    }

    // MARK: - Scene factory

    func makeScene(taille: CGSize) -> GameScene {
        if let s = scene { return s }
        let s       = GameScene(size: taille)
        s.scaleMode = .resizeFill
        scene       = s
        return s
    }

    // MARK: - Barre de ressources (haut)

    var barreRessources: some View {
        HStack(spacing: 0) {
            ressourceChip(icone: "circle.fill",     couleur: .yellow,  label: "Or",   valeur: etat.or)
            Spacer()
            ressourceChip(icone: "leaf.fill",       couleur: .green,   label: "Bois", valeur: etat.bois)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                Text("Tour \(etat.numTour)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.72))
        )
    }

    func ressourceChip(icone: String, couleur: Color, label: String, valeur: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icone)
                .font(.system(size: 13))
                .foregroundColor(couleur)
            Text("\(label): \(valeur)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(couleur)
        }
    }

    // MARK: - Message

    var messageView: some View {
        Text(etat.message)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.68))
            .cornerRadius(10)
            .padding(.horizontal, 16)
    }

    // MARK: - Panneau d'actions (bas)

    @ViewBuilder
    var panneauActions: some View {
        switch etat.etat {
        case .tourJoueur:
            if case .batimentSelectionne(let bat) = etat.selection,
               (bat.type == .chateau || bat.type == .caserne) {
                panneauRecrutement(bat)
            } else {
                panneauDefaut
            }
        case .tourIA:
            Text("⚔️  Les Gobelins attaquent…")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.72))
                .cornerRadius(14)
        default:
            EmptyView()
        }
    }

    var panneauDefaut: some View {
        HStack(spacing: 14) {
            infoSelectionView
            Spacer()
            boutonFinTour
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.72))
        .cornerRadius(16)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    var infoSelectionView: some View {
        if case .uniteSelectionnee(let u) = etat.selection {
            VStack(alignment: .leading, spacing: 2) {
                Text(u.type.nom)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    statLabel("⚔️", "\(u.type.attaque)")
                    statLabel("👟", "\(u.type.deplacement)")
                    statLabel("🏹", "\(u.type.portee)")
                    statLabel("❤️", "\(u.pvActuels)/\(u.type.pvMax)")
                }
            }
        } else {
            Text("Sélectionnez une unité ou un bâtiment")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.gray)
        }
    }

    func statLabel(_ icon: String, _ val: String) -> some View {
        HStack(spacing: 2) {
            Text(icon).font(.system(size: 11))
            Text(val).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white)
        }
    }

    var boutonFinTour: some View {
        Button(action: { etat.finDuTour() }) {
            HStack(spacing: 6) {
                Text("Fin du Tour")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 15))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.18, green: 0.48, blue: 0.88))
            .cornerRadius(12)
        }
    }

    // MARK: - Panneau recrutement

    func panneauRecrutement(_ bat: Batiment) -> some View {
        VStack(spacing: 6) {
            Text("Recruter — \(bat.type.nom)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)

            HStack(spacing: 10) {
                boutonsRecrutement(bat)
                Spacer()
                boutonFinTour
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.72))
        .cornerRadius(16)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    func boutonsRecrutement(_ bat: Batiment) -> some View {
        ForEach([TypeUnite.guerrier, TypeUnite.archer, TypeUnite.pion], id: \.self) { type in
            let peutPayer = etat.or >= type.coutOr && etat.bois >= type.coutBois
            Button(action: { etat.recruterUnite(type, depuis: bat) }) {
                VStack(spacing: 3) {
                    Text(type.nom)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    HStack(spacing: 3) {
                        Text("🪙\(type.coutOr)")
                        Text("🌿\(type.coutBois)")
                    }
                    .font(.system(size: 10))
                }
                .foregroundColor(peutPayer ? .white : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(peutPayer
                    ? Color(red: 0.75, green: 0.45, blue: 0.05)
                    : Color.gray.opacity(0.35))
                .cornerRadius(10)
            }
            .disabled(!peutPayer)
        }
    }

    // MARK: - Ecran fin de partie

    var ecranFinPartie: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(etat.etat == .victoireJoueur ? "🏆 VICTOIRE !" : "💀 DÉFAITE")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(etat.etat == .victoireJoueur ? .yellow : .red)

                Text(etat.message)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: { etat.initialiserPartie() }) {
                    Text("Rejouer")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.15, green: 0.58, blue: 0.28))
                        .cornerRadius(18)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.12, green: 0.08, blue: 0.20))
            )
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
}
