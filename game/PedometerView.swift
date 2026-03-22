import SwiftUI

struct PedometerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var pedometer = PedometerService()

    @State private var arrivedCheckpoint: Checkpoint?
    @State private var showCheckpointAlert = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.12).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    stepBubble
                    statsRow1
                    statsRow2
                    worldProgressCard
                    nextCheckpointCard
                    weeklyBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }

            if appState.isInTransit {
                OceanTransitView()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation { appState.completeOceanCrossing() }
                    }
            }
        }
        .onAppear(perform: setup)
        .onDisappear { pedometer.stopTracking() }
        .alert(isPresented: $showCheckpointAlert) {
            Alert(
                title: Text("\(arrivedCheckpoint?.emoji ?? "") Checkpoint !"),
                message: Text("Vous êtes arrivé à \(arrivedCheckpoint?.name ?? ""), \(arrivedCheckpoint?.country ?? "") 🎉"),
                dismissButton: .default(Text("Super !"))
            )
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        Text("WalkTheWorld")
            .font(.custom("Georgia", size: 28))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.top, 20)
    }

    private var stepBubble: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.12, green: 0.15, blue: 0.18))
                .frame(width: 160, height: 160)
            VStack(spacing: 6) {
                Text(pedometer.stepValidated ? "✓" : "👟")
                    .font(.system(size: 64))
                    .scaleEffect(pedometer.stepValidated ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pedometer.stepValidated)
                if pedometer.stepValidated {
                    Text("Pas validé !")
                        .font(.caption).fontWeight(.bold).foregroundColor(.green)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    private var statsRow1: some View {
        HStack(spacing: 12) {
            StatCard(title: "Pas aujourd'hui",
                     value: "\(appState.todaySteps)",
                     unit: "pas", color: .orange)
            StatCard(title: "Distance réelle",
                     value: String(format: "%.2f", Double(appState.todaySteps) * 0.000762),
                     unit: "km", color: .blue)
        }
    }

    private var statsRow2: some View {
        HStack(spacing: 12) {
            StatCard(title: "Distance ×10",
                     value: String(format: "%.2f", Double(appState.todaySteps) * 0.00762),
                     unit: "km virtuels", color: .green)
            StatCard(title: "Streak",
                     value: "\(appState.dailyStreak)",
                     unit: "jours 🔥", color: .red)
        }
    }

    private var worldProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tour du Monde")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.3f %%", appState.worldProgress * 100))
                    .font(.caption).foregroundColor(.orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.25)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(appState.worldProgress)), height: 8)
                }
            }
            .frame(height: 8)
            HStack {
                Text(String(format: "%.1f km virtuels parcourus", appState.virtualDistanceKm))
                    .font(.caption).foregroundColor(.gray)
                Spacer()
                Text("/ 40 075 km").font(.caption).foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.15, blue: 0.18))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var nextCheckpointCard: some View {
        if let next = appState.nextCheckpoint {
            HStack(spacing: 16) {
                Text(next.emoji).font(.largeTitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prochain checkpoint").font(.caption).foregroundColor(.gray)
                    Text("\(next.name), \(next.country)").font(.headline).foregroundColor(.white)
                    Text(String(format: "%.0f km restants", appState.distanceToNextCheckpointKm))
                        .font(.caption).foregroundColor(.orange)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(red: 0.12, green: 0.15, blue: 0.18))
            .cornerRadius(12)
        }
    }

    // Weekly bar: last 7 days, normalized to 10 000 steps/day goal
    private var weeklyBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Semaine").font(.headline).foregroundColor(.white)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(weekValues[i] >= 1.0 ? Color.orange : Color.blue.opacity(0.5))
                            .frame(height: max(4, CGFloat(weekValues[i]) * 56))
                        Text(dayLabels[i]).font(.caption2).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 72)
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.15, blue: 0.18))
        .cornerRadius(12)
    }

    /// Normalised bar values (0.0 – 1.5) based on a 10 000-step daily goal.
    private var weekValues: [Double] {
        let goal: Double = 10_000
        return appState.weeklySteps.map { min(Double($0) / goal, 1.5) }
    }

    /// Short day labels for the last 7 days (oldest → newest), locale-aware.
    private var dayLabels: [String] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "fr_FR")
        return (0..<7).reversed().compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return String(fmt.string(from: d).prefix(1)).uppercased()
        }
    }

    // MARK: - Setup

    private func setup() {
        pedometer.startTracking()
        pedometer.queryToday { appState.todaySteps = $0 }
        pedometer.onValidatedStep = { appState.addValidatedStep() }
        NotificationCenter.default.addObserver(
            forName: .checkpointReached, object: nil, queue: .main
        ) { note in
            arrivedCheckpoint = note.object as? Checkpoint
            showCheckpointAlert = true
        }
    }
}

// MARK: - Reusable card

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(unit).font(.caption2).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(red: 0.12, green: 0.15, blue: 0.18))
        .cornerRadius(12)
    }
}
