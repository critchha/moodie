import Foundation

struct Feedback: Codable {
    let mediaId: String
    var rating: Int // 1-5
    let wouldWatchAgain: Bool
    var watchedToCompletion: Bool
} 