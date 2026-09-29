import ActivityKit
import Foundation

struct ScreenActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isActive: Bool
    }
    let startedAt: Date
    let deadline: Date?
}
