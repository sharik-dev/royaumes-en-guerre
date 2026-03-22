import Foundation
import SwiftUI
import CoreLocation
import Combine

extension Notification.Name {
    static let checkpointReached = Notification.Name("checkpointReached")
}

final class AppState: ObservableObject {
    // Steps
    @Published var totalSteps: Int
    @Published var todaySteps: Int = 0

    // World travel
    @Published var virtualDistanceKm: Double
    @Published var playerCoordinate: CLLocationCoordinate2D
    @Published var trail: [CLLocationCoordinate2D] = []
    @Published var currentSegmentIndex: Int
    @Published var segmentProgress: Double

    // Setup
    @Published var isSetupComplete: Bool

    // Gamification
    @Published var dailyStreak: Int
    @Published var completedCheckpoints: [String]
    @Published var isInTransit = false
    @Published var weeklySteps: [Int]          // last 7 days, oldest→newest

    private var lastActiveDate: Date?

    private static let strideMeters: Double = 0.762
    static let stepMultiplier: Double = 10
    static let worldCircumferenceKm: Double = 40_075

    // MARK: - Init

    init() {
        let savedSteps  = UserDefaults.standard.integer(forKey: "totalSteps")
        let savedSeg    = UserDefaults.standard.integer(forKey: "segmentIndex")
        let savedProg   = UserDefaults.standard.double(forKey: "segmentProgress")
        let savedStreak = UserDefaults.standard.integer(forKey: "dailyStreak")
        let savedCP     = UserDefaults.standard.stringArray(forKey: "completedCheckpoints") ?? []
        let lat         = UserDefaults.standard.double(forKey: "playerLat")
        let lon         = UserDefaults.standard.double(forKey: "playerLon")
        let weeklyDict  = UserDefaults.standard.dictionary(forKey: "weeklyStepsDict") as? [String: Int] ?? [:]
        let lastDateTS  = UserDefaults.standard.double(forKey: "lastActiveDate")

        isSetupComplete      = (lat != 0 || lon != 0)
        totalSteps           = savedSteps
        currentSegmentIndex  = savedSeg
        segmentProgress      = savedProg
        dailyStreak          = max(savedStreak, 0)
        completedCheckpoints = savedCP
        virtualDistanceKm    = Double(savedSteps) * AppState.strideMeters * AppState.stepMultiplier / 1000.0
        playerCoordinate     = (lat != 0 || lon != 0)
            ? CLLocationCoordinate2D(latitude: lat, longitude: lon)
            : WorldRoute.shared.checkpoints[0].coordinate
        lastActiveDate       = lastDateTS > 0 ? Date(timeIntervalSince1970: lastDateTS) : nil
        weeklySteps          = AppState.last7DaysSteps(from: weeklyDict)
    }

    // MARK: - Computed

    var worldProgress: Double { min(virtualDistanceKm / AppState.worldCircumferenceKm, 1.0) }

    var nextCheckpoint: Checkpoint? {
        WorldRoute.shared.segments[safe: currentSegmentIndex]?.to
    }

    var distanceToNextCheckpointKm: Double {
        guard currentSegmentIndex < WorldRoute.shared.segments.count else { return 0 }
        return WorldRoute.shared.segments[currentSegmentIndex].distanceKm * (1.0 - segmentProgress)
    }

    // MARK: - Step

    func addValidatedStep() {
        totalSteps += 1
        todaySteps += 1
        let virtualMeters = AppState.strideMeters * AppState.stepMultiplier
        virtualDistanceKm += virtualMeters / 1000.0
        updateStreakAndWeekly()
        advance(meters: virtualMeters)
        persist()
    }

    // MARK: - Route advancement

    private func advance(meters: Double) {
        let segs = WorldRoute.shared.segments
        guard !segs.isEmpty, !isInTransit else { return }
        let idx = currentSegmentIndex % segs.count
        let seg = segs[idx]
        let segMeters = seg.distanceKm * 1000.0
        segmentProgress += meters / segMeters

        if segmentProgress >= 1.0 {
            let overflow = (segmentProgress - 1.0) * segMeters
            segmentProgress = 0

            if !completedCheckpoints.contains(seg.to.id) {
                completedCheckpoints.append(seg.to.id)
                NotificationCenter.default.post(name: .checkpointReached, object: seg.to)
            }

            currentSegmentIndex = (idx + 1) % segs.count

            if segs[currentSegmentIndex].isOcean {
                triggerOceanTransit()
            } else if overflow > 0 {
                advance(meters: overflow)
            }
        } else {
            interpolatePosition()
        }
    }

    /// Show the boat overlay then auto-teleport to the far shore after 3.5 s.
    private func triggerOceanTransit() {
        isInTransit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.completeOceanCrossing()
        }
    }

    /// Called automatically after the delay, or manually on user tap (skip).
    func completeOceanCrossing() {
        let segs = WorldRoute.shared.segments
        guard currentSegmentIndex < segs.count else {
            withAnimation { isInTransit = false }
            return
        }
        let seg = segs[currentSegmentIndex]
        if !completedCheckpoints.contains(seg.to.id) {
            completedCheckpoints.append(seg.to.id)
            NotificationCenter.default.post(name: .checkpointReached, object: seg.to)
        }
        currentSegmentIndex = (currentSegmentIndex + 1) % segs.count
        segmentProgress = 0
        playerCoordinate = seg.to.coordinate
        trail.append(playerCoordinate)
        withAnimation { isInTransit = false }
        persist()
    }

    private func interpolatePosition() {
        let segs = WorldRoute.shared.segments
        guard !segs.isEmpty else { return }
        let seg = segs[currentSegmentIndex % segs.count]
        let t = segmentProgress
        let lat = seg.from.coordinate.latitude  + (seg.to.coordinate.latitude  - seg.from.coordinate.latitude)  * t
        let lon = seg.from.coordinate.longitude + (seg.to.coordinate.longitude - seg.from.coordinate.longitude) * t
        playerCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        trail.append(playerCoordinate)
        if trail.count > 500 { trail.removeFirst(50) }
    }

    // MARK: - Streak & Weekly history

    private func updateStreakAndWeekly() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // --- Weekly steps dict ---
        var dict = UserDefaults.standard.dictionary(forKey: "weeklyStepsDict") as? [String: Int] ?? [:]
        let key = dayKey(for: Date())
        dict[key] = (dict[key] ?? 0) + 1
        // Prune keys older than 14 days
        if let cutoff = cal.date(byAdding: .day, value: -14, to: Date()) {
            dict = dict.filter { k, _ in
                guard let d = AppState.dateFromKey(k) else { return false }
                return d >= cutoff
            }
        }
        UserDefaults.standard.set(dict, forKey: "weeklyStepsDict")
        weeklySteps = AppState.last7DaysSteps(from: dict)

        // --- Streak ---
        let alreadyCountedToday = lastActiveDate.map { cal.isDate($0, inSameDayAs: Date()) } ?? false
        if !alreadyCountedToday {
            if let last = lastActiveDate {
                let days = cal.dateComponents([.day], from: last, to: today).day ?? 0
                if days == 1 { dailyStreak += 1 }
                else if days > 1 { dailyStreak = 1 }
            } else {
                dailyStreak = 1
            }
            lastActiveDate = today
            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: "lastActiveDate")
            UserDefaults.standard.set(dailyStreak, forKey: "dailyStreak")
        }
    }

    // MARK: - Setup

    func setStartCoordinate(_ coordinate: CLLocationCoordinate2D) {
        playerCoordinate = coordinate
        isSetupComplete = true
        UserDefaults.standard.set(coordinate.latitude,  forKey: "playerLat")
        UserDefaults.standard.set(coordinate.longitude, forKey: "playerLon")
    }

    // MARK: - Persistence

    private func persist() {
        UserDefaults.standard.set(totalSteps,           forKey: "totalSteps")
        UserDefaults.standard.set(currentSegmentIndex,  forKey: "segmentIndex")
        UserDefaults.standard.set(segmentProgress,      forKey: "segmentProgress")
        UserDefaults.standard.set(playerCoordinate.latitude,  forKey: "playerLat")
        UserDefaults.standard.set(playerCoordinate.longitude, forKey: "playerLon")
        UserDefaults.standard.set(completedCheckpoints, forKey: "completedCheckpoints")
    }

    // MARK: - Date helpers

    private func dayKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private static func dateFromKey(_ key: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: key)
    }

    /// Returns step counts for the last 7 calendar days, Monday-first within current week.
    static func last7DaysSteps(from dict: [String: Int]) -> [Int] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (0..<7).reversed().map { offset -> Int in
            guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return 0 }
            return dict[fmt.string(from: date)] ?? 0
        }
    }
}
