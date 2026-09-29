import ActivityKit
import Combine
import SwiftUI
import UIKit

@MainActor
final class ScreenOnModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var activityNotice: String?
    @Published private(set) var isReady = false
    @Published var duration: Int {
        didSet { UserDefaults.standard.set(duration, forKey: "durationMinutes") }
    }

    private var isReconciling = false
    private var sessionID = UUID()
    private var heartbeat: Task<Void, Never>?
    private var activity: Activity<ScreenActivityAttributes>?
    private var deadline: Date?
    private var deadlineUptime: TimeInterval?
    private var observers: [NSObjectProtocol] = []

    init() {
        let saved = UserDefaults.standard.integer(forKey: "durationMinutes")
        duration = [0, 15, 30, 60, 120, 240].contains(saved) ? saved : 0
        UIApplication.shared.isIdleTimerDisabled = false
        // UIKit notification resets the idle timer synchronously, before suspension.
        for name in [UIApplication.willResignActiveNotification, UIApplication.willTerminateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop(feedback: false) }
            })
        }
        Task { await reconcile() }
    }

    func sceneChanged(_ phase: ScenePhase) {
        if phase != .active {
            stop(feedback: false)
        } else if !isActive {
            Task { await reconcile() }
        } else if !UIApplication.shared.isIdleTimerDisabled {
            stop(feedback: false)
        }
    }

    private func reconcile() async {
        guard !isActive, !isReconciling else { return }
        isReconciling = true
        defer { isReconciling = false }
        isReady = false
        UIApplication.shared.isIdleTimerDisabled = false
        // No persisted ON flag: a previous process cannot own this session.
        for old in Activity<ScreenActivityAttributes>.activities {
            await old.end(ActivityContent(state: .init(isActive: false), staleDate: nil), dismissalPolicy: .immediate)
        }
        isReady = true
    }

    func toggle() {
        if isActive { stop(feedback: true) } else { start() }
    }

    private func start() {
        guard isReady, UIApplication.shared.applicationState == .active else { return }
        let now = Date()
        sessionID = UUID()
        let id = sessionID
        startedAt = now
        deadline = duration == 0 ? nil : now.addingTimeInterval(Double(duration) * 60)
        deadlineUptime = duration == 0 ? nil : ProcessInfo.processInfo.systemUptime + Double(duration) * 60
        UIApplication.shared.isIdleTimerDisabled = true
        isActive = UIApplication.shared.isIdleTimerDisabled
        activityNotice = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                activity = try Activity.request(
                    attributes: ScreenActivityAttributes(startedAt: now, deadline: deadline),
                    content: content(), pushType: nil
                )
            } catch {
                activityNotice = "Live Activity konnte nicht gestartet werden. Screen On funktioniert weiterhin in der App."
            }
        } else {
            activityNotice = "Live Activities sind in den iPhone-Einstellungen deaktiviert oder nicht verfügbar."
        }
        heartbeat = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard let self, self.isActive, self.sessionID == id else { return }
                if let limit = self.deadlineUptime, ProcessInfo.processInfo.systemUptime >= limit {
                    self.stop(feedback: false)
                    return
                }
                guard UIApplication.shared.applicationState == .active,
                      UIApplication.shared.isIdleTimerDisabled else {
                    self.stop(feedback: false)
                    return
                }
                ticks += 1
                if ticks % 15 == 0, let live = self.activity {
                    if live.activityState == .ended || live.activityState == .dismissed {
                        self.activity = nil
                        self.activityNotice = "Live Activity wurde beendet. Screen On bleibt in dieser App aktiv."
                    } else {
                        await live.update(self.content())
                        // An update already in flight must not resurrect a stopped session.
                        if self.sessionID != id || !self.isActive {
                            await live.end(ActivityContent(state: .init(isActive: false), staleDate: nil), dismissalPolicy: .immediate)
                            return
                        }
                    }
                }
            }
        }
    }

    private func content() -> ActivityContent<ScreenActivityAttributes.ContentState> {
        let lease = Date().addingTimeInterval(45)
        return ActivityContent(state: .init(isActive: true), staleDate: min(deadline ?? lease, lease))
    }

    func stop(feedback: Bool) {
        let wasActive = isActive
        UIApplication.shared.isIdleTimerDisabled = false
        isActive = false
        startedAt = nil
        deadline = nil
        deadlineUptime = nil
        sessionID = UUID()
        heartbeat?.cancel()
        heartbeat = nil
        let old = activity
        activity = nil
        if feedback && wasActive { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        guard let old else { return }
        // Allow the official ActivityKit end request a brief background execution window.
        let token = UIApplication.shared.beginBackgroundTask(withName: "End Screen On")
        Task {
            await old.end(ActivityContent(state: .init(isActive: false), staleDate: nil), dismissalPolicy: .immediate)
            if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
        }
    }
}
